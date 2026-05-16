import Foundation

public struct AppSettingsSnapshot: Codable, Equatable, Sendable {
    public var condaPath: String
    public var environmentName: String
    public var uniMERNetPath: String
    public var modelVariant: UniMERModelVariant
    public var recognitionMode: RecognitionMode
    public var outputFormat: LaTeXOutputFormat
    public var validateRender: Bool
    public var autoCopyAfterRecognition: Bool
    public var historyLimit: Int
    public var historyTitleFontSize: Int
    public var labelFontSize: Int
    public var latexEditorFontSize: Int
    public var latexEditorFontFamily: LaTeXEditorFontFamily
    public var logVerbosity: LogVerbosity
    public var workerScriptPath: String
    public var snipShortcut: GlobalKeyboardShortcut

    public init(
        condaPath: String,
        environmentName: String,
        uniMERNetPath: String,
        modelVariant: UniMERModelVariant,
        recognitionMode: RecognitionMode,
        outputFormat: LaTeXOutputFormat,
        validateRender: Bool,
        autoCopyAfterRecognition: Bool,
        historyLimit: Int,
        historyTitleFontSize: Int,
        labelFontSize: Int,
        latexEditorFontSize: Int,
        latexEditorFontFamily: LaTeXEditorFontFamily,
        logVerbosity: LogVerbosity,
        workerScriptPath: String,
        snipShortcut: GlobalKeyboardShortcut
    ) {
        self.condaPath = condaPath
        self.environmentName = environmentName
        self.uniMERNetPath = uniMERNetPath
        self.modelVariant = modelVariant
        self.recognitionMode = recognitionMode
        self.outputFormat = outputFormat
        self.validateRender = true
        self.autoCopyAfterRecognition = autoCopyAfterRecognition
        self.historyLimit = historyLimit
        self.historyTitleFontSize = Self.clampedFontSize(historyTitleFontSize)
        self.labelFontSize = Self.clampedFontSize(labelFontSize)
        self.latexEditorFontSize = Self.clampedFontSize(latexEditorFontSize)
        self.latexEditorFontFamily = latexEditorFontFamily
        self.logVerbosity = logVerbosity
        self.workerScriptPath = workerScriptPath
        self.snipShortcut = snipShortcut
    }

    private enum CodingKeys: String, CodingKey {
        case condaPath
        case environmentName
        case uniMERNetPath
        case modelVariant
        case recognitionMode
        case outputFormat
        case validateRender
        case autoCopyAfterRecognition
        case historyLimit
        case historyTitleFontSize
        case labelFontSize
        case latexEditorFontSize
        case latexEditorFontFamily
        case logVerbosity
        case workerScriptPath
        case snipShortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default

        condaPath = try container.decodeIfPresent(String.self, forKey: .condaPath) ?? defaults.condaPath
        environmentName = try container.decodeIfPresent(String.self, forKey: .environmentName) ?? defaults.environmentName
        uniMERNetPath = try container.decodeIfPresent(String.self, forKey: .uniMERNetPath) ?? defaults.uniMERNetPath
        modelVariant = try container.decodeIfPresent(UniMERModelVariant.self, forKey: .modelVariant) ?? defaults.modelVariant
        recognitionMode = try container.decodeIfPresent(RecognitionMode.self, forKey: .recognitionMode) ?? defaults.recognitionMode
        outputFormat = try container.decodeIfPresent(LaTeXOutputFormat.self, forKey: .outputFormat) ?? defaults.outputFormat
        validateRender = true
        autoCopyAfterRecognition = try container.decodeIfPresent(Bool.self, forKey: .autoCopyAfterRecognition) ?? defaults.autoCopyAfterRecognition
        historyLimit = max(4, try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? defaults.historyLimit)
        historyTitleFontSize = Self.clampedFontSize(try container.decodeIfPresent(Int.self, forKey: .historyTitleFontSize) ?? defaults.historyTitleFontSize)
        labelFontSize = Self.clampedFontSize(try container.decodeIfPresent(Int.self, forKey: .labelFontSize) ?? defaults.labelFontSize)
        latexEditorFontSize = Self.clampedFontSize(try container.decodeIfPresent(Int.self, forKey: .latexEditorFontSize) ?? defaults.latexEditorFontSize)
        latexEditorFontFamily = try container.decodeIfPresent(LaTeXEditorFontFamily.self, forKey: .latexEditorFontFamily) ?? defaults.latexEditorFontFamily
        logVerbosity = try container.decodeIfPresent(LogVerbosity.self, forKey: .logVerbosity) ?? defaults.logVerbosity
        workerScriptPath = Self.resolvedWorkerScriptPath(
            savedPath: try container.decodeIfPresent(String.self, forKey: .workerScriptPath) ?? defaults.workerScriptPath
        )
        snipShortcut = try container.decodeIfPresent(GlobalKeyboardShortcut.self, forKey: .snipShortcut) ?? defaults.snipShortcut
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(condaPath, forKey: .condaPath)
        try container.encode(environmentName, forKey: .environmentName)
        try container.encode(uniMERNetPath, forKey: .uniMERNetPath)
        try container.encode(modelVariant, forKey: .modelVariant)
        try container.encode(recognitionMode, forKey: .recognitionMode)
        try container.encode(outputFormat, forKey: .outputFormat)
        try container.encode(true, forKey: .validateRender)
        try container.encode(autoCopyAfterRecognition, forKey: .autoCopyAfterRecognition)
        try container.encode(max(4, historyLimit), forKey: .historyLimit)
        try container.encode(Self.clampedFontSize(historyTitleFontSize), forKey: .historyTitleFontSize)
        try container.encode(Self.clampedFontSize(labelFontSize), forKey: .labelFontSize)
        try container.encode(Self.clampedFontSize(latexEditorFontSize), forKey: .latexEditorFontSize)
        try container.encode(latexEditorFontFamily, forKey: .latexEditorFontFamily)
        try container.encode(logVerbosity, forKey: .logVerbosity)
        try container.encode(workerScriptPath, forKey: .workerScriptPath)
        try container.encode(snipShortcut, forKey: .snipShortcut)
    }

    public static let `default` = AppSettingsSnapshot(
        condaPath: AppSettingsSnapshot.defaultCondaPath(),
        environmentName: "snaptex",
        uniMERNetPath: AppSettingsSnapshot.defaultUniMERNetPath(),
        modelVariant: .small,
        recognitionMode: .fast,
        outputFormat: .raw,
        validateRender: true,
        autoCopyAfterRecognition: false,
        historyLimit: 40,
        historyTitleFontSize: 13,
        labelFontSize: 12,
        latexEditorFontSize: 14,
        latexEditorFontFamily: .monospaced,
        logVerbosity: .normal,
        workerScriptPath: AppSettingsSnapshot.defaultWorkerScriptPath(),
        snipShortcut: .defaultSnip
    )

    public static func clampedFontSize(_ size: Int) -> Int {
        min(28, max(10, size))
    }

    public static func defaultUniMERNetPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        for key in ["SNAPTEX_UNIMERNET_DIR", "UNIMERNET_DIR"] {
            if let configured = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !configured.isEmpty {
                return expandTilde(in: configured, homeDirectory: homeDirectory)
            }
        }

        return homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("snaptex")
            .appendingPathComponent("UniMERNet")
            .path
    }

    public static func defaultWorkerScriptPath(
        fileManager: FileManager = .default,
        resourceDirectory: URL? = Bundle.main.resourceURL
    ) -> String {
        let relativePath = "python/snaptex_worker/worker.py"
        if let bundledPath = resourceDirectory?.appendingPathComponent(relativePath).path,
           fileManager.fileExists(atPath: bundledPath) {
            return bundledPath
        }

        return relativePath
    }

    public static func resolvedWorkerScriptPath(
        savedPath: String,
        fileManager: FileManager = .default,
        resourceDirectory: URL? = Bundle.main.resourceURL
    ) -> String {
        let trimmedPath = savedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultPath = defaultWorkerScriptPath(
            fileManager: fileManager,
            resourceDirectory: resourceDirectory
        )

        guard !trimmedPath.isEmpty else {
            return defaultPath
        }

        if fileManager.fileExists(atPath: trimmedPath) {
            return trimmedPath
        }

        if trimmedPath.contains("python/unimer_latex_ocr/worker.py")
            || trimmedPath.contains("python/snaptex_worker/worker.py") {
            return defaultPath
        }

        return trimmedPath
    }

    public static func defaultCondaPath(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let homeCandidates = [
            homeDirectory.appendingPathComponent("miniforge3/bin/conda").path,
            homeDirectory.appendingPathComponent("miniconda3/bin/conda").path,
            homeDirectory.appendingPathComponent("anaconda3/bin/conda").path
        ]
        let candidates = [
            environment["CONDA_EXE"]
        ].compactMap { $0 } + homeCandidates + [
            "/opt/homebrew/bin/conda",
            "/usr/local/bin/conda"
        ]

        return candidates.first { fileManager.isExecutableFile(atPath: $0) } ?? "conda"
    }

    private static func expandTilde(in path: String, homeDirectory: URL) -> String {
        if path == "~" {
            return homeDirectory.path
        }
        if path.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(path.dropFirst(2))).path
        }
        return path
    }
}

public enum LogVerbosity: String, CaseIterable, Codable, Identifiable, Sendable {
    case normal
    case verbose
    case debug

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .verbose:
            return "Verbose"
        case .debug:
            return "Debug"
        }
    }

    public func includes(_ minimum: LogVerbosity) -> Bool {
        rank >= minimum.rank
    }

    private var rank: Int {
        switch self {
        case .normal:
            return 0
        case .verbose:
            return 1
        case .debug:
            return 2
        }
    }
}

public enum LaTeXEditorFontFamily: String, CaseIterable, Codable, Identifiable, Sendable {
    case monospaced
    case system
    case serif

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .monospaced:
            return "SF Mono"
        case .system:
            return "System"
        case .serif:
            return "Serif"
        }
    }
}
