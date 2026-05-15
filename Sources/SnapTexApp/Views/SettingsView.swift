import Foundation
import SwiftUI
import SnapTexCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    modelsSection
                    outputSection
                    shortcutsSection
                    textSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

            logsSection
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.windowBackground)
        .tint(AppTheme.primaryButtonBackground)
        .preferredColorScheme(.dark)
        .modelDownloadAlert(model: model)
        .modelDeletionAlert(model: model)
    }

    private var modelsSection: some View {
        SettingsSection("Models") {
            ForEach(UniMERModelVariant.allCases) { variant in
                ModelManagementRow(
                    variant: variant,
                    state: model.modelState(for: variant),
                    isSelected: model.settings.modelVariant == variant,
                    action: {
                        model.selectModelVariant(variant)
                    },
                    canRevealFiles: model.canRevealModelFiles(variant),
                    revealAction: {
                        model.revealModelFilesInFinder(variant)
                    },
                    deleteAction: {
                        model.requestModelDeletion(variant)
                    }
                )

                if variant != UniMERModelVariant.allCases.last {
                    Divider()
                }
            }
        }
    }

    private var outputSection: some View {
        SettingsSection("Output") {
            SettingsRow("Format") {
                Picker("Format", selection: $model.settings.outputFormat) {
                    ForEach(LaTeXOutputFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .labelsHidden()
            }

            Divider()

            Toggle("Copy after recognition", isOn: $model.settings.autoCopyAfterRecognition)

            Divider()

            SettingsRow("History limit") {
                HStack(spacing: 8) {
                    TextField("", value: historyLimitBinding, formatter: Self.historyLimitFormatter)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 76)
                    Text("items")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var shortcutsSection: some View {
        SettingsSection("Shortcuts") {
            SettingsRow("Snip") {
                ShortcutRecorderView(shortcut: $model.settings.snipShortcut)
                    .frame(width: 150, height: 28)
            }
        }
    }

    private var textSection: some View {
        SettingsSection("Text") {
            SettingsRow("History title") {
                pointSizeField(value: historyTitleFontSizeBinding)
            }

            Divider()

            SettingsRow("LaTeX size") {
                pointSizeField(value: latexEditorFontSizeBinding)
            }

            Divider()

            SettingsRow("LaTeX font") {
                Picker("LaTeX font", selection: $model.settings.latexEditorFontFamily) {
                    ForEach(LaTeXEditorFontFamily.allCases) { fontFamily in
                        Text(fontFamily.title).tag(fontFamily)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logs")
                    .font(.headline)
                Spacer()
                Picker("Log verbosity", selection: $model.settings.logVerbosity) {
                    ForEach(LogVerbosity.allCases) { verbosity in
                        Text(verbosity.title).tag(verbosity)
                    }
                }
                .labelsHidden()
                .frame(width: 116)
                .help("Choose how much recognition detail is written to logs")

                Button {
                    model.clearLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(GraphiteSecondaryButtonStyle())
                .disabled(model.logs.isEmpty)
            }

            TextEditor(text: $model.logs)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(AppTheme.insetBackground)
                .graphitePanel(background: AppTheme.insetBackground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .graphitePanel(background: AppTheme.panelBackground)
    }

    private var historyLimitBinding: Binding<Int> {
        Binding(
            get: { model.settings.historyLimit },
            set: { model.settings.historyLimit = min(200, max(4, $0)) }
        )
    }

    private var historyTitleFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.historyTitleFontSize },
            set: { model.settings.historyTitleFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private var latexEditorFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.latexEditorFontSize },
            set: { model.settings.latexEditorFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private func pointSizeField(value: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            TextField("", value: value, formatter: Self.fontSizeFormatter)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 76)
            Text("pt")
                .foregroundStyle(.secondary)
        }
    }

    private static let historyLimitFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 4
        formatter.maximum = 200
        return formatter
    }()

    private static let fontSizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 10
        formatter.maximum = 28
        return formatter
    }()
}

private struct ModelManagementRow: View {
    let variant: UniMERModelVariant
    let state: ManagedModelState
    let isSelected: Bool
    let action: () -> Void
    let canRevealFiles: Bool
    let revealAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(variant.title)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if case .downloading(let progress) = state {
                if let progress {
                    ProgressView(value: progress)
                        .frame(width: 96)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Button(action: action) {
                Text(buttonTitle)
                    .frame(width: 70)
            }
            .buttonStyle(GraphiteSecondaryButtonStyle())
            .disabled(state.isDownloading || (state.isInstalled && isSelected))

            Button(action: revealAction) {
                Image(systemName: "folder")
                    .frame(width: 18)
            }
            .buttonStyle(.borderless)
            .disabled(!canRevealFiles || state.isDownloading)
            .help("Reveal local \(variant.title) model files in Finder")

            Button(role: .destructive, action: deleteAction) {
                Image(systemName: "trash")
                    .frame(width: 18)
            }
            .buttonStyle(.borderless)
            .disabled(!state.isInstalled || state.isDownloading)
            .help("Delete local \(variant.title) model files")
        }
    }

    private var statusText: String {
        switch state {
        case .installed:
            return isSelected ? "Installed, selected" : "Installed"
        case .missing:
            return "Missing"
        case .downloading(let progress):
            if let progress {
                return "Downloading \(Int((progress * 100).rounded()))%"
            }
            return "Downloading"
        case .failed(let message):
            return message.isEmpty ? "Download failed" : message
        }
    }

    private var buttonTitle: String {
        switch state {
        case .installed:
            return isSelected ? "Selected" : "Use"
        case .missing, .failed:
            return "Download"
        case .downloading:
            return "Wait"
        }
    }
}

private struct SettingsSection<Content: View>: View {
    private let title: String?
    @ViewBuilder private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 2)
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .graphitePanel(background: AppTheme.panelBackground)
        }
    }
}

private struct SettingsRow<Content: View>: View {
    private let title: String
    @ViewBuilder private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 24)
            HStack {
                Spacer(minLength: 0)
                content
            }
            .frame(width: 190, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}
