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
    let model: UniMERModelVariant
    let mode: RecognitionMode
    let image: NSImage?
    let imageFingerprint: String
    let state: OCRHistoryEntryState

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }

    func renamed(to title: String) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: id,
            title: title,
            timestamp: timestamp,
            latex: latex,
            rawPrediction: rawPrediction,
            alternatives: alternatives,
            model: model,
            mode: mode,
            image: image,
            imageFingerprint: imageFingerprint,
            state: state
        )
    }

    func recognized(
        title: String,
        latex: String,
        rawPrediction: String,
        alternatives: [LaTeXAlternative],
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
            model: model,
            mode: mode,
            image: image,
            imageFingerprint: imageFingerprint,
            state: .recognized
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
            model: model,
            mode: mode,
            image: image,
            imageFingerprint: imageFingerprint,
            state: .failed(message)
        )
    }
}
