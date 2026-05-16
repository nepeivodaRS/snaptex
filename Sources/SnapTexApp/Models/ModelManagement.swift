import Foundation
import SnapTexCore

struct PendingModelDownload: Identifiable, Equatable {
    let variant: UniMERModelVariant

    var id: String {
        variant.rawValue
    }
}

struct PendingModelDeletion: Identifiable, Equatable {
    let variant: UniMERModelVariant

    var id: String {
        variant.rawValue
    }
}

struct ActiveModelDownload: Equatable {
    let variant: UniMERModelVariant
    let progress: Double?
}

enum ManagedModelState: Equatable {
    case available
    case installed
    case missing
    case downloading(progress: Double?)
    case failed(String)

    var isInstalled: Bool {
        if case .installed = self {
            return true
        }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }
}
