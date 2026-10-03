import AppKit

// Vector drawing in a 1024-point canvas, rendered directly at each macOS icon
// resolution. Run: swift Tools/generate-app-icon.swift
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("codex-usage-swift/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func stroke(_ points: [CGPoint], color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func arc(to endAngle: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.appendArc(withCenter: CGPoint(x: 512, y: 520), radius: 250,
                   startAngle: 225, endAngle: endAngle, clockwise: true)
    path.lineWidth = 44
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

func render(size: Int) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let tile = NSBezierPath(roundedRect: CGRect(x: 96, y: 96, width: 832, height: 832),
                            xRadius: 184, yRadius: 184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = CGSize(width: 0, height: -12)
    shadow.set()
    NSColor(red: 0.055, green: 0.075, blue: 0.09, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(red: 0.055, green: 0.075, blue: 0.09, alpha: 1),
                        NSColor(red: 0.12, green: 0.21, blue: 0.23, alpha: 1)])!
        .draw(in: tile, angle: 90)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    let mint = NSColor(red: 0.34, green: 0.88, blue: 0.73, alpha: 1)
    arc(to: -45, color: mint.withAlphaComponent(0.16))
    arc(to: 45, color: mint)
    // A terminal prompt in the gauge makes the coding/usage purpose readable
    // at Dock size without letters or an unofficial product logo.
    stroke([CGPoint(x: 397, y: 581), CGPoint(x: 469, y: 520), CGPoint(x: 397, y: 459)],
           color: NSColor(white: 0.96, alpha: 1), width: 32)
    stroke([CGPoint(x: 526, y: 459), CGPoint(x: 624, y: 459)], color: mint, width: 32)
    NSGraphicsContext.restoreGraphicsState()

    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent("icon_\(size).png"))
}

for size in [16, 32, 64, 128, 256, 512, 1024] { try render(size: size) }

let entries: [[String: String]] = [16, 32, 128, 256, 512].flatMap { size in
    [1, 2].map { scale in
        ["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x",
         "filename": "icon_\(size * scale).png"]
    }
}
let catalog: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Generated all macOS AppIcon sizes in \(output.path)")
