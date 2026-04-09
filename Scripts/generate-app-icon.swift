#!/usr/bin/env swift
// Generates app icon PNGs at all required sizes from the volcano+container glyph.
// Run: swift Scripts/generate-app-icon.swift

import AppKit

let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

let outputDir = "ColimaBar/Assets.xcassets/AppIcon.appiconset"

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let w = rect.width
        let cornerRadius = w * 0.22

        // Background: warm gradient
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        let bgGradient = NSGradient(colors: [
            NSColor(srgbRed: 0.18, green: 0.20, blue: 0.26, alpha: 1),
            NSColor(srgbRed: 0.12, green: 0.14, blue: 0.18, alpha: 1),
        ])
        bgGradient?.draw(in: bgPath, angle: -90)

        // Volcano + container in the center
        let inset = w * 0.18
        let bounds = rect.insetBy(dx: inset, dy: inset)

        let peakX = bounds.midX
        let peakY = bounds.maxY - bounds.height * 0.05
        let baseLeftX = bounds.minX
        let baseRightX = bounds.maxX
        let baseY = bounds.minY + bounds.height * 0.08
        let craterHalfWidth = bounds.width * 0.08

        let volcano = NSBezierPath()
        volcano.move(to: NSPoint(x: baseLeftX, y: baseY))
        volcano.line(to: NSPoint(x: peakX - craterHalfWidth, y: peakY))
        volcano.line(to: NSPoint(x: peakX - craterHalfWidth * 0.4, y: peakY - bounds.height * 0.06))
        volcano.line(to: NSPoint(x: peakX + craterHalfWidth * 0.4, y: peakY - bounds.height * 0.06))
        volcano.line(to: NSPoint(x: peakX + craterHalfWidth, y: peakY))
        volcano.line(to: NSPoint(x: baseRightX, y: baseY))
        volcano.close()

        let volcanoGradient = NSGradient(colors: [
            NSColor(srgbRed: 1.00, green: 0.42, blue: 0.24, alpha: 1),
            NSColor(srgbRed: 0.96, green: 0.72, blue: 0.25, alpha: 1),
        ])
        volcanoGradient?.draw(in: volcano, angle: 90)

        // Container box
        let boxWidth = bounds.width * 0.42
        let boxHeight = bounds.height * 0.22
        let box = NSRect(
            x: bounds.midX - boxWidth / 2,
            y: baseY + bounds.height * 0.12,
            width: boxWidth,
            height: boxHeight
        )
        let boxPath = NSBezierPath(roundedRect: box, xRadius: boxHeight * 0.25, yRadius: boxHeight * 0.25)
        NSColor(srgbRed: 0.13, green: 0.17, blue: 0.22, alpha: 1).setFill()
        boxPath.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        boxPath.lineWidth = max(1, w * 0.015)
        boxPath.stroke()

        // Container slat
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: box.minX + box.width * 0.1, y: box.midY))
        divider.line(to: NSPoint(x: box.maxX - box.width * 0.1, y: box.midY))
        divider.lineWidth = max(1, w * 0.015)
        NSColor.white.withAlphaComponent(0.5).setStroke()
        divider.stroke()

        return true
    }
    return image
}

func savePNG(_ image: NSImage, pixelWidth: Int, pixelHeight: Int, to path: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = image.size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// Generate
let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

var contentsImages: [[String: Any]] = []

for (size, scale) in sizes {
    let pixelSize = size * scale
    let filename = "icon_\(size)x\(size)@\(scale)x.png"
    let path = "\(outputDir)/\(filename)"

    let icon = drawIcon(size: CGFloat(size))
    savePNG(icon, pixelWidth: pixelSize, pixelHeight: pixelSize, to: path)
    print("Generated \(filename) (\(pixelSize)x\(pixelSize)px)")

    contentsImages.append([
        "filename": filename,
        "idiom": "mac",
        "scale": "\(scale)x",
        "size": "\(size)x\(size)"
    ])
}

// Write Contents.json
let contents: [String: Any] = [
    "images": contentsImages,
    "info": ["author": "dreuse", "version": 1]
]
let jsonData = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! jsonData.write(to: URL(fileURLWithPath: "\(outputDir)/Contents.json"))
print("Updated Contents.json")
