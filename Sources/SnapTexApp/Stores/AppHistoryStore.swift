import Foundation
import SnapTexCore

struct AppHistoryStore {
    struct State: Equatable {
        var history: [OCRHistoryEntry]
        var historyFolders: [HistoryFolder]
        var selectedHistoryID: OCRHistoryEntry.ID?
        var selectedHistoryScope: HistoryScope
        var historySortMode: HistorySortMode
        var globalRenderedPreviewFontSize: Int

        static let empty = State(
            history: [],
            historyFolders: [],
            selectedHistoryID: nil,
            selectedHistoryScope: .all,
            historySortMode: .time,
            globalRenderedPreviewFontSize: RenderedPreviewZoom.defaultFontSize
        )
    }

    private enum Storage {
        case defaults(UserDefaults)
        case volatile
    }

    private let key = "AppHistorySnapshot"
    private let storage: Storage

    init(defaults: UserDefaults = .standard) {
        self.storage = .defaults(defaults)
    }

    private init(storage: Storage) {
        self.storage = storage
    }

    static func defaultStore(for settingsStore: AppSettingsStore) -> AppHistoryStore {
        if settingsStore.usesStandardDefaults,
           isRunningUnitTests {
            return AppHistoryStore(storage: .volatile)
        }
        return AppHistoryStore(defaults: settingsStore.defaults)
    }

    private static var isRunningUnitTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil ||
            environment["__XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil ||
            NSClassFromString("XCTest.XCTestCase") != nil
    }

    func load() -> State {
        guard case .defaults(let defaults) = storage,
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return .empty
        }

        return snapshot.state.normalized()
    }

    func save(_ state: State) {
        guard case .defaults(let defaults) = storage,
              let data = try? JSONEncoder().encode(Snapshot(state: state.normalized())) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

private struct Snapshot: Codable {
    let version: Int
    let entries: [StoredHistoryEntry]
    let folders: [StoredHistoryFolder]
    let selectedHistoryID: UUID?
    let selectedHistoryScope: StoredHistoryScope
    let historySortMode: String
    let globalRenderedPreviewFontSize: Int

    init(state: AppHistoryStore.State) {
        self.version = 1
        self.entries = state.history.map(StoredHistoryEntry.init)
        self.folders = state.historyFolders.map(StoredHistoryFolder.init)
        self.selectedHistoryID = state.selectedHistoryID
        self.selectedHistoryScope = StoredHistoryScope(state.selectedHistoryScope)
        self.historySortMode = state.historySortMode.rawValue
        self.globalRenderedPreviewFontSize = RenderedPreviewZoom.clamped(state.globalRenderedPreviewFontSize)
    }

    var state: AppHistoryStore.State {
        AppHistoryStore.State(
            history: entries.map(\.historyEntry),
            historyFolders: folders.map(\.historyFolder),
            selectedHistoryID: selectedHistoryID,
            selectedHistoryScope: selectedHistoryScope.historyScope,
            historySortMode: HistorySortMode(rawValue: historySortMode) ?? .time,
            globalRenderedPreviewFontSize: RenderedPreviewZoom.clamped(globalRenderedPreviewFontSize)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case entries
        case folders
        case selectedHistoryID
        case selectedHistoryScope
        case historySortMode
        case globalRenderedPreviewFontSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.entries = try container.decodeIfPresent([StoredHistoryEntry].self, forKey: .entries) ?? []
        self.folders = try container.decodeIfPresent([StoredHistoryFolder].self, forKey: .folders) ?? []
        self.selectedHistoryID = try container.decodeIfPresent(UUID.self, forKey: .selectedHistoryID)
        self.selectedHistoryScope = try container.decodeIfPresent(
            StoredHistoryScope.self,
            forKey: .selectedHistoryScope
        ) ?? .all
        self.historySortMode = try container.decodeIfPresent(String.self, forKey: .historySortMode) ?? HistorySortMode.time.rawValue
        self.globalRenderedPreviewFontSize = try container.decodeIfPresent(
            Int.self,
            forKey: .globalRenderedPreviewFontSize
        ) ?? RenderedPreviewZoom.defaultFontSize
    }
}

private struct StoredHistoryFolder: Codable {
    let id: UUID
    let name: String
    let color: String
    let createdAt: Date

    init(_ folder: HistoryFolder) {
        self.id = folder.id
        self.name = folder.name
        self.color = folder.color.rawValue
        self.createdAt = folder.createdAt
    }

    var historyFolder: HistoryFolder {
        HistoryFolder(
            id: id,
            name: name,
            color: HistoryFolderColor(rawValue: color) ?? .gray,
            createdAt: createdAt
        )
    }
}

private struct StoredHistoryEntry: Codable {
    let id: UUID
    let title: String
    let timestamp: Date
    let latex: String
    let rawPrediction: String
    let alternatives: [StoredLaTeXAlternative]
    let outputFormat: LaTeXOutputFormat
    let model: UniMERModelVariant
    let mode: RecognitionMode
    let imageURLPath: String?
    let ownsImageFile: Bool
    let imageFingerprint: String
    let state: StoredHistoryEntryState
    let folderID: HistoryFolder.ID?
    let fixedRenderedPreviewFontSize: Int?

    init(_ entry: OCRHistoryEntry) {
        self.id = entry.id
        self.title = entry.title
        self.timestamp = entry.timestamp
        self.latex = entry.latex
        self.rawPrediction = entry.rawPrediction
        self.alternatives = entry.alternatives.enumerated().map { index, alternative in
            StoredLaTeXAlternative(alternative, fallbackRank: index)
        }
        self.outputFormat = entry.outputFormat
        self.model = entry.model
        self.mode = entry.mode
        self.imageURLPath = entry.imageURL?.path
        self.ownsImageFile = entry.ownsImageFile
        self.imageFingerprint = entry.imageFingerprint
        self.state = StoredHistoryEntryState(entry.state)
        self.folderID = entry.folderID
        self.fixedRenderedPreviewFontSize = entry.fixedRenderedPreviewFontSize
    }

    var historyEntry: OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives.map(\.latexAlternative),
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: nil,
            imageURL: imageURLPath.map { URL(fileURLWithPath: $0) },
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: state.historyEntryState,
            folderID: folderID,
            fixedRenderedPreviewFontSize: fixedRenderedPreviewFontSize
        )
    }
}

private struct StoredLaTeXAlternative: Codable {
    let title: String
    let latex: String
    let rank: Int

    init(_ alternative: LaTeXAlternative, fallbackRank: Int) {
        self.title = alternative.title
        self.latex = alternative.latex
        self.rank = Self.rank(from: alternative.id) ?? fallbackRank
    }

    var latexAlternative: LaTeXAlternative {
        LaTeXAlternative(title: title, latex: latex, rank: rank)
    }

    private static func rank(from id: String) -> Int? {
        let rank = id.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
        return Int(rank)
    }
}

private enum StoredHistoryEntryState: Codable {
    case recognizing
    case recognized
    case failed(String)

    init(_ state: OCRHistoryEntryState) {
        switch state {
        case .recognizing:
            self = .recognizing
        case .recognized:
            self = .recognized
        case .failed(let message):
            self = .failed(message)
        }
    }

    var historyEntryState: OCRHistoryEntryState {
        switch self {
        case .recognizing:
            return .failed("Recognition interrupted")
        case .recognized:
            return .recognized
        case .failed(let message):
            return .failed(message)
        }
    }
}

private enum StoredHistoryScope: Codable {
    case all
    case folder(UUID)

    init(_ scope: HistoryScope) {
        switch scope {
        case .all:
            self = .all
        case .folder(let folderID):
            self = .folder(folderID)
        }
    }

    var historyScope: HistoryScope {
        switch self {
        case .all:
            return .all
        case .folder(let folderID):
            return .folder(folderID)
        }
    }
}

private extension AppHistoryStore.State {
    func normalized() -> AppHistoryStore.State {
        let folderIDs = Set(historyFolders.map(\.id))
        let normalizedHistory = history.map { entry in
            guard let folderID = entry.folderID,
                  !folderIDs.contains(folderID) else {
                return entry
            }
            return entry.assigned(to: nil)
        }
        let normalizedSelectedID = selectedHistoryID.flatMap { selectedID in
            normalizedHistory.contains { $0.id == selectedID } ? selectedID : nil
        }
        let normalizedScope: HistoryScope
        switch selectedHistoryScope {
        case .all:
            normalizedScope = .all
        case .folder(let folderID):
            normalizedScope = folderIDs.contains(folderID) ? .folder(folderID) : .all
        }

        return AppHistoryStore.State(
            history: normalizedHistory,
            historyFolders: historyFolders,
            selectedHistoryID: normalizedSelectedID,
            selectedHistoryScope: normalizedScope,
            historySortMode: historySortMode,
            globalRenderedPreviewFontSize: RenderedPreviewZoom.clamped(globalRenderedPreviewFontSize)
        )
    }
}
