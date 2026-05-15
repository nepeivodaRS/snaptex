import SwiftUI

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
                message: Text("This removes the local model files from \(model.settings.uniMERNetPath)."),
                primaryButton: .destructive(Text("Delete")) {
                    model.deletePendingModel()
                },
                secondaryButton: .cancel {
                    model.cancelPendingModelDeletion()
                }
            )
        }
    }
}
