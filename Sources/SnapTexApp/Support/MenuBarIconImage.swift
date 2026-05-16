import AppKit

enum MenuBarIconImage {
    static func make() -> NSImage {
        let size = NSSize(width: 26, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.black.setStroke()

        let inset: CGFloat = 2
        let cornerLength: CGFloat = 4.5
        let minX = inset
        let maxX = size.width - inset
        let minY = inset
        let maxY = size.height - inset

        let corners = NSBezierPath()
        corners.lineWidth = 1.5
        corners.lineCapStyle = .round
        corners.lineJoinStyle = .round

        corners.move(to: NSPoint(x: minX + cornerLength, y: maxY))
        corners.line(to: NSPoint(x: minX, y: maxY))
        corners.line(to: NSPoint(x: minX, y: maxY - cornerLength))

        corners.move(to: NSPoint(x: maxX - cornerLength, y: maxY))
        corners.line(to: NSPoint(x: maxX, y: maxY))
        corners.line(to: NSPoint(x: maxX, y: maxY - cornerLength))

        corners.move(to: NSPoint(x: minX, y: minY + cornerLength))
        corners.line(to: NSPoint(x: minX, y: minY))
        corners.line(to: NSPoint(x: minX + cornerLength, y: minY))

        corners.move(to: NSPoint(x: maxX, y: minY + cornerLength))
        corners.line(to: NSPoint(x: maxX, y: minY))
        corners.line(to: NSPoint(x: maxX - cornerLength, y: minY))

        corners.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let text = NSAttributedString(string: "f(x)", attributes: attributes)
        let textSize = text.size()
        let textOrigin = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )

        text.draw(at: textOrigin)

        return image
    }
}
