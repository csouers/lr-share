import AppKit
import Foundation

@main
struct LightroomShareHelperMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

private struct ShareBatch {
    let id: Int
    let urls: [URL]
    let fingerprint: String
    let source: String
    let createdAt: Date
}

private struct PendingIntake {
    let urls: [URL]
    let source: String
}

private enum HelperTraceLogger {
    private static let logFileURL = URL(fileURLWithPath: "/tmp/lightroom-share-helper.log")
    private static let logQueue = DispatchQueue(label: "LightroomShareHelper.Trace")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(
        event: String,
        batch: ShareBatch? = nil,
        fileCount: Int? = nil,
        source: String? = nil,
        detail: String = "-"
    ) {
        let timestamp = formatter.string(from: Date())
        let pid = ProcessInfo.processInfo.processIdentifier
        let batchID = batch.map { String($0.id) } ?? "-"
        let fingerprintPrefix = batch.map { String($0.fingerprint.prefix(8)) } ?? "-"
        let count = fileCount ?? batch?.urls.count ?? 0
        let sourceValue = source ?? batch?.source ?? "-"
        let line = "\(timestamp) pid=\(pid) event=\(event) batch=\(batchID) fp=\(fingerprintPrefix) count=\(count) source=\(sourceValue) detail=\(detail)\n"

        logQueue.async {
            let manager = FileManager.default
            if !manager.fileExists(atPath: Self.logFileURL.path) {
                _ = manager.createFile(atPath: Self.logFileURL.path, contents: nil)
            }
            guard let data = line.data(using: .utf8) else {
                return
            }
            guard let handle = try? FileHandle(forWritingTo: Self.logFileURL) else {
                return
            }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = ShareCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        let passedPaths = CommandLine.arguments.dropFirst().filter { argument in
            !argument.hasPrefix("-")
        }

        coordinator.enqueue(paths: Array(passedPaths), source: "launchArgs")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.coordinator.terminateIfIdle()
        }
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        coordinator.enqueue(paths: filenames, source: "openFiles")
        application.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

final class ShareCoordinator: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    private let anchorWindow = PickerAnchorWindow()

    private let coalesceWindow: TimeInterval = 0.15
    private let duplicateWindow: TimeInterval = 1.0
    private let pickerPresentationDelay: TimeInterval = 0.2
    private let fallbackTimeout: TimeInterval = 600.0
    private let terminationDelay: TimeInterval = 0.3

    private var activeBatch: ShareBatch?
    private var queuedBatches: [ShareBatch] = []
    private var pendingIntakes: [PendingIntake] = []
    private var isPresentingPicker = false
    private var activePicker: NSSharingServicePicker?
    private var activeService: NSSharingService?
    private var terminateFallbackWorkItem: DispatchWorkItem?
    private var coalesceWorkItem: DispatchWorkItem?
    private var nextBatchID = 1

    func terminateIfIdle() {
        evaluateTerminationIfIdle(trigger: "startup_idle_check")
    }

    func enqueue(paths: [String], source: String) {
        let urls = normalizedFileURLs(from: paths)
        HelperTraceLogger.log(
            event: "enqueue",
            fileCount: urls.count,
            source: source,
            detail: urls.isEmpty ? "no_readable_files" : "accepted"
        )

        guard !urls.isEmpty else {
            evaluateTerminationIfIdle(trigger: "enqueue_empty")
            return
        }

        pendingIntakes.append(PendingIntake(urls: urls, source: source))
        scheduleCoalesceFlush()
    }

    private func scheduleCoalesceFlush() {
        coalesceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingIntakes()
        }
        coalesceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + coalesceWindow, execute: workItem)
    }

    private func flushPendingIntakes() {
        coalesceWorkItem = nil
        let intakes = pendingIntakes
        pendingIntakes.removeAll()

        guard !intakes.isEmpty else {
            evaluateTerminationIfIdle(trigger: "coalesce_empty")
            return
        }

        var uniqueByPath: [String: URL] = [:]
        var sources = Set<String>()
        for intake in intakes {
            sources.insert(intake.source)
            for url in intake.urls {
                uniqueByPath[url.path] = url
            }
        }

        let mergedURLs = uniqueByPath.values.sorted { lhs, rhs in
            lhs.path < rhs.path
        }
        guard !mergedURLs.isEmpty else {
            evaluateTerminationIfIdle(trigger: "coalesce_no_urls")
            return
        }

        let source = sources.sorted().joined(separator: "+")
        let batch = ShareBatch(
            id: nextBatchID,
            urls: mergedURLs,
            fingerprint: fingerprint(for: mergedURLs),
            source: source,
            createdAt: Date()
        )
        nextBatchID += 1

        accept(batch: batch)
    }

    private func accept(batch: ShareBatch) {
        if let activeBatch, activeBatch.fingerprint == batch.fingerprint {
            HelperTraceLogger.log(
                event: "dedupe_drop",
                batch: batch,
                detail: "reason=active_batch"
            )
            return
        }

        if let lastQueued = queuedBatches.last,
           lastQueued.fingerprint == batch.fingerprint,
           batch.createdAt.timeIntervalSince(lastQueued.createdAt) <= duplicateWindow {
            HelperTraceLogger.log(
                event: "dedupe_drop",
                batch: batch,
                detail: "reason=queued_recent"
            )
            return
        }

        if hasActiveSession {
            queuedBatches.append(batch)
            HelperTraceLogger.log(
                event: "queue_add",
                batch: batch,
                detail: "queue_depth=\(queuedBatches.count)"
            )
            return
        }

        start(batch: batch)
    }

    private var hasActiveSession: Bool {
        activeBatch != nil || isPresentingPicker || activeService != nil
    }

    private var isCompletelyIdle: Bool {
        activeBatch == nil &&
        queuedBatches.isEmpty &&
        pendingIntakes.isEmpty &&
        coalesceWorkItem == nil &&
        !isPresentingPicker &&
        activePicker == nil &&
        activeService == nil
    }

    private func start(batch: ShareBatch) {
        activeBatch = batch
        activeService = nil
        activePicker = nil
        isPresentingPicker = false
        cancelTerminateFallback()

        HelperTraceLogger.log(
            event: "batch_start",
            batch: batch,
            detail: "queue_depth=\(queuedBatches.count)"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + pickerPresentationDelay) { [weak self] in
            self?.presentPicker(forBatchID: batch.id)
        }
    }

    private func presentPicker(forBatchID batchID: Int) {
        guard let batch = activeBatch, batch.id == batchID else {
            return
        }

        guard !batch.urls.isEmpty else {
            finishActiveBatch(reason: "empty_batch")
            return
        }

        anchorWindow.prepareForPicker()
        let anchorView = anchorWindow.anchorView

        let picker = NSSharingServicePicker(items: batch.urls)
        picker.delegate = self
        activePicker = picker
        isPresentingPicker = true
        HelperTraceLogger.log(event: "picker_present", batch: batch)

        picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        activePicker = nil
        isPresentingPicker = false

        guard let batch = activeBatch else {
            return
        }

        guard let service else {
            HelperTraceLogger.log(event: "picker_cancel", batch: batch)
            finishActiveBatch(reason: "picker_cancel")
            return
        }

        activeService = service
        let serviceName = service.title.isEmpty ? String(describing: service) : service.title
        HelperTraceLogger.log(event: "service_choose", batch: batch, detail: "service=\(serviceName)")
        scheduleTerminateFallback(after: fallbackTimeout, forBatchID: batch.id)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        self
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        guard let batch = activeBatch else {
            return
        }
        HelperTraceLogger.log(event: "share_success", batch: batch, detail: "items=\(items.count)")
        finishActiveBatch(reason: "share_success")
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        guard let batch = activeBatch else {
            return
        }
        _ = items
        HelperTraceLogger.log(
            event: "share_fail",
            batch: batch,
            detail: "error=\(error.localizedDescription)"
        )
        finishActiveBatch(reason: "share_fail")
    }

    private func finishActiveBatch(reason: String) {
        cancelTerminateFallback()
        activeService = nil
        activePicker = nil
        isPresentingPicker = false
        anchorWindow.teardown()

        guard let finished = activeBatch else {
            evaluateTerminationIfIdle(trigger: "finish_without_batch")
            return
        }

        activeBatch = nil
        HelperTraceLogger.log(
            event: "batch_end",
            batch: finished,
            detail: "reason=\(reason)"
        )

        if !queuedBatches.isEmpty {
            let next = queuedBatches.removeFirst()
            start(batch: next)
            return
        }

        evaluateTerminationIfIdle(trigger: "batch_end_\(reason)")
    }

    private func scheduleTerminateFallback(after seconds: TimeInterval, forBatchID batchID: Int) {
        cancelTerminateFallback()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            guard let activeBatch = self.activeBatch, activeBatch.id == batchID else {
                return
            }
            HelperTraceLogger.log(
                event: "share_fail",
                batch: activeBatch,
                detail: "error=fallback_timeout"
            )
            self.finishActiveBatch(reason: "fallback_timeout")
        }
        terminateFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    private func cancelTerminateFallback() {
        terminateFallbackWorkItem?.cancel()
        terminateFallbackWorkItem = nil
    }

    private func evaluateTerminationIfIdle(trigger: String) {
        guard isCompletelyIdle else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + terminationDelay) { [weak self] in
            guard let self else {
                return
            }
            guard self.isCompletelyIdle else {
                return
            }
            HelperTraceLogger.log(event: "terminate", detail: "trigger=\(trigger)")
            NSApp.terminate(nil)
        }
    }

    private func normalizedFileURLs(from paths: [String]) -> [URL] {
        var unique = Set<String>()
        var urls: [URL] = []

        for path in paths {
            let candidate: URL
            if path.hasPrefix("file://"), let parsedURL = URL(string: path) {
                candidate = parsedURL
            } else {
                candidate = URL(fileURLWithPath: path)
            }

            let standardized = candidate.standardizedFileURL
            let fullPath = standardized.path
            guard FileManager.default.isReadableFile(atPath: fullPath) else {
                continue
            }
            guard !unique.contains(fullPath) else {
                continue
            }

            unique.insert(fullPath)
            urls.append(standardized)
        }

        return urls.sorted { lhs, rhs in
            lhs.path < rhs.path
        }
    }

    private func fingerprint(for urls: [URL]) -> String {
        let joinedPaths = urls.map(\.path).joined(separator: "\n")
        var hash: UInt64 = 1469598103934665603
        for byte in joinedPaths.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", CUnsignedLongLong(hash))
    }
}

final class PickerAnchorWindow {
    private let panel: NSPanel
    private let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 2, height: 2))
    let anchorView = NSView(frame: NSRect(x: 0, y: 0, width: 2, height: 2))

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 2, height: 2),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.alphaValue = 0.01
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        anchorView.wantsLayer = true
        anchorView.layer?.backgroundColor = NSColor.clear.cgColor
        anchorView.autoresizingMask = [.width, .height]
        contentView.addSubview(anchorView)
        panel.contentView = contentView
    }

    func prepareForPicker() {
        NSApp.activate(ignoringOtherApps: true)
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        let targetFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 2, height: 2)
        let panelSize = contentView.frame.size
        let centeredOrigin = NSPoint(
            x: targetFrame.midX - (panelSize.width / 2.0),
            y: targetFrame.midY - (panelSize.height / 2.0)
        )
        panel.setFrame(NSRect(origin: centeredOrigin, size: panelSize), display: false)
        anchorView.frame = contentView.bounds
        panel.orderFrontRegardless()
    }

    func teardown() {
        panel.orderOut(nil)
    }
}
