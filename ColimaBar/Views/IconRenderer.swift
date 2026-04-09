import AppKit
import SwiftUI

enum IconState: Hashable {
    case allStopped
    case anyRunning
    case transitioning
    case error
}

enum IconRenderer {

    static let menuBarSize = NSSize(width: 18, height: 18)

    static func menuBarIcon(state: IconState, runningCount: Int = 0) -> NSImage {
        let image = NSImage(size: menuBarSize, flipped: false) { rect in
            switch state {
            case .allStopped:
                drawGlyph(in: rect, color: .black, style: .outline)
            case .anyRunning:
                drawGlyph(in: rect, color: .black, style: .filledContainer)
                if runningCount > 1 {
                    drawBadge(in: rect, count: runningCount, color: .black)
                }
            case .transitioning:
                drawGlyph(in: rect, color: .black, style: .outline)
            case .error:
                drawGlyph(in: rect, color: .black, style: .outline)
                drawErrorOverlay(in: rect, color: .black)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func menuBarIcon(runningCount: Int = 0) -> NSImage {
        menuBarIcon(state: runningCount > 0 ? .anyRunning : .allStopped, runningCount: runningCount)
    }

    static func colorIcon(size: CGFloat = 64) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawGlyph(in: rect, color: nil, style: .colorFilled)
            return true
        }
    }

    private enum GlyphStyle {
        case outline            // hollow volcano + hollow container
        case filledContainer    // hollow volcano, solid-filled container — reads as "active"
        case colorFilled        // full color gradient (popover only)
    }

    private static func drawGlyph(
        in rect: NSRect,
        color templateColor: NSColor?,
        style: GlyphStyle
    ) {
        let w = rect.width
        let inset: CGFloat = w * 0.06
        let bounds = rect.insetBy(dx: inset, dy: inset)

        let volcano = NSBezierPath()
        let peakX = bounds.midX
        let peakY = bounds.maxY - bounds.height * 0.05
        let baseLeftX = bounds.minX
        let baseRightX = bounds.maxX
        let baseY = bounds.minY + bounds.height * 0.08

        let craterHalfWidth = bounds.width * 0.08
        volcano.move(to: NSPoint(x: baseLeftX, y: baseY))
        volcano.line(to: NSPoint(x: peakX - craterHalfWidth, y: peakY))
        volcano.line(to: NSPoint(x: peakX - craterHalfWidth * 0.4, y: peakY - bounds.height * 0.06))
        volcano.line(to: NSPoint(x: peakX + craterHalfWidth * 0.4, y: peakY - bounds.height * 0.06))
        volcano.line(to: NSPoint(x: peakX + craterHalfWidth, y: peakY))
        volcano.line(to: NSPoint(x: baseRightX, y: baseY))
        volcano.line(to: NSPoint(x: baseLeftX, y: baseY))
        volcano.close()
        volcano.lineWidth = max(1, w * 0.08)
        volcano.lineJoinStyle = .round

        let boxWidth = bounds.width * 0.42
        let boxHeight = bounds.height * 0.22
        let box = NSRect(
            x: bounds.midX - boxWidth / 2,
            y: baseY + bounds.height * 0.12,
            width: boxWidth,
            height: boxHeight
        )
        let boxPath = NSBezierPath(roundedRect: box, xRadius: boxHeight * 0.25, yRadius: boxHeight * 0.25)

        switch style {
        case .colorFilled:
            NSGraphicsContext.saveGraphicsState()
            let gradient = NSGradient(colors: [
                NSColor(srgbRed: 1.00, green: 0.42, blue: 0.24, alpha: 1),
                NSColor(srgbRed: 0.96, green: 0.72, blue: 0.25, alpha: 1)
            ])
            gradient?.draw(in: volcano, angle: 90)
            NSColor(srgbRed: 0.13, green: 0.17, blue: 0.22, alpha: 1).setFill()
            boxPath.fill()
            NSColor.white.withAlphaComponent(0.9).setStroke()
            boxPath.lineWidth = max(1, w * 0.03)
            boxPath.stroke()

            let divider = NSBezierPath()
            divider.move(to: NSPoint(x: box.minX + box.width * 0.1, y: box.midY))
            divider.line(to: NSPoint(x: box.maxX - box.width * 0.1, y: box.midY))
            divider.lineWidth = max(1, w * 0.03)
            NSColor.white.withAlphaComponent(0.5).setStroke()
            divider.stroke()
            NSGraphicsContext.restoreGraphicsState()

        case .outline, .filledContainer:
            let color = templateColor ?? .black
            color.setStroke()
            color.setFill()

            volcano.stroke()

            NSGraphicsContext.saveGraphicsState()
            if style == .filledContainer {
                color.setFill()
                boxPath.fill()
                // Slat carved out in white to stay readable when tinted.
                let divider = NSBezierPath()
                divider.move(to: NSPoint(x: box.minX + box.width * 0.18, y: box.midY))
                divider.line(to: NSPoint(x: box.maxX - box.width * 0.18, y: box.midY))
                divider.lineWidth = max(1, w * 0.06)
                NSColor.clear.setStroke()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                divider.stroke()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            } else {
                NSColor.clear.setFill()
                boxPath.fill()
                color.setStroke()
                boxPath.lineWidth = max(1, w * 0.08)
                boxPath.stroke()

                let divider = NSBezierPath()
                divider.move(to: NSPoint(x: box.minX + box.width * 0.15, y: box.midY))
                divider.line(to: NSPoint(x: box.maxX - box.width * 0.15, y: box.midY))
                divider.lineWidth = max(1, w * 0.06)
                divider.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private static func drawBadge(in rect: NSRect, count: Int, color: NSColor) {
        let size = rect.width * 0.42
        let badgeRect = NSRect(
            x: rect.maxX - size - rect.width * 0.02,
            y: rect.maxY - size - rect.width * 0.02,
            width: size,
            height: size
        )
        let circle = NSBezierPath(ovalIn: badgeRect)
        color.setFill()
        circle.fill()

        let text = count > 9 ? "9+" : "\(count)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.62, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let string = NSAttributedString(string: text, attributes: attrs)
        let textSize = string.size()
        let origin = NSPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        )
        string.draw(at: origin)
    }

    private static func drawErrorOverlay(in rect: NSRect, color: NSColor) {
        let size = rect.width * 0.46
        let overlayRect = NSRect(
            x: rect.maxX - size - rect.width * 0.02,
            y: rect.maxY - size - rect.width * 0.02,
            width: size,
            height: size
        )
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: overlayRect.midX, y: overlayRect.maxY))
        triangle.line(to: NSPoint(x: overlayRect.maxX, y: overlayRect.minY))
        triangle.line(to: NSPoint(x: overlayRect.minX, y: overlayRect.minY))
        triangle.close()
        color.setFill()
        triangle.fill()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let barWidth = overlayRect.width * 0.12
        let bar = NSRect(
            x: overlayRect.midX - barWidth / 2,
            y: overlayRect.minY + overlayRect.height * 0.30,
            width: barWidth,
            height: overlayRect.height * 0.35
        )
        NSBezierPath(rect: bar).fill()
        let dot = NSRect(
            x: overlayRect.midX - barWidth / 2,
            y: overlayRect.minY + overlayRect.height * 0.17,
            width: barWidth,
            height: barWidth
        )
        NSBezierPath(ovalIn: dot).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSGraphicsContext.restoreGraphicsState()
    }
}

extension Image {
    static func colimaBarColorIcon(size: CGFloat = 64) -> Image {
        Image(nsImage: IconRenderer.colorIcon(size: size))
    }
}
