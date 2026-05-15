import Foundation

enum RenderedPreviewZoom {
    static let minimumFontSize = 8
    static let maximumFontSize = 48
    static let defaultFontSize = 18
    static let step = 2

    static func zoomIn(from fontSize: Int) -> Int {
        min(maximumFontSize, fontSize + step)
    }

    static func zoomOut(from fontSize: Int) -> Int {
        max(minimumFontSize, fontSize - step)
    }

    static func percent(for fontSize: Int) -> Int {
        Int((Double(fontSize) / Double(defaultFontSize) * 100).rounded())
    }
}
