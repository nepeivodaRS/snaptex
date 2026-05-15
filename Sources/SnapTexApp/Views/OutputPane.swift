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
                OutputFormatMenu(
                    selection: $model.settings.outputFormat,
                    isDisabled: model.latexOutput.isEmpty || model.isProcessing
                )
            }
            .frame(maxWidth: .infinity)

            TextEditor(text: $model.latexOutput)
                .font(.system(
                    size: CGFloat(model.settings.latexEditorFontSize),
                    design: model.settings.latexEditorFontFamily.swiftUIDesign
                ))
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, minHeight: 160)

            VStack(alignment: .leading, spacing: 10) {
                Text("OCR Alternatives")
                    .font(.headline)

                if model.alternatives.isEmpty {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary.opacity(0.18))
                        .frame(height: 86)
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
                            .disabled(model.isProcessing)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppLayoutMetrics.outputPaneContentPadding)
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
            .background(.quaternary.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 7))
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
            .background(.quaternary.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Replace the editor contents with this alternative")
    }
}
