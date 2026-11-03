import SwiftUI

struct AudioStatusView: View {
    @ObservedObject var meter: SpotifyAudioMeter
    let playing: Bool
    let demo: Bool
    var body: some View {
        Group {
            if demo {
                Label("Vista previa", systemImage: "waveform").foregroundStyle(.white.opacity(0.45))
            } else if !meter.enabled {
                Button { meter.setEnabled(true) } label: {
                    Label("Activar ritmo real", systemImage: "waveform")
                        .foregroundStyle(.white.opacity(0.65))
                }.buttonStyle(.plain).help("Permitir analizar solo el audio de Spotify en este Mac")
            } else {
                HStack(spacing: 6) {
                    ActivityBars(playing: playing, color: .white.opacity(0.7), meter: meter).scaleEffect(0.65).frame(width: 16, height: 14)
                    Text(!playing ? "En pausa" : meter.receiving ? "Ritmo en vivo" : "Esperando audio")
                }.foregroundStyle(.white.opacity(0.55)).help(meter.message)
            }
        }.font(.system(size: 10, weight: .medium))
    }
}

struct AudioMeterSettingsView: View {
    @ObservedObject var meter: SpotifyAudioMeter
    var body: some View {
        Toggle("Visualizador con audio real", isOn: Binding(get: { meter.enabled }, set: meter.setEnabled))
        Text(meter.message).font(.caption).foregroundStyle(.secondary)
        if meter.enabled && !meter.receiving {
            Button("Reintentar conexión de audio") { meter.setEnabled(true) }
        }
    }
}

struct SpotifyGlyph: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Color(red: 0.12, green: 0.84, blue: 0.38)))
            for index in 0..<3 {
                let inset = (0.21 + Double(index) * 0.035) * side
                let y = (0.37 + Double(index) * 0.17) * side
                var path = Path()
                path.move(to: CGPoint(x: inset, y: y))
                path.addQuadCurve(to: CGPoint(x: side - inset, y: y + side * 0.045), control: CGPoint(x: side * 0.52, y: y - side * 0.14))
                context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: side * (0.075 - Double(index) * 0.01), lineCap: .round))
            }
        }.accessibilityHidden(true)
    }
}

struct ChromeButtonStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.17 : hovering ? 0.11 : 0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(hovering ? 0.1 : 0.035), lineWidth: 0.5) }
            .onHover { hovering = $0 }
    }
}

struct TransportButtonStyle: ButtonStyle {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(hovering ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.91 : hovering ? 1.045 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
            .onHover { hovering = $0 }
    }
}

struct ProgressScrubber: View {
    let position: Double
    let duration: Double
    let disabled: Bool
    let onCommit: (Double) -> Void
    @State private var draft: Double?
    @State private var hovering = false
    @FocusState private var focused: Bool
    private var value: Double { min(max(0, duration), max(0, draft ?? position)) }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geometry in
                let fraction = duration > 0 ? value / duration : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.13)).frame(height: 3)
                    Capsule().fill(.white.opacity(disabled ? 0.45 : 0.85))
                        .frame(width: max(0, geometry.size.width * fraction), height: 3)
                    Circle().fill(.white).frame(width: 8, height: 8)
                        .offset(x: max(0, min(geometry.size.width - 8, geometry.size.width * fraction - 4)))
                        .opacity(hovering || draft != nil || focused ? 1 : 0)
                }
                .frame(height: 14).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { event in
                        guard !disabled, duration > 0 else { return }
                        draft = min(duration, max(0, event.location.x / max(1, geometry.size.width) * duration))
                    }
                    .onEnded { _ in
                        guard let draft else { return }
                        onCommit(draft)
                        self.draft = nil
                    })
            }.frame(height: 14)
            HStack {
                Text(timeLabel(value))
                Spacer()
                Text("−" + timeLabel(duration - value))
            }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
        }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Posición de reproducción")
        .accessibilityValue("\(timeLabel(value)) de \(timeLabel(duration))")
        .accessibilityAdjustableAction { direction in
            guard !disabled, duration > 0 else { return }
            switch direction {
            case .increment: onCommit(min(duration, value + 5))
            case .decrement: onCommit(max(0, value - 5))
            @unknown default: break
            }
        }
        .focusable(!disabled && duration > 0).focused($focused)
        .onKeyPress(.leftArrow) { guard !disabled else { return .ignored }; onCommit(max(0, value - 5)); return .handled }
        .onKeyPress(.rightArrow) { guard !disabled else { return .ignored }; onCommit(min(duration, value + 5)); return .handled }
    }
}
