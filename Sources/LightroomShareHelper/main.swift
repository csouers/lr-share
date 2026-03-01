import AppKit

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = ShareCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        let passedPaths = CommandLine.arguments.dropFirst().filter { argument in
            !argument.hasPrefix("-")
        }

        if !passedPaths.isEmpty {
            coordinator.share(paths: passedPaths)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.coordinator.terminateIfIdle()
        }
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        coordinator.share(paths: filenames)
        application.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

final class ShareCoordinator: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    private let anchorWindow = PickerAnchorWindow()
    private var currentURLs: [URL] = []
    private var hasAttemptedShare = false
    private var activePicker: NSSharingServicePicker?
    private var activeService: NSSharingService?
    private var terminateFallbackWorkItem: DispatchWorkItem?

    override init() {
        super.init()
    }

    func terminateIfIdle() {
        if !hasAttemptedShare {
            NSApp.terminate(nil)
        }
    }

    func share(paths: [String]) {
        hasAttemptedShare = true

        let urls = normalizedFileURLs(from: paths)
        guard !urls.isEmpty else {
            terminateSoon()
            return
        }

        currentURLs = urls

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.presentPicker()
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

    private func presentPicker() {
        guard !currentURLs.isEmpty else {
            terminateSoon()
            return
        }

        anchorWindow.prepareForPicker()
        let anchorView = anchorWindow.anchorView

        let picker = NSSharingServicePicker(items: currentURLs)
        picker.delegate = self
        activePicker = picker
        picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        activePicker = nil

        guard let service else {
            anchorWindow.teardown()
            terminateSoon()
            return
        }

        activeService = service
        scheduleTerminateFallback(after: 30.0)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        self
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        _ = items
        cleanupAndTerminate()
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        _ = items
        _ = error
        cleanupAndTerminate()
    }

    private func terminateSoon() {
        cancelTerminateFallback()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }

    private func cleanupAndTerminate() {
        activeService = nil
        anchorWindow.teardown()
        terminateSoon()
    }

    private func scheduleTerminateFallback(after seconds: TimeInterval) {
        cancelTerminateFallback()
        let workItem = DispatchWorkItem { [weak self] in
            self?.cleanupAndTerminate()
        }
        terminateFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    private func cancelTerminateFallback() {
        terminateFallbackWorkItem?.cancel()
        terminateFallbackWorkItem = nil
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
        let mouse = NSEvent.mouseLocation
        panel.setFrame(NSRect(x: mouse.x, y: mouse.y, width: 2, height: 2), display: false)
        anchorView.frame = contentView.bounds
        panel.orderFrontRegardless()
    }

    func teardown() {
        panel.orderOut(nil)
    }
}
