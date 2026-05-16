import AppKit
import Foundation
import SnapTexCore
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettingsSnapshot {
        didSet {
            settingsStore.save(settings)
            let oldWorkerConfiguration = Self.workerConfiguration(for: oldValue)
            let newWorkerConfiguration = Self.workerConfiguration(for: settings)
            if oldWorkerConfiguration != newWorkerConfiguration {
                worker.updateConfiguration(newWorkerConfiguration)
            }
            if oldValue.uniMERNetPath != settings.uniMERNetPath {
                refreshModelStatuses()
            }
            if oldValue.outputFormat != settings.outputFormat, selectedHistoryID == nil {
                applyCurrentOutputFormat(settings.outputFormat)
            }
            if oldValue.isHistoryLimitEnabled != settings.isHistoryLimitEnabled ||
                oldValue.historyLimit != settings.historyLimit {
                trimHistoryToLimit()
            }
        }
    }
    @Published var capturedImage: NSImage?
    @Published var rawPrediction = ""
    @Published var latexOutput = "" {
        didSet {
            updateEditorMetadata()
            schedulePreviewUpdate()
            syncSelectedHistoryOutput()
        }
    }
    @Published var alternatives: [LaTeXAlternative] = []
    @Published var previewLatex = ""
    @Published var previewIssue: LaTeXValidationIssue?
    @Published var globalRenderedPreviewFontSize = RenderedPreviewZoom.defaultFontSize
    @Published var history: [OCRHistoryEntry] = []
    @Published var selectedHistoryID: OCRHistoryEntry.ID?
    @Published private(set) var currentResultModel: UniMERModelVariant?
    @Published var status = "Ready"
    @Published var logs = ""
    @Published var isProcessing = false
    @Published var isSnipping = false
    @Published var canPasteImage = false
    @Published var validationIssue: LaTeXValidationIssue?
    @Published private(set) var installedModels: Set<UniMERModelVariant> = []
    @Published private(set) var modelDownloadStates: [UniMERModelVariant: ManagedModelState] = [:]
    @Published var historyFolders: [HistoryFolder] = []
    @Published var selectedHistoryScope: HistoryScope = .all
    @Published var historySortMode: HistorySortMode = .time
    @Published var pendingModelDownload: PendingModelDownload?
    @Published var pendingModelDeletion: PendingModelDeletion?

    private let settingsStore: AppSettingsStore
    private let screenshotService = ScreenshotService()
    private let modelDownloader: UniMERModelDownloading
    private lazy var worker = OCRWorkerClient(configuration: workerConfiguration)
    private var lastImageURL: URL?
    private var currentImageFingerprint: String?
    private var currentBodyLatex = ""
    private var previewUpdateTask: Task<Void, Never>?
    private var activeRecognitionCount = 0
    private let pendingHistoryTitle = "Recognizing..."

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        modelDownloader: UniMERModelDownloading = UniMERModelDownloader()
    ) {
        self.settingsStore = settingsStore
        self.modelDownloader = modelDownloader
        self.settings = settingsStore.load()
        worker.logHandler = { [weak self] message in
            Task { @MainActor in
                self?.appendLog(message)
            }
        }
        refreshModelStatuses()
        refreshPasteAvailability()
    }

    var canRetry: Bool {
        guard !isSnipping, !isCurrentItemRecognizing else {
            return false
        }

        if let selectedHistoryID {
            guard let entry = history.first(where: { $0.id == selectedHistoryID }) else {
                return false
            }
            return entry.image != nil || imageFileExists(at: entry.imageURL)
        }

        return imageFileExists(at: lastImageURL)
    }

    var canStartSnip: Bool {
        !isSnipping
    }

    var canCopy: Bool {
        !latexOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canExportFormula: Bool {
        !previewLatex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            previewIssue == nil &&
            selectedHistoryEntry?.state != .recognizing
    }

    var currentOutputFormat: LaTeXOutputFormat {
        selectedHistoryEntry?.outputFormat ?? settings.outputFormat
    }

    var canChangeOutputFormat: Bool {
        canCopy && selectedHistoryEntry?.state != .recognizing
    }

    var canApplyAlternatives: Bool {
        !alternatives.isEmpty && selectedHistoryEntry?.state != .recognizing
    }

    var canChangeRecognitionSettings: Bool {
        !isSnipping && !isCurrentItemRecognizing
    }

    var isCurrentItemRecognizing: Bool {
        selectedHistoryEntry?.state == .recognizing
    }

    var toolbarStatusText: String {
        if isCurrentItemRecognizing {
            return "Recognizing"
        }
        return status
    }

    var renderedPreviewFontSize: Int {
        selectedHistoryEntry?.fixedRenderedPreviewFontSize ?? globalRenderedPreviewFontSize
    }

    var isRenderedPreviewZoomFixed: Bool {
        selectedHistoryEntry?.fixedRenderedPreviewFontSize != nil
    }

    var canFixRenderedPreviewZoom: Bool {
        selectedHistoryEntry != nil
    }

    var visibleHistory: [OCRHistoryEntry] {
        switch selectedHistoryScope {
        case .all:
            return sortedAllHistory
        case .folder(let folderID):
            return history.filter { $0.folderID == folderID }
        }
    }

    var unfiledHistoryCount: Int {
        history.filter { $0.folderID == nil }.count
    }

    private var activeHistoryFolderID: HistoryFolder.ID? {
        if case .folder(let folderID) = selectedHistoryScope,
           historyFolders.contains(where: { $0.id == folderID }) {
            return folderID
        }
        return nil
    }

    private var selectedHistoryEntry: OCRHistoryEntry? {
        guard let selectedHistoryID else {
            return nil
        }
        return history.first(where: { $0.id == selectedHistoryID })
    }

    private var sortedAllHistory: [OCRHistoryEntry] {
        switch historySortMode {
        case .time:
            return history
        case .folder:
            return history.sorted { first, second in
                let firstFolderKey = historyFolderSortKey(for: first.folderID)
                let secondFolderKey = historyFolderSortKey(for: second.folderID)
                if firstFolderKey != secondFolderKey {
                    return firstFolderKey.localizedStandardCompare(secondFolderKey) == .orderedAscending
                }
                return first.timestamp > second.timestamp
            }
        }
    }

    var activeModelDownload: ActiveModelDownload? {
        for variant in UniMERModelVariant.allCases {
            if case .downloading(let progress) = modelDownloadStates[variant] {
                return ActiveModelDownload(variant: variant, progress: progress)
            }
        }
        return nil
    }

    func modelState(for variant: UniMERModelVariant) -> ManagedModelState {
        if !variant.requiresManagedFiles {
            return .available
        }
        if let state = modelDownloadStates[variant], state.isDownloading {
            return state
        }
        if installedModels.contains(variant) {
            return .installed
        }
        return modelDownloadStates[variant] ?? .missing
    }

    func refreshModelStatuses(fileManager: FileManager = .default) {
        installedModels = Set(
            UniMERModelVariant.allCases.filter {
                $0.requiresManagedFiles &&
                $0.isInstalled(in: settings.uniMERNetPath, fileManager: fileManager)
            }
        )
    }

    func selectModelVariant(_ variant: UniMERModelVariant) {
        let state = modelState(for: variant)
        if state.isInstalled {
            settings.modelVariant = variant
            pendingModelDownload = nil
        } else if !state.isDownloading {
            requestModelDownload(variant)
        }
    }

    func requestModelDownload(_ variant: UniMERModelVariant) {
        guard variant.requiresManagedFiles,
              !modelState(for: variant).isDownloading else {
            return
        }
        pendingModelDownload = PendingModelDownload(variant: variant)
        status = "\(variant.title) model is missing"
    }

    func cancelPendingModelDownload() {
        pendingModelDownload = nil
    }

    func downloadPendingModel() {
        guard let variant = pendingModelDownload?.variant else {
            return
        }
        pendingModelDownload = nil
        startModelDownload(variant, selectWhenComplete: true)
    }

    func requestModelDeletion(_ variant: UniMERModelVariant) {
        let state = modelState(for: variant)
        guard state.isInstalled,
              !state.isDownloading else {
            return
        }
        pendingModelDeletion = PendingModelDeletion(variant: variant)
    }

    func cancelPendingModelDeletion() {
        pendingModelDeletion = nil
    }

    func deletePendingModel() {
        guard let variant = pendingModelDeletion?.variant else {
            return
        }
        pendingModelDeletion = nil
        deleteModel(variant)
    }

    func canRevealModelFiles(_ variant: UniMERModelVariant) -> Bool {
        modelRevealURL(for: variant) != nil
    }

    func revealModelFilesInFinder(_ variant: UniMERModelVariant) {
        guard let url = modelRevealURL(for: variant) else {
            status = "\(variant.title) model files unavailable"
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        status = "Revealed \(variant.title) model"
    }

    func snip() {
        guard canStartSnip else {
            return
        }
        guard ensureSelectedModelAvailable() else {
            return
        }
        Task {
            await captureAndPredict()
        }
    }

    func pasteImageFromClipboard() {
        guard !isSnipping, let image = NSImage(pasteboard: .general) else {
            refreshPasteAvailability()
            return
        }
        guard ensureSelectedModelAvailable() else {
            return
        }
        Task {
            await importImage(image)
        }
    }

    func retry() {
        guard canRetry else {
            return
        }
        guard ensureSelectedModelAvailable() else {
            return
        }
        Task {
            do {
                guard let input = try makeRetryInput() else {
                    return
                }
                let entryID = insertPendingHistoryEntry(
                    image: input.image,
                    imageURL: input.imageURL,
                    ownsImageFile: input.ownsImageFile,
                    imageFingerprint: input.imageFingerprint,
                    mode: settings.recognitionMode,
                    model: settings.modelVariant
                )
                await predict(imageURL: input.imageURL, entryID: entryID)
            } catch {
                status = "Retry failed"
                appendLog(error.localizedDescription)
            }
        }
    }

    func copyLatex() {
        guard canCopy else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latexOutput, forType: .string)
        status = "Copied"
    }

    func exportFormula(as format: FormulaExportFormat) {
        guard canExportFormula else {
            return
        }

        let bodyLatex = previewLatex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bodyLatex.isEmpty else {
            status = "No formula to export"
            return
        }
        if let issue = previewIssue ?? LaTeXValidator.firstIssue(in: bodyLatex) {
            status = "Cannot export invalid LaTeX"
            appendLog(issue.message)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Formula"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "snaptex-formula.\(format.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        status = "Exporting \(format.title)..."
        Task { [bodyLatex, fontSize = renderedPreviewFontSize, format, url] in
            do {
                let exporter = FormulaImageExporter()
                try await exporter.export(
                    latex: bodyLatex,
                    fontSize: fontSize,
                    format: format,
                    to: url
                )
                status = "Exported \(format.title)"
            } catch {
                status = "Export failed"
                appendLog(error.localizedDescription)
            }
        }
    }

    func applyAlternative(_ latex: String) {
        applyAlternative(LaTeXAlternative(title: "Alternative", latex: latex, rank: 0))
    }

    func applyAlternative(_ alternative: LaTeXAlternative) {
        currentBodyLatex = alternative.latex
        rawPrediction = alternative.latex
        latexOutput = currentOutputFormat.apply(to: alternative.latex)
        validationIssue = LaTeXValidator.firstIssue(in: alternative.latex)
        status = "Alternative applied"
    }

    func setCurrentOutputFormat(_ outputFormat: LaTeXOutputFormat) {
        guard canChangeOutputFormat else {
            return
        }

        let bodyLatex = LaTeXSource.mathBody(from: latexOutput)
        guard !bodyLatex.isEmpty else {
            return
        }

        let formattedLatex = outputFormat.apply(to: bodyLatex)
        if let selectedHistoryID,
           let index = history.firstIndex(where: { $0.id == selectedHistoryID }) {
            let entry = history[index]
            guard entry.state != .recognizing else {
                return
            }
            history[index] = entry.updatedOutput(
                latex: formattedLatex,
                rawPrediction: rawPrediction,
                alternatives: alternatives,
                outputFormat: outputFormat
            )
        } else {
            settings.outputFormat = outputFormat
        }

        currentBodyLatex = bodyLatex
        latexOutput = formattedLatex
        validationIssue = LaTeXValidator.firstIssue(in: bodyLatex)
        status = "Format updated"
    }

    func zoomRenderedPreviewIn() {
        setRenderedPreviewFontSize(RenderedPreviewZoom.zoomIn(from: renderedPreviewFontSize))
    }

    func zoomRenderedPreviewOut() {
        setRenderedPreviewFontSize(RenderedPreviewZoom.zoomOut(from: renderedPreviewFontSize))
    }

    func resetRenderedPreviewZoom() {
        setRenderedPreviewFontSize(RenderedPreviewZoom.defaultFontSize)
    }

    func toggleFixedRenderedPreviewZoom() {
        guard let selectedHistoryID,
              let index = history.firstIndex(where: { $0.id == selectedHistoryID }) else {
            return
        }

        if history[index].fixedRenderedPreviewFontSize == nil {
            history[index] = history[index].fixedRenderedPreviewFontSize(to: renderedPreviewFontSize)
            status = "Fixed rendered output size"
        } else {
            history[index] = history[index].fixedRenderedPreviewFontSize(to: nil)
            status = "Using global rendered output size"
        }
    }

    func selectHistoryScope(_ scope: HistoryScope) {
        selectedHistoryScope = normalizedHistoryScope(scope)
        reconcileSelectedHistoryWithCurrentScope()
    }

    @discardableResult
    func createHistoryFolder(
        named name: String? = nil,
        color: HistoryFolderColor? = nil
    ) -> HistoryFolder {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let folder = HistoryFolder(
            name: trimmedName.isEmpty ? nextHistoryFolderName() : trimmedName,
            color: color ?? nextHistoryFolderColor()
        )
        historyFolders.insert(folder, at: 0)
        selectedHistoryScope = .folder(folder.id)
        reconcileSelectedHistoryWithCurrentScope()
        status = "Created folder"
        return folder
    }

    func renameHistoryFolder(_ folder: HistoryFolder, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = historyFolders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        historyFolders[index] = historyFolders[index].renamed(to: trimmedName)
        status = "Renamed folder"
    }

    func updateHistoryFolderColor(_ folder: HistoryFolder, color: HistoryFolderColor) {
        guard let index = historyFolders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        historyFolders[index] = historyFolders[index].recolored(to: color)
        status = "Updated folder color"
    }

    func moveHistoryFolder(
        withID sourceID: HistoryFolder.ID,
        relativeTo targetID: HistoryFolder.ID,
        placement: HistoryFolderDropPlacement
    ) {
        guard sourceID != targetID,
              let sourceIndex = historyFolders.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = historyFolders.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let movedFolder = historyFolders.remove(at: sourceIndex)
        let adjustedTargetIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        let insertionIndex: Int
        switch placement {
        case .before:
            insertionIndex = adjustedTargetIndex
        case .after:
            insertionIndex = adjustedTargetIndex + 1
        }
        historyFolders.insert(movedFolder, at: insertionIndex)
        status = "Moved folder"
    }

    func deleteHistoryFolderKeepingSnaps(_ folder: HistoryFolder) {
        guard let index = historyFolders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        historyFolders.remove(at: index)
        history = history.map { entry in
            entry.folderID == folder.id ? entry.assigned(to: nil) : entry
        }
        if selectedHistoryScope == .folder(folder.id) {
            selectedHistoryScope = .all
        }
        status = "Removed folder"
    }

    func deleteHistoryFolderAndSnaps(_ folder: HistoryFolder) {
        guard let index = historyFolders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        let removedEntries = history.filter { $0.folderID == folder.id }
        historyFolders.remove(at: index)
        history.removeAll { $0.folderID == folder.id }
        removeOwnedImageFiles(for: removedEntries)

        if selectedHistoryScope == .folder(folder.id) {
            selectedHistoryScope = .all
        }
        if let selectedHistoryID,
           removedEntries.contains(where: { $0.id == selectedHistoryID }) {
            if let nextEntry = visibleHistory.first {
                reopenHistoryEntry(nextEntry)
            } else {
                clearCurrentEntryDisplay()
            }
        }
        status = "Removed folder and snaps"
    }

    func moveHistoryEntry(_ entry: OCRHistoryEntry, to folderID: HistoryFolder.ID?) {
        guard folderID == nil || historyFolders.contains(where: { $0.id == folderID }) else {
            return
        }
        guard let index = history.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        history[index] = history[index].assigned(to: folderID)
        if selectedHistoryID == entry.id, !isHistoryEntryVisible(history[index]) {
            reconcileSelectedHistoryWithCurrentScope()
        }
        status = "Moved to \(historyFolderName(for: folderID))"
    }

    func moveHistoryEntries(withIDs ids: [OCRHistoryEntry.ID], to folderID: HistoryFolder.ID) {
        guard historyFolders.contains(where: { $0.id == folderID }) else {
            return
        }

        let idSet = Set(ids)
        history = history.map { entry in
            idSet.contains(entry.id) ? entry.assigned(to: folderID) : entry
        }
        if let selectedHistoryID,
           let selectedEntry = history.first(where: { $0.id == selectedHistoryID }),
           !isHistoryEntryVisible(selectedEntry) {
            reconcileSelectedHistoryWithCurrentScope()
        }
        status = "Moved to \(historyFolderName(for: folderID))"
    }

    func historyCount(for scope: HistoryScope) -> Int {
        switch scope {
        case .all:
            return history.count
        case .folder(let folderID):
            return history.filter { $0.folderID == folderID }.count
        }
    }

    func historyFolderName(for folderID: HistoryFolder.ID?) -> String {
        guard let folderID else {
            return "No Folder"
        }
        return historyFolderName(folderID) ?? "Folder"
    }

    func historyFolderColor(for folderID: HistoryFolder.ID?) -> HistoryFolderColor? {
        guard let folderID else {
            return nil
        }
        return historyFolders.first(where: { $0.id == folderID })?.color
    }

    func selectHistory(_ entry: OCRHistoryEntry) {
        reopenHistoryEntry(entry)
    }

    func copyHistoryEntry(_ entry: OCRHistoryEntry) {
        guard !entry.latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.latex, forType: .string)
        status = "Copied from history"
        refreshPasteAvailability()
    }

    func canRevealHistoryImage(_ entry: OCRHistoryEntry) -> Bool {
        imageFileExists(at: historyImageURL(for: entry))
    }

    func revealHistoryImageInFinder(_ entry: OCRHistoryEntry) {
        guard let imageURL = historyImageURL(for: entry),
              imageFileExists(at: imageURL) else {
            status = "Image file unavailable"
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([imageURL])
        status = "Revealed image in Finder"
    }

    func renameHistoryEntry(_ entry: OCRHistoryEntry, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = history.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        history[index] = history[index].renamed(to: trimmed)
        status = "Renamed history item"
    }

    func deleteHistoryEntry(_ entry: OCRHistoryEntry) {
        let deletedSelectedEntry = selectedHistoryID == entry.id
        let removedEntries = history.filter { $0.id == entry.id }
        history.removeAll { $0.id == entry.id }
        removeOwnedImageFiles(for: removedEntries)

        if deletedSelectedEntry {
            if let nextEntry = visibleHistory.first {
                reopenHistoryEntry(nextEntry)
            } else {
                clearCurrentEntryDisplay()
            }
        } else if currentImageFingerprint == entry.imageFingerprint {
            currentImageFingerprint = nil
        }

        status = "Deleted history item"
    }

    func reopenHistoryEntry(_ entry: OCRHistoryEntry) {
        let entry = history.first(where: { $0.id == entry.id }) ?? entry

        selectedHistoryID = entry.id
        capturedImage = entry.image ?? entry.imageURL.flatMap(NSImage.init(contentsOf:))
        lastImageURL = nil
        rawPrediction = entry.rawPrediction
        currentImageFingerprint = entry.imageFingerprint
        currentBodyLatex = LaTeXSource.mathBody(from: entry.latex)
        alternatives = entry.alternatives
        currentResultModel = entry.model
        latexOutput = entry.latex
        validationIssue = LaTeXValidator.firstIssue(in: currentBodyLatex)
        switch entry.state {
        case .recognizing:
            status = "Recognizing"
        case .recognized:
            status = "Reopened history item"
        case .failed:
            status = "Recognition failed"
        }
    }

    func refreshPasteAvailability() {
        canPasteImage = NSImage(pasteboard: .general) != nil
    }

    func clearLogs() {
        logs = ""
    }

    func importDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard !isSnipping else {
            return false
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                let url: URL?
                if let itemURL = item as? URL {
                    url = itemURL
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }

                guard let url else {
                    return
                }

                Task { @MainActor [weak self] in
                    await self?.importImageFile(url)
                }
            }
            return true
        }

        if let provider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            provider.loadObject(ofClass: NSImage.self) { [weak self] object, _ in
                guard let image = object as? NSImage else {
                    return
                }

                Task { @MainActor [weak self] in
                    await self?.importImage(image)
                }
            }
            return true
        }

        return false
    }

    func applyRecognitionPredictions(_ predictions: [String]) {
        guard let firstPrediction = predictions.first else {
            return
        }

        let sanitizedPredictions = predictions.map(LaTeXPredictionSanitizer.sanitize)
        let firstSanitized = LaTeXPredictionSanitizer.sanitize(firstPrediction)
        rawPrediction = firstSanitized
        alternatives = LaTeXAlternativeGenerator.makeAlternatives(predictions: sanitizedPredictions, limit: 3)

        if let preferred = alternatives.first {
            currentBodyLatex = preferred.latex
            latexOutput = settings.outputFormat.apply(to: preferred.latex)
        } else {
            currentBodyLatex = firstSanitized
            latexOutput = settings.outputFormat.apply(to: firstSanitized)
        }
        currentResultModel = settings.modelVariant
        validationIssue = LaTeXValidator.firstIssue(in: currentBodyLatex)
    }

    @discardableResult
    func insertPendingHistoryEntry(
        image: NSImage?,
        imageURL: URL? = nil,
        ownsImageFile: Bool = false,
        imageFingerprint: String,
        mode: RecognitionMode,
        model: UniMERModelVariant,
        folderID: HistoryFolder.ID? = nil
    ) -> OCRHistoryEntry.ID {
        let existingIndex = OCRHistoryPolicy.replacementIndex(
            in: history.map(\.imageFingerprint),
            for: imageFingerprint
        )
        let existingEntry = existingIndex.map { history[$0] }
        let assignedFolderID = folderID ?? activeHistoryFolderID ?? existingEntry?.folderID
        let entry = OCRHistoryEntry(
            id: existingEntry?.id ?? UUID(),
            title: pendingHistoryTitle,
            timestamp: Date(),
            latex: "",
            rawPrediction: "",
            alternatives: [],
            outputFormat: settings.outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: .recognizing,
            folderID: assignedFolderID,
            fixedRenderedPreviewFontSize: existingEntry?.fixedRenderedPreviewFontSize
        )

        var removedEntries: [OCRHistoryEntry] = []
        if let existingIndex {
            removedEntries.append(history.remove(at: existingIndex))
        }
        history.insert(entry, at: 0)
        removeOwnedImageFiles(for: removedEntries)
        trimHistoryToLimit()
        selectedHistoryID = entry.id
        return entry.id
    }

    private func normalizedHistoryScope(_ scope: HistoryScope) -> HistoryScope {
        if case .folder(let folderID) = scope,
           !historyFolders.contains(where: { $0.id == folderID }) {
            return .all
        }
        return scope
    }

    private func reconcileSelectedHistoryWithCurrentScope() {
        if let selectedHistoryID,
           visibleHistory.contains(where: { $0.id == selectedHistoryID }) {
            return
        }

        if let nextEntry = visibleHistory.first {
            reopenHistoryEntry(nextEntry)
        } else {
            clearCurrentEntryDisplay()
        }
    }

    private func isHistoryEntryVisible(_ entry: OCRHistoryEntry) -> Bool {
        switch selectedHistoryScope {
        case .all:
            return true
        case .folder(let folderID):
            return entry.folderID == folderID
        }
    }

    private func setRenderedPreviewFontSize(_ fontSize: Int) {
        let clampedFontSize = RenderedPreviewZoom.clamped(fontSize)
        if let selectedHistoryID,
           let index = history.firstIndex(where: { $0.id == selectedHistoryID }),
           history[index].fixedRenderedPreviewFontSize != nil {
            history[index] = history[index].fixedRenderedPreviewFontSize(to: clampedFontSize)
        } else {
            globalRenderedPreviewFontSize = clampedFontSize
        }
    }

    private func nextHistoryFolderName() -> String {
        let existingNames = Set(historyFolders.map(\.name))
        let baseName = "New Folder"
        guard existingNames.contains(baseName) else {
            return baseName
        }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private func nextHistoryFolderColor() -> HistoryFolderColor {
        let usedColors = Set(historyFolders.map(\.color))
        if let unusedColor = HistoryFolderColor.automaticSequence.first(where: { !usedColors.contains($0) }) {
            return unusedColor
        }

        return HistoryFolderColor.automaticSequence[historyFolders.count % HistoryFolderColor.automaticSequence.count]
    }

    private func historyFolderName(_ folderID: HistoryFolder.ID) -> String? {
        historyFolders.first(where: { $0.id == folderID })?.name
    }

    private func historyFolderSortKey(for folderID: HistoryFolder.ID?) -> String {
        guard let folderID else {
            return "\u{10FFFF}"
        }
        return historyFolderName(folderID) ?? "\u{10FFFF}"
    }

    private func ensureSelectedModelAvailable() -> Bool {
        let state = modelState(for: settings.modelVariant)
        if state.isInstalled {
            return true
        }
        if !state.isDownloading {
            requestModelDownload(settings.modelVariant)
        }
        return false
    }

    private func startModelDownload(_ variant: UniMERModelVariant, selectWhenComplete: Bool) {
        guard variant.requiresManagedFiles,
              !modelState(for: variant).isDownloading else {
            return
        }

        let configuration = workerConfiguration
        setModelDownloadState(.downloading(progress: 0), for: variant)
        status = "Downloading \(variant.title)"

        Task {
            do {
                try await modelDownloader.download(
                    variant: variant,
                    configuration: configuration
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.setModelDownloadState(.downloading(progress: progress), for: variant)
                    }
                }
                refreshModelStatuses()
                setModelDownloadState(nil, for: variant)
                if selectWhenComplete {
                    settings.modelVariant = variant
                }
                status = "\(variant.title) model ready"
            } catch {
                setModelDownloadState(.failed(error.localizedDescription), for: variant)
                status = "Model download failed"
                appendLog(error.localizedDescription)
            }
        }
    }

    private func setModelDownloadState(_ state: ManagedModelState?, for variant: UniMERModelVariant) {
        var states = modelDownloadStates
        states[variant] = state
        modelDownloadStates = states
    }

    private func deleteModel(_ variant: UniMERModelVariant) {
        let fileManager = FileManager.default

        if variant.requiresManagedFiles {
            let modelDirectory = modelDirectoryURL(for: variant)

            for candidate in variant.modelFileCandidates(in: settings.uniMERNetPath) {
                if fileManager.fileExists(atPath: candidate.path) {
                    try? fileManager.removeItem(at: candidate)
                }
            }
            if fileManager.fileExists(atPath: modelDirectory.path) {
                try? fileManager.removeItem(at: modelDirectory)
            }
        } else {
            for candidate in paddleModelCacheCandidates(for: variant) {
                if fileManager.fileExists(atPath: candidate.path) {
                    try? fileManager.removeItem(at: candidate)
                }
            }
        }

        setModelDownloadState(nil, for: variant)
        refreshModelStatuses()
        status = "\(variant.title) model deleted"
    }

    private func captureAndPredict() async {
        isSnipping = true
        status = "Selecting region"
        defer {
            isSnipping = false
        }

        do {
            guard let imageURL = try await screenshotService.captureInteractive() else {
                status = "Capture cancelled"
                return
            }
            isSnipping = false
            let image = NSImage(contentsOf: imageURL)
            let fingerprint = imageFingerprint(from: imageURL) ?? UUID().uuidString
            lastImageURL = imageURL
            capturedImage = image
            currentImageFingerprint = fingerprint
            let entryID = insertPendingHistoryEntry(
                image: image,
                imageURL: imageURL,
                ownsImageFile: true,
                imageFingerprint: fingerprint,
                mode: settings.recognitionMode,
                model: settings.modelVariant
            )
            await predict(imageURL: imageURL, entryID: entryID)
        } catch {
            status = "Capture failed"
            appendLog(error.localizedDescription)
        }
    }

    private func importImageFile(_ url: URL) async {
        guard let image = NSImage(contentsOf: url) else {
            status = "Dropped file is not an image"
            return
        }

        capturedImage = image
        lastImageURL = url
        let fingerprint = imageFingerprint(from: url) ?? UUID().uuidString
        currentImageFingerprint = fingerprint
        let entryID = insertPendingHistoryEntry(
            image: image,
            imageURL: url,
            ownsImageFile: false,
            imageFingerprint: fingerprint,
            mode: settings.recognitionMode,
            model: settings.modelVariant
        )
        await predict(imageURL: url, entryID: entryID)
    }

    private func importImage(_ image: NSImage) async {
        do {
            let imageURL = try image.writeTemporaryPNG(prefix: "snaptex-input")
            capturedImage = image
            lastImageURL = imageURL
            let fingerprint = imageFingerprint(from: imageURL) ?? UUID().uuidString
            currentImageFingerprint = fingerprint
            let entryID = insertPendingHistoryEntry(
                image: image,
                imageURL: imageURL,
                ownsImageFile: true,
                imageFingerprint: fingerprint,
                mode: settings.recognitionMode,
                model: settings.modelVariant
            )
            await predict(imageURL: imageURL, entryID: entryID)
        } catch {
            status = "Image import failed"
            appendLog(error.localizedDescription)
        }
    }

    private func predict(imageURL: URL, entryID: OCRHistoryEntry.ID? = nil) async {
        beginRecognition(entryID: entryID)
        defer { finishRecognition() }

        do {
            let request = UniMERWorkerRequest(
                imagePath: imageURL.path,
                mode: settings.recognitionMode,
                model: settings.modelVariant,
                validateRender: true,
                logVerbosity: settings.logVerbosity
            )
            appendLog(
                "Recognition started: model=\(settings.modelVariant.title), ocr_passes=\(settings.recognitionMode.passCount), image=\(imageURL.lastPathComponent)",
                minimumVerbosity: .verbose
            )
            let result = try await worker.predict(request: request)
            appendLog(
                "Worker result: model=\(result.model.title), ocr_passes=\(result.mode.passCount), alternatives=\(max(1, result.alternatives.count))",
                minimumVerbosity: .verbose
            )
            let outputFormat = entryID.map { outputFormatForHistoryEntry(id: $0) } ?? settings.outputFormat
            let display = makeRecognitionDisplay(
                predictions: result.alternatives.isEmpty ? [result.latex] : result.alternatives,
                outputFormat: outputFormat
            )
            appendLog(
                "Display prepared: validation=\(display.validationIssue == nil ? "ok" : "issue")",
                minimumVerbosity: .debug
            )

            if let entryID {
                completeHistoryEntry(id: entryID, result: result, display: display)
            }

            if entryID == nil || selectedHistoryID == entryID {
                applyRecognitionDisplay(display, model: result.model)
            }

            if settings.autoCopyAfterRecognition {
                copyLatex(display.latexOutput, updateStatus: isCurrentRecognition(entryID))
            } else if isCurrentRecognition(entryID) {
                status = "Recognition complete"
            }
        } catch {
            if let entryID {
                failHistoryEntry(id: entryID, message: error.localizedDescription)
            }
            if isCurrentRecognition(entryID) {
                status = "Recognition failed"
            }
            appendLog(error.localizedDescription)
        }
    }

    private func applyCurrentOutputFormat(_ outputFormat: LaTeXOutputFormat) {
        guard !currentBodyLatex.isEmpty else {
            return
        }
        latexOutput = outputFormat.apply(to: currentBodyLatex)
    }

    private var workerConfiguration: OCRWorkerConfiguration {
        Self.workerConfiguration(for: settings)
    }

    static func workerConfiguration(for settings: AppSettingsSnapshot) -> OCRWorkerConfiguration {
        OCRWorkerConfiguration(
            condaPath: settings.condaPath,
            environmentName: settings.environmentName,
            workerScriptPath: settings.workerScriptPath,
            uniMERNetPath: settings.uniMERNetPath
        )
    }

    private func appendLog(_ message: String, minimumVerbosity: LogVerbosity = .normal) {
        guard settings.logVerbosity.includes(minimumVerbosity) else {
            return
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        logs += "\(trimmed)\n"
    }

    private func beginRecognition(entryID: OCRHistoryEntry.ID?) {
        activeRecognitionCount += 1
        isProcessing = true
        if isCurrentRecognition(entryID) {
            status = "Recognizing"
        }
    }

    private func finishRecognition() {
        activeRecognitionCount = max(0, activeRecognitionCount - 1)
        isProcessing = activeRecognitionCount > 0
    }

    private struct RecognitionDisplay {
        let rawPrediction: String
        let latexOutput: String
        let bodyLatex: String
        let alternatives: [LaTeXAlternative]
        let validationIssue: LaTeXValidationIssue?
    }

    private func makeRecognitionDisplay(
        predictions: [String],
        outputFormat: LaTeXOutputFormat
    ) -> RecognitionDisplay {
        let sanitizedPredictions = predictions.map(LaTeXPredictionSanitizer.sanitize)
        let firstSanitized = sanitizedPredictions.first ?? ""
        let alternatives = LaTeXAlternativeGenerator.makeAlternatives(predictions: sanitizedPredictions, limit: 3)
        let bodyLatex = alternatives.first?.latex ?? firstSanitized
        let latexOutput = outputFormat.apply(to: bodyLatex)
        return RecognitionDisplay(
            rawPrediction: firstSanitized,
            latexOutput: latexOutput,
            bodyLatex: bodyLatex,
            alternatives: alternatives,
            validationIssue: LaTeXValidator.firstIssue(in: bodyLatex)
        )
    }

    private func applyRecognitionDisplay(_ display: RecognitionDisplay, model: UniMERModelVariant) {
        rawPrediction = display.rawPrediction
        alternatives = display.alternatives
        currentBodyLatex = display.bodyLatex
        currentResultModel = model
        latexOutput = display.latexOutput
        validationIssue = display.validationIssue
    }

    private func completeHistoryEntry(
        id: OCRHistoryEntry.ID,
        result: UniMERRecognitionResult,
        display: RecognitionDisplay
    ) {
        guard let index = history.firstIndex(where: { $0.id == id }) else {
            return
        }
        let existing = history[index]
        let title = existing.title == pendingHistoryTitle ? defaultHistoryTitle(for: display.latexOutput) : existing.title
        history[index] = existing.recognized(
            title: title,
            latex: display.latexOutput,
            rawPrediction: display.rawPrediction,
            alternatives: display.alternatives,
            outputFormat: existing.outputFormat,
            model: result.model,
            mode: result.mode
        )
    }

    private func failHistoryEntry(id: OCRHistoryEntry.ID, message: String) {
        guard let index = history.firstIndex(where: { $0.id == id }) else {
            return
        }
        history[index] = history[index].failed(message: message)
    }

    private struct RetryInput {
        let imageURL: URL
        let image: NSImage?
        let ownsImageFile: Bool
        let imageFingerprint: String
    }

    private func makeRetryInput() throws -> RetryInput? {
        if let selectedHistoryID,
           let entry = history.first(where: { $0.id == selectedHistoryID }) {
            if imageFileExists(at: entry.imageURL), let imageURL = entry.imageURL {
                let image = entry.image ?? NSImage(contentsOf: imageURL)
                capturedImage = image
                lastImageURL = imageURL
                currentImageFingerprint = entry.imageFingerprint
                return RetryInput(
                    imageURL: imageURL,
                    image: image,
                    ownsImageFile: entry.ownsImageFile,
                    imageFingerprint: entry.imageFingerprint
                )
            }

            guard let image = entry.image else {
                return nil
            }

            let imageURL = try image.writeTemporaryPNG(prefix: "snaptex-retry")
            capturedImage = image
            lastImageURL = imageURL
            currentImageFingerprint = entry.imageFingerprint
            return RetryInput(imageURL: imageURL, image: image, ownsImageFile: true, imageFingerprint: entry.imageFingerprint)
        }

        guard let lastImageURL else {
            return nil
        }

        let fingerprint = currentImageFingerprint ?? imageFingerprint(from: lastImageURL) ?? UUID().uuidString
        let ownsImageFile = lastImageURL.lastPathComponent.hasPrefix("snaptex-")
        return RetryInput(imageURL: lastImageURL, image: capturedImage, ownsImageFile: ownsImageFile, imageFingerprint: fingerprint)
    }

    private func clearCurrentEntryDisplay() {
        selectedHistoryID = nil
        capturedImage = nil
        lastImageURL = nil
        currentImageFingerprint = nil
        rawPrediction = ""
        alternatives = []
        validationIssue = nil
        latexOutput = ""
        currentBodyLatex = ""
        currentResultModel = nil
        previewUpdateTask?.cancel()
        previewLatex = ""
        previewIssue = nil
    }

    private func copyLatex(_ latex: String, updateStatus: Bool = true) {
        guard !latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latex, forType: .string)
        if updateStatus {
            status = "Copied"
        }
    }

    private func trimHistoryToLimit() {
        guard settings.isHistoryLimitEnabled else {
            return
        }

        let limit = max(4, settings.historyLimit)
        if history.count > limit {
            let removedEntries = Array(history.suffix(history.count - limit))
            let removedSelectedEntry = selectedHistoryID.map { selectedID in
                removedEntries.contains { $0.id == selectedID }
            } ?? false
            history.removeLast(history.count - limit)
            removeOwnedImageFiles(for: removedEntries)
            if removedSelectedEntry {
                if let nextEntry = visibleHistory.first {
                    reopenHistoryEntry(nextEntry)
                } else {
                    clearCurrentEntryDisplay()
                }
            }
        }
    }

    private func updateEditorMetadata() {
        let body = LaTeXSource.mathBody(from: latexOutput)
        currentBodyLatex = body
    }

    private func syncSelectedHistoryOutput() {
        guard let selectedHistoryID,
              let index = history.firstIndex(where: { $0.id == selectedHistoryID }),
              history[index].state != .recognizing else {
            return
        }

        let entry = history[index]
        guard entry.latex != latexOutput ||
              entry.rawPrediction != rawPrediction ||
              entry.alternatives != alternatives else {
            return
        }

        history[index] = entry.updatedOutput(
            latex: latexOutput,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: entry.outputFormat
        )
    }

    private func schedulePreviewUpdate() {
        let source = latexOutput
        previewUpdateTask?.cancel()
        previewUpdateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }

            let body = LaTeXSource.mathBody(from: source)
            let issue = body.isEmpty ? nil : LaTeXValidator.firstIssue(in: body)

            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }

                if body.isEmpty {
                    self?.previewLatex = ""
                    self?.previewIssue = nil
                } else if let issue {
                    self?.previewLatex = ""
                    self?.previewIssue = issue
                } else {
                    self?.previewLatex = body
                    self?.previewIssue = nil
                }
            }
        }
    }

    private func imageFingerprint(from imageURL: URL) -> String? {
        guard let data = try? Data(contentsOf: imageURL) else {
            return nil
        }
        return OCRImageFingerprint.make(from: data)
    }

    private func historyImageURL(for entry: OCRHistoryEntry) -> URL? {
        history.first(where: { $0.id == entry.id })?.imageURL ?? entry.imageURL
    }

    private func outputFormatForHistoryEntry(id: OCRHistoryEntry.ID) -> LaTeXOutputFormat {
        history.first(where: { $0.id == id })?.outputFormat ?? settings.outputFormat
    }

    private func isCurrentRecognition(_ entryID: OCRHistoryEntry.ID?) -> Bool {
        entryID == nil || selectedHistoryID == entryID
    }

    private func modelDirectoryURL(for variant: UniMERModelVariant) -> URL {
        URL(fileURLWithPath: (settings.uniMERNetPath as NSString).expandingTildeInPath)
            .appendingPathComponent("models")
            .appendingPathComponent(variant.directoryName)
    }

    private func paddleModelCacheCandidates(for variant: UniMERModelVariant) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let modelName = variant.workerModelName
        return [
            home.appendingPathComponent(".paddlex/official_models").appendingPathComponent(modelName),
            home.appendingPathComponent(".paddleocr/whl/formula").appendingPathComponent(modelName),
            home.appendingPathComponent(".cache/paddleocr").appendingPathComponent(modelName)
        ]
    }

    private func modelRevealURL(for variant: UniMERModelVariant) -> URL? {
        let fileManager = FileManager.default
        let modelDirectory = modelDirectoryURL(for: variant)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: modelDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return modelDirectory
        }

        return variant.modelFileCandidates(in: settings.uniMERNetPath).first {
            fileManager.fileExists(atPath: $0.path)
        }
    }

    private func imageFileExists(at url: URL?) -> Bool {
        guard let url else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func removeOwnedImageFiles(for entries: [OCRHistoryEntry]) {
        let preservedURLs = Set(history.compactMap(\.imageURL))
        for entry in entries where entry.ownsImageFile {
            guard let imageURL = entry.imageURL,
                  !preservedURLs.contains(imageURL) else {
                continue
            }
            try? FileManager.default.removeItem(at: imageURL)
        }
    }
}

private func defaultHistoryTitle(for latex: String) -> String {
    let body = LaTeXSource.mathBody(from: latex)
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else {
        return "Untitled formula"
    }
    return String(body.prefix(42))
}
