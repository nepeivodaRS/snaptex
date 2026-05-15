import Foundation

public struct OCRWorkerConfiguration: Equatable, Sendable {
    public var condaPath: String
    public var environmentName: String
    public var workerScriptPath: String
    public var uniMERNetPath: String

    public init(
        condaPath: String,
        environmentName: String,
        workerScriptPath: String,
        uniMERNetPath: String
    ) {
        self.condaPath = condaPath
        self.environmentName = environmentName
        self.workerScriptPath = workerScriptPath
        self.uniMERNetPath = uniMERNetPath
    }

    public func resolvedPythonPath(fileManager: FileManager = .default) throws -> String {
        let condaURL = URL(fileURLWithPath: condaPath)
        let root = condaURL.deletingLastPathComponent().deletingLastPathComponent()
        let pythonURL = root
            .appendingPathComponent("envs")
            .appendingPathComponent(environmentName)
            .appendingPathComponent("bin")
            .appendingPathComponent("python")
        let path = pythonURL.path
        guard fileManager.isExecutableFile(atPath: path) else {
            throw OCRWorkerClientError.missingPython(path)
        }
        return path
    }
}

public enum OCRWorkerClientError: LocalizedError {
    case missingPipe
    case workerExited
    case invalidUTF8
    case invalidReadyResponse(String)
    case workerError(String)
    case emptyPrediction
    case missingPython(String)

    public var errorDescription: String? {
        switch self {
        case .missingPipe:
            return "OCR worker pipes are unavailable."
        case .workerExited:
            return "OCR worker exited before returning a response."
        case .invalidUTF8:
            return "OCR worker returned non-UTF-8 output."
        case .invalidReadyResponse(let response):
            return "OCR worker did not become ready: \(response)"
        case .workerError(let message):
            return message
        case .emptyPrediction:
            return "OCR worker returned an empty prediction."
        case .missingPython(let path):
            return "Conda environment Python was not found at \(path)."
        }
    }
}

public final class OCRWorkerClient: @unchecked Sendable {
    public var logHandler: ((String) -> Void)?

    private var configuration: OCRWorkerConfiguration
    private let lock = NSLock()
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var errorPipe: Pipe?

    public init(configuration: OCRWorkerConfiguration) {
        self.configuration = configuration
    }

    deinit {
        stop()
    }

    public func updateConfiguration(_ configuration: OCRWorkerConfiguration) {
        lock.lock()
        let changed = self.configuration != configuration
        self.configuration = configuration
        lock.unlock()

        if changed {
            stop()
        }
    }

    public func predict(request: UniMERWorkerRequest) async throws -> UniMERRecognitionResult {
        try await Task.detached(priority: .userInitiated) {
            try self.predictSync(request: request)
        }.value
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        if let inputHandle {
            try? inputHandle.write(contentsOf: Data("quit\n".utf8))
            try? inputHandle.close()
        }
        process?.terminate()
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        inputHandle = nil
        outputHandle = nil
        errorPipe = nil
    }

    private func predictSync(request: UniMERWorkerRequest) throws -> UniMERRecognitionResult {
        lock.lock()
        defer { lock.unlock() }

        try startIfNeeded()

        guard let inputHandle else {
            throw OCRWorkerClientError.missingPipe
        }

        let data = try JSONEncoder().encode(request)
        try inputHandle.write(contentsOf: data + Data("\n".utf8))

        let response = try readResponse()
        guard response.ok else {
            throw OCRWorkerClientError.workerError(response.error ?? "OCR worker failed.")
        }
        guard let prediction = response.prediction, !prediction.isEmpty else {
            throw OCRWorkerClientError.emptyPrediction
        }

        return UniMERRecognitionResult(
            latex: prediction,
            model: response.model ?? request.model,
            mode: response.mode ?? request.mode,
            alternatives: response.alternatives ?? [prediction]
        )
    }

    private func startIfNeeded() throws {
        if process?.isRunning == true {
            return
        }

        let pythonPath = try configuration.resolvedPythonPath()
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [
            configuration.workerScriptPath,
            "--unimernet-path",
            configuration.uniMERNetPath
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONNOUSERSITE"] = "1"
        environment["NO_ALBUMENTATIONS_UPDATE"] = "1"
        process.environment = environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            self?.logHandler?(text)
        }

        try process.run()

        self.process = process
        self.inputHandle = inputPipe.fileHandleForWriting
        self.outputHandle = outputPipe.fileHandleForReading
        self.errorPipe = errorPipe

        let readyResponse = try readResponse()
        guard readyResponse.ok, readyResponse.ready == true else {
            throw OCRWorkerClientError.invalidReadyResponse(readyResponse.error ?? "Unknown startup response.")
        }
    }

    private func readResponse() throws -> UniMERWorkerResponse {
        let line = try readLine()
        guard let data = line.data(using: .utf8) else {
            throw OCRWorkerClientError.invalidUTF8
        }
        return try JSONDecoder().decode(UniMERWorkerResponse.self, from: data)
    }

    private func readLine() throws -> String {
        guard let outputHandle else {
            throw OCRWorkerClientError.missingPipe
        }

        var data = Data()
        while true {
            let byte = outputHandle.readData(ofLength: 1)
            if byte.isEmpty {
                throw OCRWorkerClientError.workerExited
            }
            if byte.first == 10 {
                break
            }
            data.append(byte)
        }

        guard let line = String(data: data, encoding: .utf8) else {
            throw OCRWorkerClientError.invalidUTF8
        }
        return line
    }
}

private func + (left: Data, right: Data) -> Data {
    var data = left
    data.append(right)
    return data
}
