import AppKit
import SwiftUI

enum IslandAppearance: String, CaseIterable, Identifiable {
    case normal, albumGradient, liquidGlass
    var id: String { rawValue }
    var title: String {
        switch self {
        case .normal: return "Normal · negro"
        case .albumGradient: return "Degradado de la canción"
        case .liquidGlass: return "Liquid Glass"
        }
    }
    var detail: String {
        switch self {
        case .normal: return "Fondo negro uniforme, integrado con el notch."
        case .albumGradient: return "Un degradado intenso que toma el color de la carátula."
        case .liquidGlass:
            if #available(macOS 26.0, *) { return "Cristal nativo en toda la isla. La cámara física permanece negra." }
            return "Material translúcido compatible. El cristal nativo requiere macOS 26."
        }
    }
}

enum VisualizerColor: String, CaseIterable, Identifiable {
    case white, album
    var id: String { rawValue }
    var title: String { self == .white ? "Blanco" : "Adaptado a la canción" }
}

struct IslandSurface: ViewModifier {
    let appearance: IslandAppearance
    let tint: Color
    let secondary: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        switch appearance {
        case .normal:
            content.background(Color.black)
        case .albumGradient:
            content.background {
                LinearGradient(colors: [tint.opacity(0.90), secondary.opacity(0.82), .black.opacity(0.94)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .background(Color.black)
                    .overlay {
                        LinearGradient(colors: [.black.opacity(0.03), .black.opacity(0.35)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
        case .liquidGlass:
            if reduceTransparency {
                content.background(Color(white: 0.075))
            } else if #available(macOS 26.0, *) {
                // Apply glass to the content itself so it participates in native vibrancy.
                content.glassEffect(.regular, in: NotchShape())
            } else {
                content.background { LegacyGlassMaterial() }
                    .overlay { NotchShape().stroke(.white.opacity(0.18), lineWidth: 0.5).allowsHitTesting(false) }
            }
        }
    }
}

private struct LegacyGlassMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Computed only when artwork changes, using 1,024 pixels rather than a full-size image.
struct ArtworkPalette {
    let background: NSColor
    let secondary: NSColor
    let accent: NSColor

    static func extract(from image: NSImage) -> ArtworkPalette {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 128, bitsPerPixel: 32),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return neutral }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .medium
        image.draw(in: CGRect(x: 0, y: 0, width: 32, height: 32), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        var buckets = [(weight: Double, red: Double, green: Double, blue: Double)](repeating: (0, 0, 0, 0), count: 12)
        for y in 0..<32 {
            for x in 0..<32 {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      color.alphaComponent > 0.5, color.saturationComponent > 0.15,
                      color.brightnessComponent > 0.12 else { continue }
                let index = min(11, Int(color.hueComponent * 12))
                let weight = 0.35 + color.saturationComponent
                buckets[index].weight += weight
                buckets[index].red += color.redComponent * weight
                buckets[index].green += color.greenComponent * weight
                buckets[index].blue += color.blueComponent * weight
            }
        }
        guard let dominant = buckets.max(by: { $0.weight < $1.weight }), dominant.weight > 0 else { return neutral }
        let color = NSColor(srgbRed: dominant.red / dominant.weight, green: dominant.green / dominant.weight,
                            blue: dominant.blue / dominant.weight, alpha: 1)
        let hue = color.hueComponent
        let saturation = min(0.9, max(0.42, color.saturationComponent))
        return ArtworkPalette(
            background: NSColor(hue: hue, saturation: saturation, brightness: min(0.78, max(0.58, color.brightnessComponent)), alpha: 1),
            secondary: NSColor(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: 0.36, alpha: 1),
            accent: NSColor(hue: hue, saturation: min(0.62, saturation), brightness: 1, alpha: 1))
    }

    static let neutral = ArtworkPalette(background: NSColor(srgbRed: 0.42, green: 0.42, blue: 0.42, alpha: 1),
                                        secondary: NSColor(srgbRed: 0.20, green: 0.20, blue: 0.20, alpha: 1),
                                        accent: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
}
