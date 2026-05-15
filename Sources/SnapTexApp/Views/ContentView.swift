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
        HStack(spacing: 12) {
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

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 26)
                .frame(width: 1)

            HStack(spacing: 6) {
                Text("OCR model")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: AppLayoutMetrics.toolbarModelLabelWidth, alignment: .leading)
                Picker("OCR model", selection: modelSelection) {
                    ForEach(UniMERModelVariant.allCases) { variant in
                        Text(variant.title).tag(variant)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)
                .disabled(!model.canChangeRecognitionSettings)
                .help("Choose which UniMERNet model size to use")
            }

            HStack(spacing: 6) {
                Text("OCR passes")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: AppLayoutMetrics.toolbarPassesLabelWidth, alignment: .leading)
                Picker("OCR passes", selection: $model.settings.recognitionMode) {
                    ForEach(RecognitionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 120)
                .disabled(!model.canChangeRecognitionSettings)
            }

            Spacer()

            if let activeDownload = model.activeModelDownload {
                HStack(spacing: 8) {
                    DownloadProgressView(progress: activeDownload.progress)
                        .frame(width: AppLayoutMetrics.toolbarDownloadProgressWidth)
                    Text("Downloading \(activeDownload.variant.title) model")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: AppLayoutMetrics.toolbarStatusWidth, alignment: .leading)
                }
            }

            if model.isCurrentItemRecognizing {
                ProgressView()
                    .controlSize(.small)
            }
            if model.activeModelDownload == nil {
                Text(model.toolbarStatusText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: AppLayoutMetrics.toolbarStatusWidth, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var modelSelection: Binding<UniMERModelVariant> {
        Binding(
            get: { model.settings.modelVariant },
            set: { model.selectModelVariant($0) }
        )
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
        if model.isSnipping {
            button
                .buttonStyle(GraphitePrimaryButtonStyle())
        } else {
            button
                .buttonStyle(GraphitePrimaryButtonStyle())
        }
    }

    private var button: some View {
        Button {
            model.snip()
        } label: {
            Label("Snip", systemImage: "crop")
        }
        .disabled(!model.canStartSnip)
        .help("Capture a screen region")
    }
}
