import AppKit
import SwiftUI
import ImageIO

@MainActor
final class PlaybackStore: ObservableObject {
    @Published private(set) var track: PlaybackSnapshot?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var tint: Color = .mint
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var message = "Conecta Spotify para ver y controlar lo que escuchas."
    @Published private(set) var permissionDenied = false
    let demo: Bool
    let audioMeter = SpotifyAudioMeter()
    private let provider: MusicProvider
    private var pollTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private let cache = NSCache<NSURL, NSImage>()
    private var currentArtworkURL: URL?
    private var reading = false
    private var revision = 0
    private var sleeping = false
    private var expanded = false
    private var visible = true
    private var observers: [NSObjectProtocol] = []

    init(provider: MusicProvider = SpotifyProvider(), demo: Bool = false) {
        self.provider = provider
        self.demo = demo
        connected = !demo && UserDefaults.standard.bool(forKey: "spotifyConnected")
        cache.countLimit = 12
        cache.totalCostLimit = 8 * 1024 * 1024
        if demo {
            track = .demo
            connected = true
            artwork = Self.demoArtwork()
            tint = Color(red: 0.61, green: 0.76, blue: 0.95)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = true; self?.audioMeter.setPlaybackActive(false) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = false; await self?.refresh() }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        })
        for event in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                      NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: event, object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    guard let self else { return }
                    if notification.name == NSWorkspace.screensDidSleepNotification {
                        self.sleeping = true
                        self.audioMeter.setPlaybackActive(false)
                    } else if notification.name == NSWorkspace.screensDidWakeNotification {
                        self.sleeping = false
                        await self.refresh()
                    } else if (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == "com.spotify.client" {
                        await self.refresh()
                    }
                }
            })
        }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.pollInterval ?? 12
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    var pollInterval: Double {
        guard connected, !sleeping, track != nil else { return 12 }
        guard track?.isPlaying == true else { return 8 }
        return expanded && visible ? 2 : 4
    }

    func setPresentation(expanded: Bool, visible: Bool) {
        let opening = expanded && !self.expanded
        self.expanded = expanded
        self.visible = visible
        audioMeter.setPlaybackActive(track?.isPlaying == true && visible && !sleeping)
        if opening && !demo { Task { await refresh() } }
    }

    func connect() {
        guard !demo else { return }
        connected = true
        permissionDenied = false
        message = "Conectando con Spotify…"
        Task { await refresh() }
    }

    func refresh() async {
        guard connected, !demo, !sleeping, !reading, !busy else { return }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty == false else {
            clearTrack()
            message = "Abre Spotify para empezar a escuchar."
            return
        }
        reading = true
        let version = revision
        defer { reading = false }
        do {
            let snapshot = try await provider.read()
            guard version == revision else { return }
            apply(snapshot)
        } catch {
            guard version == revision else { return }
            handle(error)
        }
    }

    func send(_ command: PlaybackCommand) {
        guard connected, track != nil, !busy, !demo else { return }
        revision += 1
        busy = true
        Task {
            defer { busy = false }
            do {
                try await provider.send(command)
                apply(try await provider.read())
            } catch { handle(error) }
        }
    }

    private func handle(_ error: Error) {
        clearTrack()
        message = error.localizedDescription
        if case SpotifyError.permission = error {
            permissionDenied = true
            connected = false
            UserDefaults.standard.set(false, forKey: "spotifyConnected")
        }
    }

    private func clearTrack() {
        audioMeter.setPlaybackActive(false)
        track = nil
        artworkTask?.cancel()
        currentArtworkURL = nil
        artwork = nil
        tint = .mint
    }

    private func apply(_ snapshot: PlaybackSnapshot) {
        if !demo {
            audioMeter.setPlaybackActive(snapshot.isPlaying && visible && !sleeping)
            if snapshot.isPlaying && visible && !sleeping { audioMeter.reconcile() }
        }
        if let current = track {
            var comparable = current
            comparable.position = snapshot.position
            comparable.sampledAt = snapshot.sampledAt
            if comparable != snapshot || abs(current.progress(at: snapshot.sampledAt) - snapshot.position) > 0.6 {
                track = snapshot
            }
        } else { track = snapshot }
        if !UserDefaults.standard.bool(forKey: "spotifyConnected") { UserDefaults.standard.set(true, forKey: "spotifyConnected") }
        message = ""
        permissionDenied = false
        guard currentArtworkURL != snapshot.artworkURL else { return }
        artworkTask?.cancel()
        currentArtworkURL = snapshot.artworkURL
        artwork = nil
        tint = .mint
        guard let url = snapshot.artworkURL else { return }
        if let cached = cache.object(forKey: url as NSURL) { setArtwork(cached); return }
        artworkTask = Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 12
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled, currentArtworkURL == url,
                      let response = response as? HTTPURLResponse, response.statusCode == 200,
                      data.count <= 10_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 320,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return }
                let image = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
                cache.setObject(image, forKey: url as NSURL, cost: thumbnail.bytesPerRow * thumbnail.height)
                setArtwork(image)
            } catch { /* The placeholder remains usable without a network connection. */ }
        }
    }

    private func setArtwork(_ image: NSImage) {
        artwork = image
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        NSGraphicsContext.restoreGraphicsState()
        if let color = rep.colorAt(x: 0, y: 0) { tint = Color(nsColor: color) }
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") else {
            message = "Instala Spotify para usar el reproductor."
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    static func demoArtwork() -> NSImage {
        let image = NSImage(size: NSSize(width: 360, height: 360))
        image.lockFocus()
        NSGradient(colors: [.init(srgbRed: 0.09, green: 0.15, blue: 0.31, alpha: 1),
                            .init(srgbRed: 0.45, green: 0.60, blue: 0.75, alpha: 1)])?.draw(in: NSRect(x: 0, y: 0, width: 360, height: 360), angle: 55)
        NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
        for index in 0..<6 {
            NSBezierPath(ovalIn: NSRect(x: 55 + index * 17, y: 25 + index * 24, width: 200, height: 200)).fill()
        }
        let text = "N"
        text.draw(at: NSPoint(x: 131, y: 115), withAttributes: [.font: NSFont.systemFont(ofSize: 110, weight: .ultraLight), .foregroundColor: NSColor.white])
        image.unlockFocus()
        return image
    }
}
