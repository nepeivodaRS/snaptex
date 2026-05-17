import Foundation
import SwiftUI
import SnapTexCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HSplitView {
            settingsControlsPane
            logsSection
                .frame(minWidth: AppLayoutMetrics.settingsLogsPaneMinWidth)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.windowBackground)
        .tint(AppTheme.primaryButtonBackground)
        .preferredColorScheme(.dark)
        .modelDownloadAlert(model: model)
        .modelDeletionAlert(model: model)
    }

    private var settingsControlsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                modelsSection
                outputSection
                shortcutsSection
                textSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .rigidScrollBehavior()
        }
        .frame(
            minWidth: AppLayoutMetrics.settingsControlsPaneMinWidth,
            idealWidth: AppLayoutMetrics.settingsControlsPaneIdealWidth,
            maxWidth: AppLayoutMetrics.settingsControlsPaneMaxWidth
        )
    }

    private var modelsSection: some View {
        SettingsSection("Models") {
            ForEach(Self.modelSectionProviders) { provider in
                ModelProviderSubsection(provider: provider) {
                    ForEach(Self.modelVariants(for: provider)) { variant in
                        ModelManagementRow(
                            variant: variant,
                            state: model.modelState(for: variant),
                            isSelected: model.settings.modelVariant == variant,
                            action: {
                                model.selectModelVariant(variant)
                            },
                            isDownloadBlocked: model.isModelDownloadBlocked(for: variant),
                            canRevealFiles: model.canRevealModelFiles(variant),
                            revealAction: {
                                model.revealModelFilesInFinder(variant)
                            },
                            deleteAction: {
                                model.requestModelDeletion(variant)
                            }
                        )

                        if variant != Self.modelVariants(for: provider).last {
                            ModelRowSeparator()
                        }
                    }
                }

                if provider != Self.modelSectionProviders.last {
                    ModelRowSeparator()
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private static let modelSectionProviders: [OCRModelProvider] = [
        .uniMERNet,
        .paddlePaddle
    ]

    private static func modelVariants(for provider: OCRModelProvider) -> [UniMERModelVariant] {
        OCRModelSize.allCases.map { size in
            UniMERModelVariant(provider: provider, size: size)
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

            SettingsHistoryLimitRow(
                isUnlimited: unlimitedHistoryBinding,
                limit: limitedHistoryLimitBinding
            )
        }
    }

    private var shortcutsSection: some View {
        SettingsSection("Shortcuts") {
            SettingsRow("Snip") {
                ShortcutRecorderView(shortcut: $model.settings.snipShortcut)
                    .frame(width: 150, height: 28)
            }

            Divider()

            SettingsRow("Open app") {
                ShortcutRecorderView(shortcut: $model.settings.openAppShortcut)
                    .frame(width: 150, height: 28)
            }
        }
    }

    private var textSection: some View {
        SettingsSection("Text") {
            SettingsFontRow(
                title: "History snap titles",
                description: "Snap names in the History list",
                value: historyTitleFontSizeBinding
            )

            Divider()

            SettingsFontRow(
                title: "Sidebar labels",
                description: "All Snaps, Folders, and folder names",
                value: labelFontSizeBinding
            )

            Divider()

            SettingsFontRow(
                title: "Pane headings",
                description: "History, Capture, Output, LaTeX",
                value: paneTitleFontSizeBinding
            )

            Divider()

            SettingsFontRow(
                title: "Toolbar controls",
                description: "Model controls and status",
                value: toolbarFontSizeBinding
            )

            Divider()

            SettingsFontRow(
                title: "Snip button",
                description: "Main capture button text",
                value: snipButtonFontSizeBinding
            )

            Divider()

            SettingsFontRow(
                title: "Metadata text",
                description: "Timestamps, counts, model info, and alternatives",
                value: metadataFontSizeBinding
            )

            Divider()

            SettingsFontRow(
                title: "LaTeX editor",
                description: "Recognized LaTeX text editor",
                value: latexEditorFontSizeBinding
            )

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
                .rigidScrollBehavior()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .graphitePanel(background: AppTheme.panelBackground)
    }

    private var unlimitedHistoryBinding: Binding<Bool> {
        Binding(
            get: { !model.settings.isHistoryLimitEnabled },
            set: { model.settings.isHistoryLimitEnabled = !$0 }
        )
    }

    private var limitedHistoryLimitBinding: Binding<Int> {
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

    private var labelFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.labelFontSize },
            set: { model.settings.labelFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private var paneTitleFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.paneTitleFontSize },
            set: { model.settings.paneTitleFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private var toolbarFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.toolbarFontSize },
            set: { model.settings.toolbarFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private var snipButtonFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.snipButtonFontSize },
            set: { model.settings.snipButtonFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private var metadataFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.metadataFontSize },
            set: { model.settings.metadataFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

    private var latexEditorFontSizeBinding: Binding<Int> {
        Binding(
            get: { model.settings.latexEditorFontSize },
            set: { model.settings.latexEditorFontSize = AppSettingsSnapshot.clampedFontSize($0) }
        )
    }

}

private struct ModelProviderSubsection<Content: View>: View {
    let provider: OCRModelProvider
    @ViewBuilder let content: Content
    @State private var isHeaderHovered = false

    init(provider: OCRModelProvider, @ViewBuilder content: () -> Content) {
        self.provider = provider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Link(destination: provider.repositoryURL) {
                HStack(spacing: 6) {
                    Text(provider.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isHeaderHovered ? accentColor : Color.primary)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isHeaderHovered ? accentColor : Color.secondary)
                        .offset(x: isHeaderHovered ? 1 : 0, y: isHeaderHovered ? -1 : 0)
                }
                .lineLimit(1)
                .scaleEffect(isHeaderHovered ? 1.025 : 1, anchor: .leading)
            }
            .buttonStyle(.plain)
            .onHover { isHeaderHovered = $0 }
            .help("Open \(provider.title) repository")

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.14), value: isHeaderHovered)
    }

    private var accentColor: Color {
        switch provider {
        case .paddlePaddle:
            return Color(red: 0.49, green: 0.76, blue: 0.96)
        case .uniMERNet:
            return Color(red: 0.56, green: 0.78, blue: 0.61)
        }
    }
}

private struct ModelManagementRow: View {
    let variant: UniMERModelVariant
    let state: ManagedModelState
    let isSelected: Bool
    let action: () -> Void
    let isDownloadBlocked: Bool
    let canRevealFiles: Bool
    let revealAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(providerAccentColor)
                .frame(width: 3)
                .opacity(isSelected ? 1 : 0)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.title)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.68) : Color.secondary)
                        .lineLimit(1)
                }
                .frame(minWidth: AppLayoutMetrics.settingsModelTitleMinWidth, alignment: .leading)

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
                .disabled(
                    isDownloadBlocked ||
                    state.isDownloading ||
                    (isSelected && state.isInstalled)
                )

                SettingsIconActionButton(
                    systemImage: "folder",
                    isEnabled: canRevealFiles && !state.isDownloading,
                    help: "Reveal local \(variant.title) model files in Finder",
                    action: revealAction
                )

                SettingsIconActionButton(
                    systemImage: "trash",
                    role: .destructive,
                    isEnabled: state.isInstalled && !state.isDownloading,
                    help: "Delete local \(variant.title) model files",
                    action: deleteAction
                )
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                .fill(isSelected ? selectedModelFill : Color.clear)
        }
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }

    private var providerAccentColor: Color {
        switch variant.provider {
        case .paddlePaddle:
            return Color(red: 0.57, green: 0.65, blue: 0.72)
        case .uniMERNet:
            return Color(red: 0.61, green: 0.72, blue: 0.64)
        }
    }

    private var selectedModelFill: Color {
        Color.white.opacity(0.075)
    }

    private var statusText: String {
        switch state {
        case .available:
            return "Available"
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
        case .available, .installed:
            return isSelected ? "Selected" : "Use"
        case .missing, .failed:
            return "Download"
        case .downloading:
            return "Wait"
        }
    }
}

private struct ModelRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.045))
            .frame(height: 1)
            .padding(.leading, 10)
    }
}

private struct SettingsIconActionButton: View {
    let systemImage: String
    var role: ButtonRole?
    let isEnabled: Bool
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: isHovered && isEnabled ? .semibold : .regular))
                .frame(width: 22, height: 22)
                .foregroundStyle(foreground)
                .background {
                    Circle()
                        .fill(background)
                }
                .scaleEffect(isHovered && isEnabled ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .contentShape(Circle())
        .onHover { isHovered = $0 }
        .help(help)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var foreground: Color {
        guard isEnabled else {
            return Color.secondary.opacity(0.34)
        }
        if role == .destructive {
            return isHovered ? Color(red: 1.0, green: 0.48, blue: 0.44) : Color.secondary
        }
        return isHovered ? Color.primary : Color.secondary
    }

    private var background: Color {
        guard isEnabled, isHovered else {
            return Color.clear
        }
        if role == .destructive {
            return Color(red: 1.0, green: 0.48, blue: 0.44).opacity(0.14)
        }
        return Color.white.opacity(0.10)
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

private struct SettingsHistoryLimitRow: View {
    @Binding var isUnlimited: Bool
    @Binding var limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text("History limit")
                    .lineLimit(1)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    limitControls

                    Divider().frame(height: 18)

                    Toggle("Unlimited", isOn: $isUnlimited)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Text("Limited deletes oldest snaps beyond the limit. Unlimited keeps every snap.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var limitControls: some View {
        HStack(spacing: 6) {
            TextField("", value: $limit, formatter: Self.historyLimitFormatter)
                .multilineTextAlignment(.trailing)
                .graphiteTextInput(width: 54)

            Text("items")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper("", value: $limit, in: 4...200, step: 1)
                .labelsHidden()
                .controlSize(.small)
                .help("Increase or decrease by 1 item")
        }
        .disabled(isUnlimited)
        .opacity(isUnlimited ? 0.5 : 1)
    }

    private static let historyLimitFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 4
        formatter.maximum = 200
        return formatter
    }()
}

private struct SettingsFontRow: View {
    let title: String
    let description: String
    @Binding var value: Int

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                TextField("", value: $value, formatter: Self.fontSizeFormatter)
                    .multilineTextAlignment(.trailing)
                    .graphiteTextInput(width: 76, background: AppTheme.windowBackground)

                Text("pt")
                    .foregroundStyle(.secondary)

                Stepper("", value: $value, in: 10...28, step: 1)
                    .labelsHidden()
                    .controlSize(.small)
                    .help("Increase or decrease by 1 pt")
            }
            .frame(width: 138, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private static let fontSizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 10
        formatter.maximum = 28
        return formatter
    }()
}
