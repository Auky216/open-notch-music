import AppKit
import Carbon
import SwiftUI

@main
enum NotchMusicMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var playback: PlaybackStore!
    private var settings: SettingsStore!
    private var notch: NotchWindowController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var presentationTimer: Timer?
    private let performance = PerformanceSampler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        let animationCheck = arguments.firstIndex(of: "--verify-animations")
        let demo = arguments.contains("--demo") || arguments.contains("--render-preview") || animationCheck != nil
        playback = PlaybackStore(demo: demo)
        if animationCheck != nil || arguments.contains("--render-preview"),
           let defaults = UserDefaults(suiteName: "local.antoniomac.NotchMusic.QA") {
            defaults.removePersistentDomain(forName: "local.antoniomac.NotchMusic.QA")
            settings = SettingsStore(defaults: defaults)
            settings.hoverToOpen = false
        } else { settings = SettingsStore() }
        if let index = arguments.firstIndex(of: "--render-preview"), arguments.count > index + 1 {
            renderPreview(path: arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        notch = NotchWindowController(playback: playback, settings: settings, observePointer: animationCheck == nil)
        notch.openSettings = { [weak self] in self?.showSettings() }
        if let index = animationCheck, arguments.count > index + 1 {
            Task {
                do { try await AnimationCheck.run(controller: notch, directory: URL(fileURLWithPath: arguments[index + 1])) }
                catch { NSLog("Animation check failed: %@", error.localizedDescription) }
                NSApp.terminate(nil)
            }
            return
        }
        createMenu()
        registerHotKey()
        if let index = arguments.firstIndex(of: "--presentation-report"), arguments.count > index + 1 {
            let url = URL(fileURLWithPath: arguments[index + 1])
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { try? self?.notch.savePresentationDiagnostics(to: url) }
            }
            RunLoop.main.add(timer, forMode: .common)
            presentationTimer = timer
        }
        if let index = arguments.firstIndex(of: "--performance-report"), arguments.count > index + 1 {
            performance.start(to: URL(fileURLWithPath: arguments[index + 1]), playback: playback, panel: notch.state)
        }
        if let index = arguments.firstIndex(of: "--audio-report"), arguments.count > index + 1 {
            let url = URL(fileURLWithPath: arguments[index + 1])
            Task { [weak self] in
                for _ in 0..<60 {
                    try? await Task.sleep(for: .seconds(1))
                    try? self?.playback.audioMeter.saveDiagnostics(to: url)
                }
            }
        }
        if arguments.contains("--connect") { playback.connect() }
        if arguments.contains("--expanded") {
            notch.show()
            notch.state.pinned = arguments.contains("--pinned")
        }
        if !UserDefaults.standard.bool(forKey: "hasSeenWelcome") || demo {
            notch.show()
            if !demo { UserDefaults.standard.set(true, forKey: "hasSeenWelcome") }
        }
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Notch Music")
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector, key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        item("Abrir reproductor", #selector(showPlayer))
        item("Conectar Spotify", #selector(connect))
        item("Abrir Spotify", #selector(openSpotify))
        menu.addItem(.separator())
        item("Mostrar / ocultar panel", #selector(togglePanel))
        item("Ajustes…", #selector(showSettings), key: ",")
        menu.addItem(.separator())
        item("Salir de Notch Music", #selector(quit), key: "q")
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Salir de Notch Music", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        applicationMenu.addItem(quitItem)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showPlayer() { notch.show() }
    @objc private func connect() { playback.connect(); notch.show() }
    @objc private func openSpotify() { playback.openSpotify() }
    @objc private func togglePanel() { settings.panelEnabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 650),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Notch Music"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings, playback: playback))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func registerHotKey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.notch.toggle() }
            return noErr
        }, 1, &event, pointer, &hotKeyHandler)
        guard installed == noErr else { settings.shortcutAvailable = false; return }
        let registered = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4E4D5553, id: 1),
                                             GetApplicationEventTarget(), 0, &hotKey)
        settings.shortcutAvailable = registered == noErr
    }

    func applicationWillTerminate(_ notification: Notification) {
        playback?.audioMeter.stop()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }

    private func renderPreview(path: String) {
        let state = PanelState()
        state.expanded = true
        state.expansion = 1
        state.canvasSize = CGSize(width: NotchWindowController.expandedWidth, height: state.topHeight + NotchWindowController.expandedBodyHeight)
        let preview = VStack(spacing: 35) {
            PlayerView(store: playback, panel: state, settings: settings).frame(width: NotchWindowController.expandedWidth, height: state.topHeight + NotchWindowController.expandedBodyHeight)
            Text("NOTCH MUSIC").font(.system(size: 12, weight: .medium, design: .rounded)).tracking(4).foregroundStyle(.white.opacity(0.55))
            Text("Tu música, justo aquí.").font(.system(size: 25, weight: .light)).foregroundStyle(.white.opacity(0.85))
        }.frame(width: 800, height: 480, alignment: .top)
            .background(LinearGradient(colors: [Color(red: 0.20, green: 0.32, blue: 0.37), Color(red: 0.07, green: 0.12, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing))
        let host = NSHostingView(rootView: preview)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 480), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
    }
}
