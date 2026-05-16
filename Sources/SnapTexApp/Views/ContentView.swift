import AppKit
import SwiftUI
import SnapTexCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    private let pasteboardTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(model: model)
                .padding(.vertical, 10)
                .padding(.leading, AppLayoutMetrics.toolbarLeadingPadding)
                .padding(.trailing, AppLayoutMetrics.outputPaneContentPadding)
                .background(AppTheme.windowBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }
            HSplitView {
                HistorySidebarView(model: model)
                    .frame(
                        minWidth: AppLayoutMetrics.historyPaneMinWidth,
                        idealWidth: AppLayoutMetrics.historyPaneIdealWidth,
                        maxWidth: AppLayoutMetrics.historyPaneMaxWidth
                    )
                CapturePreviewPane(model: model)
                    .frame(
                        minWidth: AppLayoutMetrics.capturePaneMinWidth,
                        idealWidth: AppLayoutMetrics.capturePaneIdealWidth
                    )
                OutputPane(model: model)
                    .frame(minWidth: AppLayoutMetrics.outputPaneMinWidth)
            }
        }
        .background(AppTheme.windowBackground)
        .tint(AppTheme.primaryButtonBackground)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPasteAvailability()
        }
        .onReceive(pasteboardTimer) { _ in
            model.refreshPasteAvailability()
        }
        .modelDownloadAlert(model: model)
    }
}

private struct ToolbarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            FullToolbarLayout(model: model)
            CompactToolbarLayout(model: model)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FullToolbarLayout: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            ToolbarActionStrip(model: model)
            ToolbarDivider()
            RecognitionControlGroup(model: model, showsLabels: true)

            Spacer(minLength: 12)
            ToolbarStatusView(model: model, compact: false)
        }
    }
}

private struct CompactToolbarLayout: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ToolbarActionStrip(model: model)
                Spacer(minLength: 8)
                ToolbarStatusView(model: model, compact: true)
            }

            RecognitionControlGroup(model: model, showsLabels: false)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ToolbarActionStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            SnipButton(model: model)

            Button {
                model.pasteImageFromClipboard()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(GraphiteSecondaryButtonStyle())
            .disabled(model.isSnipping || !model.canPasteImage)
            .help("Run OCR on an image from the clipboard")

            Button {
                model.retry()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GraphiteSecondaryButtonStyle())
            .disabled(!model.canRetry)
            .help("Run OCR again on the last input")

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
}

private struct RecognitionControlGroup: View {
    @ObservedObject var model: AppModel
    let showsLabels: Bool

    var body: some View {
        HStack(spacing: showsLabels ? 12 : 8) {
            HStack(spacing: 6) {
                if showsLabels {
                    Text("OCR model")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: AppLayoutMetrics.toolbarModelLabelWidth, alignment: .leading)
                }

                SmoothRecognitionSegmentedControl(
                    selection: modelSelection,
                    options: UniMERModelVariant.allCases,
                    width: showsLabels ? 210 : 174,
                    title: \.title
                )
                .help("Choose which UniMERNet model size to use")
            }

            HStack(spacing: 6) {
                if showsLabels {
                    Text("OCR passes")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: AppLayoutMetrics.toolbarPassesLabelWidth, alignment: .leading)
                }

                SmoothRecognitionSegmentedControl(
                    selection: $model.settings.recognitionMode,
                    options: RecognitionMode.allCases,
                    width: showsLabels ? 120 : 104,
                    title: \.title
                )
                .help("Choose how many OCR passes to run")
            }
        }
        .disabled(!model.canChangeRecognitionSettings)
    }

    private var modelSelection: Binding<UniMERModelVariant> {
        Binding(
            get: { model.settings.modelVariant },
            set: { model.selectModelVariant($0) }
        )
    }
}

private struct SmoothRecognitionSegmentedControl<Option: Identifiable & Equatable>: View {
    @Binding var selection: Option
    let options: [Option]
    let width: CGFloat
    let title: (Option) -> String

    @Environment(\.isEnabled) private var isEnabled
    @State private var hoveredOption: Option?

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                .fill(AppTheme.controlBackground.opacity(isEnabled ? 0.70 : 0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                }

            selectedIndicator

            HStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selection = option
                        }
                    } label: {
                        Text(title(option))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(foreground(for: option))
                            .frame(width: segmentWidth, height: 28)
                            .contentShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(segmentHoverColor(for: option))
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                    }
                    .onHover { isHovered in
                        hoveredOption = isHovered ? option : hoveredOption == option ? nil : hoveredOption
                    }
                }
            }
        }
        .frame(width: width, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
        .animation(.easeOut(duration: 0.12), value: hoveredOption?.id)
    }

    private var selectedIndicator: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(AppTheme.primaryButtonBackground.opacity(isEnabled ? 0.18 : 0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(AppTheme.primaryButtonBackground.opacity(isEnabled ? 0.26 : 0.10), lineWidth: 1)
            }
            .frame(width: segmentWidth - 4, height: 24)
            .offset(x: CGFloat(selectedIndex) * segmentWidth + 2)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedIndex)
    }

    private var segmentWidth: CGFloat {
        width / CGFloat(max(options.count, 1))
    }

    private var selectedIndex: Int {
        options.firstIndex(of: selection) ?? 0
    }

    private func foreground(for option: Option) -> Color {
        guard isEnabled else {
            return .primary.opacity(0.34)
        }
        if option == selection {
            return .primary
        }
        return hoveredOption == option ? .primary.opacity(0.88) : .secondary
    }

    private func segmentHoverColor(for option: Option) -> Color {
        guard isEnabled,
              hoveredOption == option,
              option != selection else {
            return Color.clear
        }
        return AppTheme.primaryButtonBackground.opacity(0.10)
    }
}

private struct ToolbarStatusView: View {
    @ObservedObject var model: AppModel
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let activeDownload = model.activeModelDownload {
                DownloadProgressView(progress: activeDownload.progress)
                    .frame(width: compact ? 86 : AppLayoutMetrics.toolbarDownloadProgressWidth)

                if !compact {
                    Text("Downloading \(activeDownload.variant.title) model")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: AppLayoutMetrics.toolbarStatusWidth, alignment: .leading)
                }
            } else {
                if model.isCurrentItemRecognizing {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(model.toolbarStatusText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: compact ? 120 : AppLayoutMetrics.toolbarStatusWidth, alignment: .trailing)
            }
        }
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: 26)
    }
}

private struct DownloadProgressView: View {
    let progress: Double?

    var body: some View {
        if let progress {
            ProgressView(value: progress)
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }
}

private struct SnipButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button {
            model.snip()
        } label: {
            Label("Snip", systemImage: "crop")
        }
        .buttonStyle(GraphitePrimaryButtonStyle())
        .disabled(!model.canStartSnip)
        .help("Capture a screen region")
    }
}
