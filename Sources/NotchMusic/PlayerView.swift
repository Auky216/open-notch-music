import SwiftUI

@MainActor
final class PanelState: ObservableObject {
    @Published var expanded = false
    @Published var pinned = false
    @Published var topHeight: CGFloat = 36
    @Published var compactWidth: CGFloat = 300
    @Published var expansion: CGFloat = 0
    @Published var canvasSize = CGSize(width: 548, height: 334)
    var surfaceSize: CGSize {
        CGSize(width: compactWidth + (canvasSize.width - compactWidth) * expansion,
               height: topHeight + (canvasSize.height - topHeight) * expansion)
    }
    var onToggle: (() -> Void)?
    var onSettings: (() -> Void)?
    var onPin: (() -> Void)?
    var onHaptic: (() -> Void)?
}

struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let top: CGFloat = 12
        let bottom: CGFloat = min(27, rect.height * 0.4)
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: top, y: top), control: CGPoint(x: top, y: 0))
        p.addLine(to: CGPoint(x: top, y: rect.height - bottom))
        p.addQuadCurve(to: CGPoint(x: top + bottom, y: rect.height), control: CGPoint(x: top, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width - top - bottom, y: rect.height))
        p.addQuadCurve(to: CGPoint(x: rect.width - top, y: rect.height - bottom), control: CGPoint(x: rect.width - top, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width - top, y: top))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.width - top, y: 0))
        p.closeSubpath()
        return p
    }
}

struct ArtworkView: View {
    let image: NSImage?
    var size: CGFloat
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else {
                RoundedRectangle(cornerRadius: size * 0.17).fill(.white.opacity(0.075))
                    .overlay { Image(systemName: "music.note").font(.system(size: size * 0.35, weight: .medium)).foregroundStyle(.white.opacity(0.45)) }
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.17, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: size * 0.17).strokeBorder(.white.opacity(0.09), lineWidth: 0.5) }
        .accessibilityHidden(true)
    }
}

struct ActivityBars: View {
    let playing: Bool
    let color: Color
    @ObservedObject var meter: SpotifyAudioMeter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<4) { index in
                Capsule().fill(color.opacity(0.9))
                    .frame(width: 3, height: playing && !reduceMotion ? 3 + 20 * meter.levels[index] : 3)
            }
        }.frame(width: 22, height: 24)
            .accessibilityLabel(meter.receiving && playing ? "Visualizador del audio real de Spotify" : "Sin señal de audio")
    }
}

struct PlayerView: View {
    @ObservedObject var store: PlaybackStore
    @ObservedObject var panel: PanelState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = panel.surfaceSize
        let contentOpacity = min(1, max(0, (panel.expansion - 0.28) / 0.65))
        ZStack(alignment: .top) {
            if panel.expansion > 0.0001 {
                VStack(spacing: 0) {
                    Color.clear.frame(height: panel.topHeight)
                    header
                    if let track = store.track {
                        expanded(track)
                    } else { emptyState }
                }
                .frame(width: panel.canvasSize.width, height: panel.canvasSize.height, alignment: .top)
                .offset(y: 4 * (1 - panel.expansion))
                .opacity(contentOpacity)
                .allowsHitTesting(panel.expansion > 0.94 && panel.expanded)
                .accessibilityHidden(panel.expansion < 0.94 || !panel.expanded)
            }
            compact.frame(width: size.width, height: panel.topHeight)
                .opacity(max(0, 1 - panel.expansion * 4))
                .allowsHitTesting(!panel.expanded)
                .accessibilityHidden(panel.expanded)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background {
            ZStack(alignment: .leading) {
                Color.black
                if store.track != nil {
                    RadialGradient(colors: [store.tint.opacity(0.26), .clear],
                                   center: .init(x: 0.2, y: 0.45), startRadius: 10, endRadius: 330)
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                }
            }
            .overlay(alignment: .top) { Color.black.frame(height: panel.topHeight) }
            .opacity(panel.expansion)
            .background(Color.black)
        }
        .clipShape(NotchShape())
        .contentShape(NotchShape())
        .preferredColorScheme(.dark)
        .tint(.white)
        .onExitCommand { panel.onToggle?() }
        .frame(width: panel.canvasSize.width, height: panel.canvasSize.height, alignment: .top)
    }

    private var compact: some View {
        Button { panel.onToggle?() } label: {
            HStack {
                ArtworkView(image: store.artwork, size: max(22, panel.topHeight - 10))
                Spacer(minLength: 0)
                if store.track != nil {
                    ActivityBars(playing: store.track?.isPlaying == true, color: .white, meter: store.audioMeter)
                } else {
                    Image(systemName: store.permissionDenied ? "exclamationmark.circle" : "music.note")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 23).frame(height: panel.topHeight)
            .frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Abrir reproductor de Notch Music")
        .help("Abrir reproductor · ⌃⌥Espacio")
    }

    private var header: some View {
        HStack {
            Button { store.openSpotify() } label: {
                SpotifyGlyph().frame(width: 19, height: 19)
                    .padding(.horizontal, 10).padding(.vertical, 4)
            }
            .buttonStyle(ChromeButtonStyle())
            .help("Abrir Spotify").accessibilityLabel("Abrir Spotify")
            if store.demo { Text("VISTA PREVIA").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary) }
            Spacer()
            Button { panel.onPin?() } label: {
                Image(systemName: panel.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 26)
                    .foregroundStyle(panel.pinned ? Color.mint : .white.opacity(0.65))
            }.buttonStyle(ChromeButtonStyle()).help("Mantener abierto").accessibilityLabel(panel.pinned ? "Desfijar panel" : "Mantener abierto")
            Button { panel.onSettings?() } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 26).foregroundStyle(.white.opacity(0.65))
            }.buttonStyle(ChromeButtonStyle()).help("Ajustes").accessibilityLabel("Ajustes")
        }
        .padding(.horizontal, 29).frame(height: 36)
    }

    private func expanded(_ track: PlaybackSnapshot) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 21) {
                ArtworkView(image: store.artwork, size: 116)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title).font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true).help(track.title)
                    Text(track.artist).font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70)).lineLimit(1).help(track.artist)
                    Text(track.album).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                    AudioStatusView(meter: store.audioMeter, playing: track.isPlaying, demo: store.demo)
                        .padding(.top, 5)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            SeekView(track: track, disabled: store.busy || store.demo) { position in
                panel.onHaptic?()
                store.send(.seek(position))
            }
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    iconButton("shuffle", label: "Aleatorio", size: 14) { store.send(.shuffle(!track.shuffle)) }
                        .foregroundStyle(track.shuffle ? Color.mint : .white.opacity(0.45))
                    iconButton("repeat", label: "Repetir", size: 14) { store.send(.repeating(!track.repeatEnabled)) }
                        .foregroundStyle(track.repeatEnabled ? Color.mint : .white.opacity(0.45))
                }.frame(width: 108, alignment: .leading)
                Spacer(minLength: 4)
                HStack(spacing: 12) {
                    transport("backward.end.fill", label: "Canción anterior") { store.send(.previous) }
                    Button { store.send(.toggle) } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .semibold)).offset(x: track.isPlaying ? 0 : 1)
                            .foregroundStyle(.black).frame(width: 52, height: 52)
                            .background(LinearGradient(colors: [.white, .white.opacity(0.85)], startPoint: .top, endPoint: .bottom), in: Circle())
                            .shadow(color: .white.opacity(0.12), radius: 12, y: 2)
                    }.buttonStyle(TransportButtonStyle())
                        .help(track.isPlaying ? "Pausar" : "Reproducir").accessibilityLabel(track.isPlaying ? "Pausar" : "Reproducir")
                    transport("forward.end.fill", label: "Siguiente canción") { store.send(.next) }
                }
                Spacer(minLength: 4)
                VolumeView(volume: track.volume, disabled: store.busy || store.demo) { store.send(.volume($0)) }
                    .frame(width: 108, alignment: .trailing)
            }
            .disabled(store.busy || store.demo)
        }.padding(.horizontal, 33).padding(.top, 12).padding(.bottom, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.permissionDenied ? "lock.shield" : "music.note")
                .font(.system(size: 29, weight: .light)).foregroundStyle(.mint)
            Text(store.permissionDenied ? "Un permiso y listo" : "Tu música, justo aquí.")
                .font(.system(size: 19, weight: .semibold))
            Text(store.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if store.permissionDenied {
                    Button("Abrir permisos") { store.openPrivacy() }
                    Button("Reintentar") { store.connect() }
                } else {
                    Button("Abrir Spotify") { store.openSpotify() }
                    if !store.connected {
                        Button { store.connect() } label: {
                            Text("Conectar").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black).padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Color.mint, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }.controlSize(.small).padding(.top, 3)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 40).padding(.bottom, 20)
    }

    private func iconButton(_ symbol: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .medium))
                .frame(width: 30, height: 30).contentShape(Rectangle())
        }.buttonStyle(ChromeButtonStyle()).help(label).accessibilityLabel(label)
    }

    private func transport(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white).frame(width: 40, height: 40)
                .background(.white.opacity(0.06), in: Circle())
        }.buttonStyle(TransportButtonStyle()).help(label).accessibilityLabel(label)
    }
}

struct SeekView: View {
    let track: PlaybackSnapshot
    let disabled: Bool
    let seek: (Double) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: track.isPlaying ? 0.5 : 60)) { context in
            ProgressScrubber(position: track.progress(at: context.date), duration: track.duration,
                             disabled: disabled, onCommit: seek)
        }.id(track.id)
    }
}

struct VolumeView: View {
    let volume: Double
    let disabled: Bool
    let setVolume: (Double) -> Void
    @State private var draft: Double?
    @State private var dragging = false
    @State private var commitTask: Task<Void, Never>?
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.4)).frame(width: 15)
            Slider(value: Binding(get: { draft ?? min(100, max(0, volume)) }, set: { draft = $0 }), in: 0...100, onEditingChanged: { editing in
                dragging = editing
                if !editing { commit() }
            }).controlSize(.mini).frame(width: 85).disabled(disabled).accessibilityLabel("Volumen de Spotify")
        }
        .onChange(of: draft) { _, value in
            commitTask?.cancel()
            guard value != nil, !dragging else { return }
            commitTask = Task {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                commit()
            }
        }
        .onDisappear { commitTask?.cancel() }
    }

    private func commit() {
        commitTask?.cancel()
        if let value = draft { setVolume(value); draft = nil }
    }
}
