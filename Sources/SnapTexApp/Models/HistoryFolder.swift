import SwiftUI

struct HistoryFolder: Identifiable, Equatable {
    let id: UUID
    let name: String
    let color: HistoryFolderColor
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: HistoryFolderColor = .gray,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }

    func renamed(to name: String) -> HistoryFolder {
        HistoryFolder(id: id, name: name, color: color, createdAt: createdAt)
    }

    func recolored(to color: HistoryFolderColor) -> HistoryFolder {
        HistoryFolder(id: id, name: name, color: color, createdAt: createdAt)
    }
}

enum HistoryFolderColor: String, CaseIterable, Identifiable {
    case gray
    case blue
    case green
    case yellow
    case orange
    case red
    case purple

    var id: String { rawValue }

    static let automaticSequence: [HistoryFolderColor] = [
        .blue,
        .green,
        .yellow,
        .orange,
        .red,
        .purple,
        .gray
    ]

    var title: String {
        switch self {
        case .gray:
            return "Gray"
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .red:
            return "Red"
        case .purple:
            return "Purple"
        }
    }

    var tint: Color {
        switch self {
        case .gray:
            return .secondary
        case .blue:
            return .blue
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        case .red:
            return .red
        case .purple:
            return .purple
        }
    }
}

enum HistoryScope: Equatable, Hashable, Identifiable {
    case all
    case folder(HistoryFolder.ID)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .folder(let id):
            return "folder-\(id.uuidString)"
        }
    }
}

enum HistoryFolderDropPlacement: Equatable {
    case before
    case after
}

enum HistorySortMode: String, CaseIterable, Identifiable {
    case time
    case folder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .time:
            return "Time"
        case .folder:
            return "Folder"
        }
    }

    var menuTitle: String {
        "Sort by \(title)"
    }

    var systemName: String {
        switch self {
        case .time:
            return "clock"
        case .folder:
            return "folder"
        }
    }
}
