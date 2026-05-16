import Foundation

enum ScreenshotServiceError: LocalizedError {
    case captureToolUnavailable
    case missingOutputFile

    var errorDescription: String? {
        switch self {
        case .captureToolUnavailable:
            return "macOS screencapture is unavailable."
        case .missingOutputFile:
            return "Screenshot capture did not produce an image."
        }
    }
}

struct ScreenshotService {
    func captureInteractive() async throws -> URL? {
        try await Task.detached(priority: .userInitiated) {
            try captureInteractiveSync()
        }.value
    }

    static func validatedCaptureOutput(
        at outputURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL? {
        guard fileManager.fileExists(atPath: outputURL.path) else {
            return nil
        }

        let attributes = try fileManager.attributesOfItem(atPath: outputURL.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0 else {
            throw ScreenshotServiceError.missingOutputFile
        }

        return outputURL
    }
}

private func captureInteractiveSync() throws -> URL? {
    let screencapturePath = "/usr/sbin/screencapture"
    guard FileManager.default.isExecutableFile(atPath: screencapturePath) else {
        throw ScreenshotServiceError.captureToolUnavailable
    }

    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("snaptex-\(UUID().uuidString)")
        .appendingPathExtension("png")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: screencapturePath)
    process.arguments = ["-i", outputURL.path]
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        return nil
    }

    return try ScreenshotService.validatedCaptureOutput(at: outputURL)
}
