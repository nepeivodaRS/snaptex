import SwiftUI
import SnapTexCore
import UniformTypeIdentifiers

struct CapturePreviewPane: View {
    @ObservedObject var model: AppModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture")
                .font(.headline)
                .foregroundStyle(.primary)

            captureSurface

            HStack {
                Text("Rendered Output")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let currentResultModel = model.currentResultModel {
                    Text("Model: \(currentResultModel.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

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
                .fill(isDropTargeted ? AppTheme.selectedBackground : AppTheme.insetBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isDropTargeted ? AppTheme.selectedBorder : AppTheme.border,
                            style: StrokeStyle(lineWidth: 1, dash: model.capturedImage == nil ? [5, 5] : [])
                        )
                }

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
        .graphitePanel(background: AppTheme.panelBackground)
        .onDrop(
            of: [UTType.fileURL.identifier, UTType.image.identifier],
            isTargeted: $isDropTargeted,
            perform: model.importDroppedProviders
        )
    }

    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.insetBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                }

            if let issue = model.previewIssue {
                PreviewErrorView(issue: issue)
                    .padding(12)
            } else if model.previewLatex.isEmpty {
                Image(systemName: "function")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
            } else {
                LaTeXPreviewView(latex: model.previewLatex, fontSize: model.renderedPreviewFontSize)
            }
        }
        .frame(minHeight: 170)
        .graphitePanel(background: AppTheme.panelBackground)
    }

    private var previewZoomControls: some View {
        HStack(spacing: 4) {
            ZoomIconButton(
                systemName: "minus.magnifyingglass",
                help: "Zoom out rendered output",
                isDisabled: model.renderedPreviewFontSize <= RenderedPreviewZoom.minimumFontSize
            ) {
                model.zoomRenderedPreviewOut()
            }

            Text("\(RenderedPreviewZoom.percent(for: model.renderedPreviewFontSize))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .center)

            ZoomIconButton(
                systemName: "plus.magnifyingglass",
                help: "Zoom in rendered output",
                isDisabled: model.renderedPreviewFontSize >= RenderedPreviewZoom.maximumFontSize
            ) {
                model.zoomRenderedPreviewIn()
            }

            ZoomIconButton(
                systemName: model.isRenderedPreviewZoomFixed ? "pin.fill" : "pin",
                help: model.isRenderedPreviewZoomFixed
                    ? "Use global rendered output size"
                    : "Fix rendered output size for this snap",
                isDisabled: !model.canFixRenderedPreviewZoom
            ) {
                model.toggleFixedRenderedPreviewZoom()
            }

            ZoomIconButton(
                systemName: "arrow.counterclockwise",
                help: "Reset rendered output zoom",
                isDisabled: model.renderedPreviewFontSize == RenderedPreviewZoom.defaultFontSize
            ) {
                model.resetRenderedPreviewZoom()
            }
        }
        .controlSize(.small)
        .foregroundStyle(.secondary)
    }
}

private struct ZoomIconButton: View {
    let systemName: String
    let help: String
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(ZoomIconButtonStyle(isHovered: isHovered))
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct ZoomIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary.opacity(isEnabled ? 1 : 0.38))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(AppTheme.primaryButtonBackground.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func backgroundOpacity(isPressed: Bool) -> Double {
        guard isEnabled else {
            return 0
        }
        if isPressed {
            return 0.18
        }
        return isHovered ? 0.10 : 0
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
                .background(AppTheme.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
