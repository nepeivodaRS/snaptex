import Foundation

public struct UniMERWorkerRequest: Codable, Equatable, Sendable {
    public let imagePath: String
    public let mode: RecognitionMode
    public let model: UniMERModelVariant
    public let modelStoragePath: String?
    public let validateRender: Bool
    public let logVerbosity: LogVerbosity

    public init(
        imagePath: String,
        mode: RecognitionMode,
        model: UniMERModelVariant,
        modelStoragePath: String? = nil,
        validateRender: Bool,
        logVerbosity: LogVerbosity = .normal
    ) {
        self.imagePath = imagePath
        self.mode = mode
        self.model = model
        self.modelStoragePath = modelStoragePath
        self.validateRender = validateRender
        self.logVerbosity = logVerbosity
    }

    private enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case mode
        case model
        case modelStoragePath = "model_storage_path"
        case validateRender = "validate_render"
        case logVerbosity = "log_verbosity"
    }
}

public struct UniMERWorkerResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let ready: Bool?
    public let prediction: String?
    public let alternatives: [String]?
    public let model: UniMERModelVariant?
    public let mode: RecognitionMode?
    public let error: String?

    public init(
        ok: Bool,
        ready: Bool? = nil,
        prediction: String? = nil,
        alternatives: [String]? = nil,
        model: UniMERModelVariant? = nil,
        mode: RecognitionMode? = nil,
        error: String? = nil
    ) {
        self.ok = ok
        self.ready = ready
        self.prediction = prediction
        self.alternatives = alternatives
        self.model = model
        self.mode = mode
        self.error = error
    }
}
