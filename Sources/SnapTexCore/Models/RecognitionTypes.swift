import Foundation

public enum RecognitionMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case fast
    case balanced
    case accurate

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fast:
            return "1"
        case .balanced:
            return "2"
        case .accurate:
            return "3"
        }
    }

    public var passCount: Int {
        switch self {
        case .fast:
            return 1
        case .balanced:
            return 2
        case .accurate:
            return 3
        }
    }
}

public enum OCRModelProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case uniMERNet = "unimernet"
    case paddlePaddle = "paddlepaddle"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .uniMERNet:
            return "UniMERNet"
        case .paddlePaddle:
            return "PaddlePaddle"
        }
    }

    public var repositoryURL: URL {
        switch self {
        case .uniMERNet:
            return URL(string: "https://github.com/opendatalab")!
        case .paddlePaddle:
            return URL(string: "https://github.com/PaddlePaddle")!
        }
    }
}

public enum OCRModelSize: String, CaseIterable, Codable, Identifiable, Sendable {
    case small = "s"
    case medium = "m"
    case large = "l"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small:
            return "S"
        case .medium:
            return "M"
        case .large:
            return "L"
        }
    }

    public var descriptiveTitle: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }
}

public struct OCRModelSelection: CaseIterable, Codable, Hashable, Identifiable, Sendable {
    public let provider: OCRModelProvider
    public let size: OCRModelSize

    public init(provider: OCRModelProvider, size: OCRModelSize) {
        self.provider = provider
        self.size = size
    }

    public var id: String { rawValue }

    public var rawValue: String {
        "\(provider.rawValue)-\(size.rawValue)"
    }

    public var title: String {
        "\(provider.title) \(size.title)"
    }

    public var workerModelName: String {
        switch provider {
        case .uniMERNet:
            return uniMERNetVariantName
        case .paddlePaddle:
            return "PP-FormulaNet_plus-\(size.title)"
        }
    }

    public var directoryName: String {
        switch provider {
        case .uniMERNet:
            return "unimernet_\(uniMERNetVariantName)"
        case .paddlePaddle:
            return workerModelName
        }
    }

    public var requiresManagedFiles: Bool {
        provider == .uniMERNet
    }

    public static let allCases: [OCRModelSelection] = OCRModelProvider.allCases.flatMap { provider in
        OCRModelSize.allCases.map { size in
            OCRModelSelection(provider: provider, size: size)
        }
    }

    public static let tiny = OCRModelSelection(provider: .uniMERNet, size: .small)
    public static let small = OCRModelSelection(provider: .uniMERNet, size: .medium)
    public static let base = OCRModelSelection(provider: .uniMERNet, size: .large)

    private var uniMERNetVariantName: String {
        switch size {
        case .small:
            return "tiny"
        case .medium:
            return "small"
        case .large:
            return "base"
        }
    }

    public func isInstalled(
        in uniMERNetPath: String,
        fileManager: FileManager = .default
    ) -> Bool {
        guard requiresManagedFiles else {
            return true
        }
        return modelFileCandidates(in: uniMERNetPath).contains {
            fileManager.fileExists(atPath: $0.path)
        }
    }

    public func modelFileCandidates(in uniMERNetPath: String) -> [URL] {
        guard requiresManagedFiles else {
            return []
        }

        let root = URL(fileURLWithPath: (uniMERNetPath as NSString).expandingTildeInPath)
        let modelsDirectory = root.appendingPathComponent("models")
        let modelDirectory = modelsDirectory.appendingPathComponent(directoryName)
        return [
            modelsDirectory.appendingPathComponent("\(directoryName).pth"),
            modelDirectory.appendingPathComponent("\(directoryName).pth"),
            modelDirectory.appendingPathComponent("pytorch_model.bin"),
            modelDirectory.appendingPathComponent("pytorch_model.pth")
        ]
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let provider = try container.decodeIfPresent(OCRModelProvider.self, forKey: .provider),
           let size = try container.decodeIfPresent(OCRModelSize.self, forKey: .size) {
            self.init(provider: provider, size: size)
            return
        }

        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        if let selection = Self(legacyIdentifier: identifier) {
            self = selection
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unknown OCR model selection: \(identifier)"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(size, forKey: .size)
    }

    private init?(legacyIdentifier: String) {
        switch legacyIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "tiny", "s", "unimernet-s", "unimernet-tiny":
            self = .tiny
        case "small", "m", "unimernet-m", "unimernet-small":
            self = .small
        case "base", "l", "unimernet-l", "unimernet-base":
            self = .base
        case "paddlepaddle-s", "pp-formulanet_plus-s":
            self.init(provider: .paddlePaddle, size: .small)
        case "paddlepaddle-m", "pp-formulanet_plus-m":
            self.init(provider: .paddlePaddle, size: .medium)
        case "paddlepaddle-l", "pp-formulanet_plus-l":
            self.init(provider: .paddlePaddle, size: .large)
        default:
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case provider
        case size
    }
}

public typealias UniMERModelVariant = OCRModelSelection

public struct UniMERRecognitionResult: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let latex: String
    public let model: UniMERModelVariant
    public let mode: RecognitionMode
    public let alternatives: [String]

    public init(
        id: UUID = UUID(),
        latex: String,
        model: UniMERModelVariant,
        mode: RecognitionMode,
        alternatives: [String] = []
    ) {
        self.id = id
        self.latex = latex
        self.model = model
        self.mode = mode
        self.alternatives = alternatives
    }
}
