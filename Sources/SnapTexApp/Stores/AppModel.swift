import AppKit
import Foundation
import SnapTexCore
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettingsSnapshot {
        didSet {
            settingsStore.save(settings)
            worker.updateConfiguration(workerConfiguration)
            if oldValue.uniMERNetPath != settings.uniMERNetPath {
                refreshModelStatuses()
            }
            applyCurrentOutputFormat()
        }
    }
    @Published var capturedImage: NSImage?
    @Published var rawPrediction = ""
    @Published var latexOutput = "" {
        didSet {
            updateEditorMetadata()
            schedulePreviewUpdate()
        }
    }
    @Published var alternatives: [LaTeXAlternative] = []
    @Published var previewLatex = ""
    @Published var previewIssue: LaTeXValidationIssue?
    @Published var history: [OCRHistoryEntry] = []
    @Published var selectedHistoryID: OCRHistoryEntry.ID?
    @Published var status = "Ready"
    @Published var logs = ""
    @Published var isProcessing = false
    @Published var isSnipping = false
    @Published var canPasteImage = false
    @Published var validationIssue: LaTeXValidationIssue?
    @Published private(set) var installedModels: Set<UniMERModelVariant> = []
    @Published private(set) var modelDownloadStates: [UniMERModelVariant: ManagedModelState] = [:]
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
        guard !isProcessing, !isSnipping else {
            return false
        }

        if let selectedHistoryID {
            return history.first(where: { $0.id == selectedHistoryID })?.image != nil
        }

        return lastImageURL != nil
    }

    var canStartSnip: Bool {
        !isSnipping
    }

    var canCopy: Bool {
        !latexOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        guard !modelState(for: variant).isDownloading else {
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
        guard modelState(for: variant).isInstalled else {
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

    func applyAlternative(_ latex: String) {
        applyAlternative(LaTeXAlternative(title: "Alternative", latex: latex, rank: 0))
    }

    func applyAlternative(_ alternative: LaTeXAlternative) {
        currentBodyLatex = alternative.latex
        rawPrediction = alternative.latex
        latexOutput = settings.outputFormat.apply(to: alternative.latex)
        validationIssue = LaTeXValidator.firstIssue(in: alternative.latex)
        status = "Alternative applied"
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
        history.removeAll { $0.id == entry.id }

        if deletedSelectedEntry {
            if let nextEntry = history.first {
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
        selectedHistoryID = entry.id
        capturedImage = entry.image
        lastImageURL = nil
        rawPrediction = entry.rawPrediction
        currentImageFingerprint = entry.imageFingerprint
        currentBodyLatex = LaTeXSource.mathBody(from: entry.latex)
        alternatives = entry.alternatives
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
        validationIssue = LaTeXValidator.firstIssue(in: currentBodyLatex)
    }

    @discardableResult
    func insertPendingHistoryEntry(
        image: NSImage?,
        imageFingerprint: String,
        mode: RecognitionMode,
        model: UniMERModelVariant
    ) -> OCRHistoryEntry.ID {
        let existingIndex = OCRHistoryPolicy.replacementIndex(
            in: history.map(\.imageFingerprint),
            for: imageFingerprint
        )
        let existingEntry = existingIndex.map { history[$0] }
        let entry = OCRHistoryEntry(
            id: existingEntry?.id ?? UUID(),
            title: pendingHistoryTitle,
            timestamp: Date(),
            latex: "",
            rawPrediction: "",
            alternatives: [],
            model: model,
            mode: mode,
            image: image,
            imageFingerprint: imageFingerprint,
            state: .recognizing
        )

        if let existingIndex {
            history.remove(at: existingIndex)
        }
        history.insert(entry, at: 0)
        trimHistoryToLimit()
        selectedHistoryID = entry.id
        return entry.id
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
        guard !modelState(for: variant).isDownloading else {
            return
        }

        let configuration = workerConfiguration
        setModelDownloadState(.downloading(progress: 0), for: variant)
        status = "Downloading \(variant.title) model"

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
        let modelDirectory = URL(fileURLWithPath: (settings.uniMERNetPath as NSString).expandingTildeInPath)
            .appendingPathComponent("models")
            .appendingPathComponent(variant.directoryName)

        for candidate in variant.modelFileCandidates(in: settings.uniMERNetPath) {
            if fileManager.fileExists(atPath: candidate.path) {
                try? fileManager.removeItem(at: candidate)
            }
        }
        if fileManager.fileExists(atPath: modelDirectory.path) {
            try? fileManager.removeItem(at: modelDirectory)
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
        beginRecognition()
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
            let display = makeRecognitionDisplay(predictions: result.alternatives.isEmpty ? [result.latex] : result.alternatives)
            appendLog(
                "Display prepared: validation=\(display.validationIssue == nil ? "ok" : "issue")",
                minimumVerbosity: .debug
            )

            if let entryID {
                completeHistoryEntry(id: entryID, result: result, display: display)
            }

            if entryID == nil || selectedHistoryID == entryID {
                applyRecognitionDisplay(display)
            }

            if settings.autoCopyAfterRecognition {
                copyLatex(display.latexOutput)
            } else {
                status = "Recognition complete"
            }
        } catch {
            if let entryID {
                failHistoryEntry(id: entryID, message: error.localizedDescription)
            }
            status = "Recognition failed"
            appendLog(error.localizedDescription)
        }
    }

    private func applyCurrentOutputFormat() {
        guard !currentBodyLatex.isEmpty else {
            return
        }
        latexOutput = settings.outputFormat.apply(to: currentBodyLatex)
    }

    private var workerConfiguration: OCRWorkerConfiguration {
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

    private func beginRecognition() {
        activeRecognitionCount += 1
        isProcessing = true
        status = activeRecognitionCount == 1 ? "Recognizing" : "Recognizing \(activeRecognitionCount) items"
    }

    private func finishRecognition() {
        activeRecognitionCount = max(0, activeRecognitionCount - 1)
        isProcessing = activeRecognitionCount > 0
        if activeRecognitionCount > 0 {
            status = activeRecognitionCount == 1 ? "Recognizing" : "Recognizing \(activeRecognitionCount) items"
        }
    }

    private struct RecognitionDisplay {
        let rawPrediction: String
        let latexOutput: String
        let bodyLatex: String
        let alternatives: [LaTeXAlternative]
        let validationIssue: LaTeXValidationIssue?
    }

    private func makeRecognitionDisplay(predictions: [String]) -> RecognitionDisplay {
        let sanitizedPredictions = predictions.map(LaTeXPredictionSanitizer.sanitize)
        let firstSanitized = sanitizedPredictions.first ?? ""
        let alternatives = LaTeXAlternativeGenerator.makeAlternatives(predictions: sanitizedPredictions, limit: 3)
        let bodyLatex = alternatives.first?.latex ?? firstSanitized
        let latexOutput = settings.outputFormat.apply(to: bodyLatex)
        return RecognitionDisplay(
            rawPrediction: firstSanitized,
            latexOutput: latexOutput,
            bodyLatex: bodyLatex,
            alternatives: alternatives,
            validationIssue: LaTeXValidator.firstIssue(in: bodyLatex)
        )
    }

    private func applyRecognitionDisplay(_ display: RecognitionDisplay) {
        rawPrediction = display.rawPrediction
        alternatives = display.alternatives
        currentBodyLatex = display.bodyLatex
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
        let imageFingerprint: String
    }

    private func makeRetryInput() throws -> RetryInput? {
        if let selectedHistoryID,
           let entry = history.first(where: { $0.id == selectedHistoryID }),
           let image = entry.image {
            let imageURL = try image.writeTemporaryPNG(prefix: "snaptex-retry")
            capturedImage = image
            lastImageURL = imageURL
            currentImageFingerprint = entry.imageFingerprint
            return RetryInput(imageURL: imageURL, image: image, imageFingerprint: entry.imageFingerprint)
        }

        guard let lastImageURL else {
            return nil
        }

        let fingerprint = currentImageFingerprint ?? imageFingerprint(from: lastImageURL) ?? UUID().uuidString
        return RetryInput(imageURL: lastImageURL, image: capturedImage, imageFingerprint: fingerprint)
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
        previewUpdateTask?.cancel()
        previewLatex = ""
        previewIssue = nil
    }

    private func copyLatex(_ latex: String) {
        guard !latex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latex, forType: .string)
        status = "Copied"
    }

    private func trimHistoryToLimit() {
        let limit = max(4, settings.historyLimit)
        if history.count > limit {
            history.removeLast(history.count - limit)
        }
    }

    private func updateEditorMetadata() {
        let body = LaTeXSource.mathBody(from: latexOutput)
        currentBodyLatex = body
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
