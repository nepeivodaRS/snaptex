import SwiftUI
import SnapTexCore

struct OutputPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LaTeX")
                    .font(.headline)
                Spacer()
                OutputCopyButton(model: model)
                OutputFormatMenu(
                    selection: outputFormatSelection,
                    isDisabled: !model.canChangeOutputFormat
                )
            }
            .frame(maxWidth: .infinity)

            TextEditor(text: $model.latexOutput)
                .font(.system(
                    size: CGFloat(model.settings.latexEditorFontSize),
                    design: model.settings.latexEditorFontFamily.swiftUIDesign
                ))
                .scrollContentBackground(.hidden)
                .background(AppTheme.insetBackground)
                .graphitePanel(background: AppTheme.insetBackground)
                .frame(maxWidth: .infinity, minHeight: 160)

            VStack(alignment: .leading, spacing: 10) {
                Text("OCR Alternatives")
                    .font(.headline)

                if model.alternatives.isEmpty {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.insetBackground)
                        .frame(height: 86)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(AppTheme.border, lineWidth: 1)
                        }
                        .overlay {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 26))
                                .foregroundStyle(.tertiary)
                        }
                } else {
                    VStack(spacing: 8) {
                        ForEach(model.alternatives) { alternative in
                            AlternativeRow(alternative: alternative) {
                                model.applyAlternative(alternative)
                            }
                            .disabled(!model.canApplyAlternatives)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppLayoutMetrics.outputPaneContentPadding)
        .background(AppTheme.windowBackground)
    }

    private var outputFormatSelection: Binding<LaTeXOutputFormat> {
        Binding(
            get: { model.currentOutputFormat },
            set: { model.setCurrentOutputFormat($0) }
        )
    }
}

private struct OutputCopyButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button {
            model.copyLatex()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .buttonStyle(GraphiteSecondaryButtonStyle())
        .disabled(!model.canCopy)
        .help("Copy visible LaTeX")
    }
}

private struct OutputFormatMenu: View {
    @Binding var selection: LaTeXOutputFormat
    let isDisabled: Bool

    var body: some View {
        Menu {
            ForEach(LaTeXOutputFormat.allCases) { format in
                Button {
                    selection = format
                } label: {
                    HStack {
                        Text(format.title)
                        if selection == format {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(selection.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(width: 145, height: 28)
            .background(AppTheme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            .opacity(isDisabled ? 0.55 : 1)
        }
        .disabled(isDisabled)
    }
}

private extension LaTeXEditorFontFamily {
    var swiftUIDesign: Font.Design {
        switch self {
        case .monospaced:
            return .monospaced
        case .system:
            return .default
        case .serif:
            return .serif
        }
    }
}

private struct AlternativeRow: View {
    let alternative: LaTeXAlternative
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(alternative.title)
                    .font(.subheadline.weight(.semibold))

                Text(alternative.latex)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(9)
            .graphitePanel(background: AppTheme.raisedPanelBackground, radius: 6)
        }
        .buttonStyle(.plain)
        .help("Replace the editor contents with this alternative")
    }
}
