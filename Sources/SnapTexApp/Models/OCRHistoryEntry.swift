import AppKit
import Foundation
import SnapTexCore

enum OCRHistoryEntryState: Equatable {
    case recognizing
    case recognized
    case failed(String)
}

struct OCRHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let timestamp: Date
    let latex: String
    let rawPrediction: String
    let alternatives: [LaTeXAlternative]
    let outputFormat: LaTeXOutputFormat
    let model: UniMERModelVariant
    let mode: RecognitionMode
    let image: NSImage?
    let imageURL: URL?
    let ownsImageFile: Bool
    let imageFingerprint: String
    let state: OCRHistoryEntryState
    let folderID: HistoryFolder.ID?
    let fixedRenderedPreviewFontSize: Int?

    init(
        id: UUID,
        title: String,
        timestamp: Date,
        latex: String,
        rawPrediction: String,
        alternatives: [LaTeXAlternative],
        outputFormat: LaTeXOutputFormat = .raw,
        model: UniMERModelVariant,
        mode: RecognitionMode,
        image: NSImage?,
        imageURL: URL? = nil,
        ownsImageFile: Bool = false,
        imageFingerprint: String,
        state: OCRHistoryEntryState,
        folderID: HistoryFolder.ID? = nil,
        fixedRenderedPreviewFontSize: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.latex = latex
        self.rawPrediction = rawPrediction
        self.alternatives = alternatives
        self.outputFormat = outputFormat
        self.model = model
        self.mode = mode
        self.image = image
        self.imageURL = imageURL
        self.ownsImageFile = ownsImageFile
        self.imageFingerprint = imageFingerprint
        self.state = state
        self.folderID = folderID
        self.fixedRenderedPreviewFontSize = fixedRenderedPreviewFontSize
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }

    var displayImage: NSImage? {
        image ?? imageURL.flatMap(NSImage.init(contentsOf:))
    }

    func renamed(to title: String) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: state,
            folderID: folderID,
            fixedRenderedPreviewFontSize: fixedRenderedPreviewFontSize
        )
    }

    func assigned(to folderID: HistoryFolder.ID?) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: state,
            folderID: folderID,
            fixedRenderedPreviewFontSize: fixedRenderedPreviewFontSize
        )
    }

    func fixedRenderedPreviewFontSize(to fontSize: Int?) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: state,
            folderID: folderID,
            fixedRenderedPreviewFontSize: fontSize
        )
    }

    func recognized(
        title: String,
        latex: String,
        rawPrediction: String,
        alternatives: [LaTeXAlternative],
        outputFormat: LaTeXOutputFormat,
        model: UniMERModelVariant,
        mode: RecognitionMode
    ) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: .recognized,
            folderID: folderID,
            fixedRenderedPreviewFontSize: fixedRenderedPreviewFontSize
        )
    }

    func updatedOutput(
        latex: String,
        rawPrediction: String,
        alternatives: [LaTeXAlternative],
        outputFormat: LaTeXOutputFormat
    ) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: state,
            folderID: folderID,
            fixedRenderedPreviewFontSize: fixedRenderedPreviewFontSize
        )
    }

    func failed(message: String) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: "Recognition failed",
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            outputFormat: outputFormat,
            model: model,
            mode: mode,
            image: image,
            imageURL: imageURL,
            ownsImageFile: ownsImageFile,
            imageFingerprint: imageFingerprint,
            state: .failed(message),
            folderID: folderID,
            fixedRenderedPreviewFontSize: fixedRenderedPreviewFontSize
        )
    }
}
