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
                    .lineLimit(1)

                if let currentResultModel = model.currentResultModel {
                    Text("Model: \(currentResultModel.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                ExportFormulaMenu(model: model)

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 22)

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

private struct ExportFormulaMenu: View {
    @ObservedObject var model: AppModel
    @State private var isExportHovered = false
    @State private var isExportPressed = false

    var body: some View {
        ZStack {
            ExportMenuLabel(
                isHovered: isExportHovered,
                isPressed: isExportPressed,
                isEnabled: model.canExportFormula
            )

            ExportFormulaMenuBridge(
                isHovered: $isExportHovered,
                isPressed: $isExportPressed,
                isEnabled: model.canExportFormula
            ) { format in
                model.exportFormula(as: format)
            }
            .frame(width: 88, height: 30)
        }
        .animation(.easeOut(duration: 0.12), value: isExportHovered)
        .animation(.easeOut(duration: 0.08), value: isExportPressed)
        .help("Export the rendered formula as a transparent PNG or EPS")
    }
}

private struct ExportMenuLabel: View {
    let isHovered: Bool
    let isPressed: Bool
    let isEnabled: Bool

    var body: some View {
        Label("Export", systemImage: "square.and.arrow.down")
            .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .fill(AppTheme.controlBackground.opacity(backgroundOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(color: AppTheme.primaryButtonBackground.opacity(isHovered && isEnabled ? 0.16 : 0), radius: 7, y: 1)
            .scaleEffect(isPressed ? 0.96 : isHovered && isEnabled ? 1.05 : 1)
            .offset(y: isHovered && isEnabled && !isPressed ? -2 : 0)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var backgroundOpacity: Double {
        guard isEnabled else {
            return 0.42
        }
        if isPressed {
            return 0.72
        }
        return isHovered ? 1 : 0.72
    }

    private var borderColor: Color {
        guard isEnabled else {
            return AppTheme.border
        }
        if isPressed {
            return AppTheme.selectedBorder
        }
        return isHovered ? AppTheme.primaryButtonBackground.opacity(0.40) : AppTheme.border
    }
}

private struct ExportFormulaMenuBridge: NSViewRepresentable {
    @Binding var isHovered: Bool
    @Binding var isPressed: Bool
    let isEnabled: Bool
    let export: (FormulaExportFormat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isHovered: $isHovered,
            isPressed: $isPressed,
            isEnabled: isEnabled,
            export: export
        )
    }

    func makeNSView(context: Context) -> ExportMenuTriggerView {
        let view = ExportMenuTriggerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: ExportMenuTriggerView, context: Context) {
        context.coordinator.isHovered = $isHovered
        context.coordinator.isPressed = $isPressed
        context.coordinator.isEnabled = isEnabled
        context.coordinator.export = export
        view.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var isHovered: Binding<Bool>
        var isPressed: Binding<Bool>
        var isEnabled: Bool
        var export: (FormulaExportFormat) -> Void

        init(
            isHovered: Binding<Bool>,
            isPressed: Binding<Bool>,
            isEnabled: Bool,
            export: @escaping (FormulaExportFormat) -> Void
        ) {
            self.isHovered = isHovered
            self.isPressed = isPressed
            self.isEnabled = isEnabled
            self.export = export
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()
            for (index, format) in FormulaExportFormat.allCases.enumerated() {
                let item = NSMenuItem(
                    title: format.title,
                    action: #selector(selectFormat(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = index
                item.target = self
                menu.addItem(item)
            }
            return menu
        }

        @objc private func selectFormat(_ sender: NSMenuItem) {
            guard let index = sender.representedObject as? Int,
                  FormulaExportFormat.allCases.indices.contains(index) else {
                return
            }
            export(FormulaExportFormat.allCases[index])
        }
    }

    final class ExportMenuTriggerView: NSView {
        weak var coordinator: Coordinator?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
                    owner: self
                )
            )
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard coordinator?.isEnabled == true,
                  let event = window?.currentEvent else {
                return nil
            }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                return self
            }
            return nil
        }

        override func mouseEntered(with event: NSEvent) {
            coordinator?.isHovered.wrappedValue = coordinator?.isEnabled == true
        }

        override func mouseExited(with event: NSEvent) {
            coordinator?.isHovered.wrappedValue = false
            coordinator?.isPressed.wrappedValue = false
        }

        override func mouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        override func rightMouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        private func showMenu(with event: NSEvent) {
            guard let coordinator, coordinator.isEnabled else {
                return
            }
            coordinator.isPressed.wrappedValue = true
            NSMenu.popUpContextMenu(coordinator.makeMenu(), with: event, for: self)
            coordinator.isPressed.wrappedValue = false
        }
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
