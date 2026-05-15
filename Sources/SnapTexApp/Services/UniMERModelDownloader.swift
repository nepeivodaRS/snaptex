import Foundation
import SnapTexCore

protocol UniMERModelDownloading {
    func download(
        variant: UniMERModelVariant,
        configuration: OCRWorkerConfiguration,
        progressHandler: @escaping (Double?) -> Void
    ) async throws
}

struct UniMERModelDownloader: UniMERModelDownloading {
    func download(
        variant: UniMERModelVariant,
        configuration: OCRWorkerConfiguration,
        progressHandler: @escaping (Double?) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try downloadSync(
                variant: variant,
                configuration: configuration,
                progressHandler: progressHandler
            )
        }.value
    }

    private func downloadSync(
        variant: UniMERModelVariant,
        configuration: OCRWorkerConfiguration,
        progressHandler: @escaping (Double?) -> Void
    ) throws {
        let pythonPath = try configuration.resolvedPythonPath()
        let modelsDirectory = URL(fileURLWithPath: configuration.uniMERNetPath)
            .appendingPathComponent("models")
        try FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true
        )

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [
            "-m",
            "snaptex_worker.download_model",
            "--variant",
            variant.rawValue,
            "--models-dir",
            modelsDirectory.path,
            "--progress-json"
        ]
        process.environment = environment(for: configuration)
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        let output = readOutput(from: outputPipe.fileHandleForReading, progressHandler: progressHandler)
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModelDownloadError.failed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func environment(for configuration: OCRWorkerConfiguration) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONNOUSERSITE"] = "1"
        environment["NO_ALBUMENTATIONS_UPDATE"] = "1"

        let packageRoot = URL(fileURLWithPath: configuration.workerScriptPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        if let existing = environment["PYTHONPATH"], !existing.isEmpty {
            environment["PYTHONPATH"] = "\(packageRoot):\(existing)"
        } else {
            environment["PYTHONPATH"] = packageRoot
        }

        return environment
    }

    private func readOutput(
        from handle: FileHandle,
        progressHandler: (Double?) -> Void
    ) -> String {
        var buffer = Data()
        var output = ""

        while true {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                break
            }
            if byte.first == 10 {
                if let line = String(data: buffer, encoding: .utf8) {
                    output += line + "\n"
                    handleLine(line, progressHandler: progressHandler)
                }
                buffer.removeAll(keepingCapacity: true)
            } else {
                buffer.append(byte)
            }
        }

        if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
            output += line
            handleLine(line, progressHandler: progressHandler)
        }

        return output
    }

    private func handleLine(_ line: String, progressHandler: (Double?) -> Void) {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(ModelDownloadProgressEvent.self, from: data) else {
            return
        }
        progressHandler(event.progress)
    }
}

private struct ModelDownloadProgressEvent: Decodable {
    let progress: Double?
}

private enum ModelDownloadError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let output):
            if output.isEmpty {
                return "Model download failed."
            }
            return output
        }
    }
}
