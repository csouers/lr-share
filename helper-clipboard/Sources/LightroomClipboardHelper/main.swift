import AppKit
import Foundation
import UniformTypeIdentifiers

enum HelperError: Error, CustomStringConvertible {
    case noReadableFiles
    case unsupportedImageType(path: String)
    case readFailed(path: String)
    case pasteboardWriteFailed
    case unknown

    var description: String {
        switch self {
        case .noReadableFiles:
            return "No readable files were provided."
        case .unsupportedImageType(let path):
            return "Unsupported image type: \(path)"
        case .readFailed(let path):
            return "Failed to read file: \(path)"
        case .pasteboardWriteFailed:
            return "Failed to write to clipboard."
        case .unknown:
            return "Unknown error occurred."
        }
    }
}

func normalizedReadableFileURLs(from paths: [String]) -> [URL] {
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

func inferredImageType(for url: URL) -> UTType? {
    let fileExtension = url.pathExtension
    guard !fileExtension.isEmpty else {
        return nil
    }

    guard let type = UTType(filenameExtension: fileExtension) else {
        return nil
    }

    guard type.conforms(to: .image) else {
        return nil
    }

    return type
}

func copyToClipboard(paths: [String]) -> Result<Int, HelperError> {
    let urls = normalizedReadableFileURLs(from: paths)
    guard !urls.isEmpty else {
        return .failure(.noReadableFiles)
    }

    var items: [NSPasteboardItem] = []
    items.reserveCapacity(urls.count)

    for url in urls {
        guard let imageType = inferredImageType(for: url) else {
            return .failure(.unsupportedImageType(path: url.path))
        }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            return .failure(.readFailed(path: url.path))
        }

        let item = NSPasteboardItem()
        let pasteboardType = NSPasteboard.PasteboardType(imageType.identifier)
        guard item.setData(fileData, forType: pasteboardType) else {
            return .failure(.pasteboardWriteFailed)
        }

        items.append(item)
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    guard pasteboard.writeObjects(items) else {
        return .failure(.pasteboardWriteFailed)
    }

    return .success(items.count)
}

// Main entry point - no arguments needed for clipboard mode
let arguments = Array(CommandLine.arguments.dropFirst())

let result = copyToClipboard(paths: arguments)

switch result {
case .success(let count):
    fputs("LightroomClipboardHelper: Copied \(count) image(s) to clipboard.\n", stderr)
    Darwin.exit(0)
case .failure(let error):
    fputs("LightroomClipboardHelper: \(error.description)\n", stderr)
    Darwin.exit(1)
}