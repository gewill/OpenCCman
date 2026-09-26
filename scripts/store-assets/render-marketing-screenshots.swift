import AppKit
import Foundation

// Deterministic marketing layout around real, unchanged application captures.
// Usage: swift render-marketing-screenshots.swift <source-directory> <output-directory>
guard CommandLine.arguments.count == 3 else {
    fatalError("Expected source and output directories")
}

let sourceRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputRoot = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let copyURL = sourceRoot.appendingPathComponent("marketing-copy.json")
let data = try Data(contentsOf: copyURL)
let copy = try JSONDecoder().decode([String: [String: [String]]].self, from: data)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

func drawText(_ value: String, in rect: NSRect, preferredSize: CGFloat, weight: NSFont.Weight, ink: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    var size = preferredSize
    var attributes: [NSAttributedString.Key: Any] = [:]
    while size >= preferredSize * 0.76 {
        attributes = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: ink,
            .paragraphStyle: paragraph
        ]
        let bounds = (value as NSString).boundingRect(
            with: NSSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        if bounds.height <= rect.height { break }
        size -= 2
    }
    (value as NSString).draw(in: rect, withAttributes: attributes)
}

for locale in copy.keys.sorted() {
    guard let slides = copy[locale] else { continue }
    for key in slides.keys.sorted() {
        guard let lines = slides[key], lines.count == 2 else { fatalError("Invalid copy for \(locale)/\(key)") }
        let sourceName = key == "mac/01-workspace" && locale == "en-US"
            ? "01-workspace-clean.png" : "\(key.components(separatedBy: "/")[1]).png"
        let sourceURL = sourceRoot.appendingPathComponent("\(key.components(separatedBy: "/")[0])/\(locale)/\(sourceName)")
        guard let source = NSImage(contentsOf: sourceURL) else { fatalError("Missing \(sourceURL.path)") }
        guard let sourceRep = NSBitmapImageRep(data: try Data(contentsOf: sourceURL)) else { fatalError("Invalid source PNG") }
        let isMac = key.hasPrefix("mac/")
        let width = isMac ? 2560 : sourceRep.pixelsWide
        let height = isMac ? 1600 : sourceRep.pixelsHigh
        let w = CGFloat(width)
        let h = CGFloat(height)
        guard let result = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: result) else { fatalError("Cannot create bitmap") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        let canvas = NSRect(x: 0, y: 0, width: w, height: h)
        NSGradient(starting: color(245, 249, 252), ending: color(218, 232, 244))!
            .draw(in: canvas, angle: 270)

        let header = h * (isMac ? 0.16 : 0.18)
        let margin = min(w, h) * 0.045
        let maxImageWidth = w - margin * 2
        let maxImageHeight = h - header - margin * 1.7
        let sourceWidth = CGFloat(sourceRep.pixelsWide)
        let sourceHeight = CGFloat(sourceRep.pixelsHigh)
        let scale = min(maxImageWidth / sourceWidth, maxImageHeight / sourceHeight)
        let imageRect = NSRect(
            x: (w - sourceWidth * scale) / 2, y: margin * 0.7,
            width: sourceWidth * scale, height: sourceHeight * scale
        )
        let corner = min(w, h) * 0.025
        let clip = NSBezierPath(roundedRect: imageRect, xRadius: corner, yRadius: corner)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = color(36, 77, 119).withAlphaComponent(0.22)
        shadow.shadowOffset = NSSize(width: 0, height: -min(w, h) * 0.014)
        shadow.shadowBlurRadius = min(w, h) * 0.028
        shadow.set()
        NSColor.white.setFill()
        clip.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        source.draw(in: imageRect, from: NSRect(origin: .zero, size: source.size), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let titleFont = min(w, h) * (isMac ? 0.053 : 0.077)
        let subtitleFont = min(w, h) * (isMac ? 0.024 : 0.038)
        let textWidth = w - margin * 2
        let top = h - margin * 0.65
        drawText(lines[0], in: NSRect(x: margin, y: top - titleFont * 1.5, width: textWidth, height: titleFont * 1.65),
                 preferredSize: titleFont, weight: .bold, ink: color(24, 53, 85))
        drawText(lines[1], in: NSRect(x: margin, y: top - titleFont * 2.45, width: textWidth, height: subtitleFont * 1.7),
                 preferredSize: subtitleFont, weight: .regular, ink: color(71, 96, 120))

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = result.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
        let output = outputRoot.appendingPathComponent("\(key.components(separatedBy: "/")[0])/\(locale)/\(key.components(separatedBy: "/")[1]).png")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: output, options: .atomic)
        print("\(output.path) \(width)x\(height)")
    }
}
