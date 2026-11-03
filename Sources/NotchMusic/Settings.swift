import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var hoverToOpen: Bool { didSet { defaults.set(hoverToOpen, forKey: "hoverToOpen") } }
    @Published var hideWhenIdle: Bool { didSet { defaults.set(hideWhenIdle, forKey: "hideWhenIdle") } }
    @Published var screenID: String { didSet { defaults.set(screenID, forKey: "screenID") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    @Published var panelEnabled = true
    @Published var screens: [NSScreen] = NSScreen.screens
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginMessage = ""
    @Published var shortcutAvailable = true
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["hoverToOpen": true, "hideWhenIdle": false, "screenID": "auto", "haptics": true])
        hoverToOpen = defaults.bool(forKey: "hoverToOpen")
        hideWhenIdle = defaults.bool(forKey: "hideWhenIdle")
        screenID = defaults.string(forKey: "screenID") ?? "auto"
        haptics = defaults.bool(forKey: "haptics")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginMessage = SMAppService.mainApp.status == .requiresApproval ? "Activa Notch Music en los ítems de inicio de Ajustes del Sistema." : ""
        } catch { loginMessage = "No se pudo cambiar el inicio de sesión: \(error.localizedDescription)" }
    }

    var selectedScreen: NSScreen? {
        screens.first(where: { $0.stableID == screenID }) ?? screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? screens.first
    }
}

extension NSScreen {
    var stableID: String { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? localizedName }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var playback: PlaybackStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 62, height: 62)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Notch Music").font(.title2.weight(.semibold))
                    Text("Tu música, justo aquí.").foregroundStyle(.secondary)
                }
                Spacer()
                Text("0.4.2").font(.caption).foregroundStyle(.tertiary)
            }
            Form {
                Section("Interacción") {
                    Toggle("Abrir al pasar el cursor", isOn: $settings.hoverToOpen)
                    Toggle("Respuesta háptica del trackpad", isOn: $settings.haptics)
                    Toggle("Ocultar cuando no haya una canción", isOn: $settings.hideWhenIdle)
                    Toggle("Mostrar el panel", isOn: $settings.panelEnabled)
                }
                Section("Pantalla") {
                    Picker("Mostrar en", selection: $settings.screenID) {
                        Text("Automática · preferir notch").tag("auto")
                        ForEach(settings.screens, id: \.stableID) { screen in Text(screen.localizedName).tag(screen.stableID) }
                    }
                }
                Section("General") {
                    Toggle("Abrir al iniciar sesión", isOn: Binding(get: { settings.launchAtLogin }, set: settings.setLaunchAtLogin))
                    if !settings.loginMessage.isEmpty { Text(settings.loginMessage).font(.caption).foregroundStyle(.secondary) }
                }
                Section("Spotify") {
                    Text(playback.demo ? "Vista de demostración. Los controles no afectan a Spotify." : "Spotify reproduce el audio. Notch Music muestra la canción y envía tus controles.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button("Conectar Spotify") { playback.connect() }.disabled(playback.demo)
                        Button("Permisos…") { playback.openPrivacy() }
                    }
                }
                Section("Ritmo de la música") {
                    AudioMeterSettingsView(meter: playback.audioMeter)
                }
            }.formStyle(.grouped)
            HStack {
                Text(settings.shortcutAvailable ? "⌃⌥Espacio abre o cierra el reproductor." : "Abre el reproductor desde el icono de la barra de menús.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
            }
        }
        .padding(24).frame(width: 490, height: 565).preferredColorScheme(.dark)
    }
}
