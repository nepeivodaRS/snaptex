import AppKit
import Foundation

extension NSImage {
    func writeTemporaryPNG(prefix: String) throws -> URL {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try data.write(to: url)
        return url
    }
}
