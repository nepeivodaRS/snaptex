import SwiftUI
import SnapTexCore
import UniformTypeIdentifiers

struct CapturePreviewPane: View {
    @ObservedObject var model: AppModel
    @State private var isDropTargeted = false
    @State private var previewFontSize = RenderedPreviewZoom.defaultFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture")
                .font(.headline)

            captureSurface

            HStack {
                Text("Rendered Output")
                    .font(.headline)

                Spacer()

                previewZoomControls
            }

            previewSurface
        }
        .padding(14)
    }

    private var captureSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.24) : Color.secondary.opacity(0.10))

            if let image = model.capturedImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 42))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 180)
        .onDrop(
            of: [UTType.fileURL.identifier, UTType.image.identifier],
            isTargeted: $isDropTargeted,
            perform: model.importDroppedProviders
        )
    }

    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.25))

            if let issue = model.previewIssue {
                PreviewErrorView(issue: issue)
                    .padding(12)
            } else if model.previewLatex.isEmpty {
                Image(systemName: "function")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
            } else {
                LaTeXPreviewView(latex: model.previewLatex, fontSize: previewFontSize)
            }
        }
        .frame(minHeight: 170)
    }

    private var previewZoomControls: some View {
        HStack(spacing: 4) {
            Button {
                previewFontSize = RenderedPreviewZoom.zoomOut(from: previewFontSize)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .disabled(previewFontSize <= RenderedPreviewZoom.minimumFontSize)
            .help("Zoom out rendered output")

            Text("\(RenderedPreviewZoom.percent(for: previewFontSize))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .center)

            Button {
                previewFontSize = RenderedPreviewZoom.zoomIn(from: previewFontSize)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .disabled(previewFontSize >= RenderedPreviewZoom.maximumFontSize)
            .help("Zoom in rendered output")

            Button {
                previewFontSize = RenderedPreviewZoom.defaultFontSize
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(previewFontSize == RenderedPreviewZoom.defaultFontSize)
            .help("Reset rendered output zoom")
        }
        .controlSize(.small)
    }
}

private struct PreviewErrorView: View {
    let issue: LaTeXValidationIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Invalid LaTeX", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text(issue.message)
                .foregroundStyle(.primary)

            Text(issue.markedExcerpt)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
