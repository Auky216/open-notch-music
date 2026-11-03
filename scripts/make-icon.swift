import AppKit

// Geometric source, mirrored in Resources/Icon/AppIcon.svg. No runtime rendering.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 184, yRadius: 184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
    shadow.shadowBlurRadius = 16
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    NSColor(srgbRed: 0.91, green: 0.92, blue: 0.94, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(srgbRed: 0.88, green: 0.89, blue: 0.91, alpha: 1),
                        NSColor(srgbRed: 0.99, green: 0.99, blue: 1.0, alpha: 1)])!.draw(in: tile, angle: 90)
    NSColor.white.withAlphaComponent(0.7).setStroke()
    tile.lineWidth = 2
    tile.stroke()
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: 1024 - y) }
    let notch = NSBezierPath()
    notch.move(to: point(256, 356))
    notch.line(to: point(768, 356))
    notch.curve(to: point(742, 382), controlPoint1: point(752, 356), controlPoint2: point(742, 366))
    notch.line(to: point(742, 576))
    notch.curve(to: point(650, 668), controlPoint1: point(742, 637), controlPoint2: point(711, 668))
    notch.line(to: point(374, 668))
    notch.curve(to: point(282, 576), controlPoint1: point(313, 668), controlPoint2: point(282, 637))
    notch.line(to: point(282, 382))
    notch.curve(to: point(256, 356), controlPoint1: point(282, 366), controlPoint2: point(272, 356))
    notch.close()
    NSGradient(colors: [NSColor(srgbRed: 0.025, green: 0.028, blue: 0.035, alpha: 1),
                        NSColor(srgbRed: 0.09, green: 0.095, blue: 0.11, alpha: 1)])!.draw(in: notch, angle: 90)
    NSColor(srgbRed: 0.985, green: 0.985, blue: 0.995, alpha: 1).setFill()
    let bars: [(CGFloat, CGFloat)] = [(398, 84), (488, 164), (578, 116)]
    for (x, height) in bars {
        NSBezierPath(roundedRect: NSRect(x: x, y: 1024 - 512 - height / 2, width: 48, height: height), xRadius: 24, yRadius: 24).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    if [16, 32, 128, 256, 512].contains(size) { try data.write(to: output.appendingPathComponent("icon_\(size)x\(size).png")) }
    if [16, 32, 128, 256, 512].contains(size / 2) { try data.write(to: output.appendingPathComponent("icon_\(size / 2)x\(size / 2)@2x.png")) }
}
