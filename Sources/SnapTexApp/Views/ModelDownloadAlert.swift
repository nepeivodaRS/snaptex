import SwiftUI
import SnapTexCore

extension View {
    func modelDownloadAlert(model: AppModel) -> some View {
        alert(item: Binding(
            get: { model.pendingModelDownload },
            set: { model.pendingModelDownload = $0 }
        )) { request in
            Alert(
                title: Text("Download \(request.variant.title) model?"),
                message: Text("The model is missing from \(model.settings.uniMERNetPath)."),
                primaryButton: .default(Text("Download")) {
                    model.downloadPendingModel()
                },
                secondaryButton: .cancel {
                    model.cancelPendingModelDownload()
                }
            )
        }
    }

    func modelDeletionAlert(model: AppModel) -> some View {
        alert(item: Binding(
            get: { model.pendingModelDeletion },
            set: { model.pendingModelDeletion = $0 }
        )) { request in
            Alert(
                title: Text("Delete \(request.variant.title) model?"),
                message: Text(deletionMessage(for: request.variant, model: model)),
                primaryButton: .destructive(Text("Delete")) {
                    model.deletePendingModel()
                },
                secondaryButton: .cancel {
                    model.cancelPendingModelDeletion()
                }
            )
        }
    }

    private func deletionMessage(for variant: UniMERModelVariant, model: AppModel) -> String {
        if variant.requiresManagedFiles {
            return "This removes the local model files from \(model.settings.uniMERNetPath)."
        }
        return "This clears local PaddleOCR cached model files when present."
    }
}
