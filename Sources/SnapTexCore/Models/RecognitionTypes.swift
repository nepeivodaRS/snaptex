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

public enum UniMERModelVariant: String, CaseIterable, Codable, Identifiable, Sendable {
    case tiny
    case small
    case base

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .small:
            return "Small"
        case .base:
            return "Base"
        }
    }

    public var directoryName: String {
        "unimernet_\(rawValue)"
    }

    public func isInstalled(
        in uniMERNetPath: String,
        fileManager: FileManager = .default
    ) -> Bool {
        modelFileCandidates(in: uniMERNetPath).contains {
            fileManager.fileExists(atPath: $0.path)
        }
    }

    public func modelFileCandidates(in uniMERNetPath: String) -> [URL] {
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
}

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
