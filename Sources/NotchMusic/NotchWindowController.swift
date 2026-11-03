import AppKit
import Combine
import SwiftUI

final class NotchPanel: NSPanel {
    static let overlayLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    static func makeOverlay() -> NotchPanel {
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Setting isFloatingPanel resets level to NSFloatingWindowLevel (3).
        // Apply the explicit overlay level only after all panel behavior is configured.
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary,
                                    .fullScreenDisallowsTiling, .stationary, .ignoresCycle]
        panel.level = overlayLevel
        return panel
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    // AppKit normally moves windows below the menu bar, separating the island from the camera.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
final class NotchWindowController {
    let state = PanelState()
    private let playback: PlaybackStore
    private let settings: SettingsStore
    private let panel: NotchPanel
    private var subscriptions = Set<AnyCancellable>()
    private var closeTask: Task<Void, Never>?
    private var monitor: Any?
    private var localMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var pointerTimer: Timer?
    private var pointerInside = false
    private var lastPointerPoint: NSPoint?
    private var pointerInterval: TimeInterval = 0
    private var observePointer: Bool
    private var displaySleeping = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var spaceRecovery: Task<Void, Never>?
    private var motion = LiquidMotion()
    private var motionTimer: Timer?
    private var lastMotionTime: TimeInterval = 0
    private let surfaceMask = CAShapeLayer()
    static let expandedWidth: CGFloat = 548
    static let expandedBodyHeight: CGFloat = 260
    var openSettings: (() -> Void)?
    private(set) var hapticCount = 0
    var reducedMotionOverride: Bool?
    var frame: NSRect {
        let size = state.surfaceSize
        return NSRect(x: panel.frame.midX - size.width / 2, y: panel.frame.maxY - size.height, width: size.width, height: size.height)
    }
    var screenTop: CGFloat { settings.selectedScreen?.frame.maxY ?? 0 }

    init(playback: PlaybackStore, settings: SettingsStore, observePointer: Bool = true) {
        self.observePointer = observePointer
        self.playback = playback
        self.settings = settings
        panel = NotchPanel.makeOverlay()
        let host = NSHostingView(rootView: PlayerView(store: playback, panel: state))
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.mask = surfaceMask
        panel.contentView = host
        state.onToggle = { [weak self] in self?.toggle() }
        state.onSettings = { [weak self] in self?.openSettings?() }
        state.onPin = { [weak self] in self?.state.pinned.toggle() }
        state.onHaptic = { [weak self] in self?.tick() }
        settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.update(animated: false) }
        }.store(in: &subscriptions)
        playback.$track.map { $0 != nil }.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.update(animated: false) }
        }.store(in: &subscriptions)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.settings.screens = NSScreen.screens
                self?.update(animated: false)
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            workspaceObservers.append(workspace.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.restoreAcrossSpaces() }
            })
        }
        if observePointer {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
                Task { @MainActor in self?.pointerMoved(to: NSEvent.mouseLocation) }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
                self?.pointerMoved(to: NSEvent.mouseLocation)
                return event
            }
            // The physical camera and menu-bar windows can swallow tracking events.
            // Reading the pointer provides a fallback without Accessibility permission.
            configurePointerTimer(nearTop: false)
        }
        for event in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification] {
            workspaceObservers.append(workspace.addObserver(forName: event, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.displaySleeping = notification.name == NSWorkspace.screensDidSleepNotification
                    if self.displaySleeping { self.pointerTimer?.invalidate(); self.pointerTimer = nil; self.pointerInterval = 0 }
                    else { self.configurePointerTimer(nearTop: false); self.update(animated: false) }
                }
            })
        }
        update(animated: false)
    }

    func toggle() {
        settings.panelEnabled = true
        closeTask?.cancel()
        state.pinned = false
        state.expanded.toggle()
        tick()
        update(animated: true)
    }

    func show() {
        settings.panelEnabled = true
        closeTask?.cancel()
        if !state.expanded { tick() }
        state.expanded = true
        update(animated: true)
    }

    private func hover(_ inside: Bool) {
        closeTask?.cancel()
        if inside {
            guard settings.hoverToOpen, !state.expanded else { return }
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled, let self else { return }
                self.state.expanded = true
                self.tick()
                self.update(animated: true)
            }
        } else {
            guard !state.pinned else { return }
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self, !self.state.pinned else { return }
                // Resizing can generate transient exit events under a stationary cursor.
                guard !self.pointerInside else { return }
                self.state.expanded = false
                self.tick()
                self.update(animated: true)
            }
        }
    }

    private func update(animated: Bool) {
        guard let screen = settings.selectedScreen else { panel.orderOut(nil); return }
        if panel.level != NotchPanel.overlayLevel { panel.level = NotchPanel.overlayLevel }
        let topHeight = max(36, screen.safeAreaInsets.top)
        if state.topHeight != topHeight { state.topHeight = topHeight }
        let compactWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            compactWidth = max(280, right.minX - left.maxX + 112)
        } else { compactWidth = 288 }
        if state.compactWidth != compactWidth { state.compactWidth = compactWidth }
        let width = min(Self.expandedWidth, screen.frame.width)
        let height = state.topHeight + Self.expandedBodyHeight
        let geometryChanged = state.canvasSize != CGSize(width: width, height: height)
        if geometryChanged { state.canvasSize = CGSize(width: width, height: height) }
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        // The native window never resizes during a transition. One spring controls the
        // visible silhouette and its mask, preventing AppKit/SwiftUI rectangular flashes.
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        motion.target = state.expanded ? 1 : 0
        if animated || (motionTimer != nil && !geometryChanged),
           !(reducedMotionOverride ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
            startMotion()
        } else {
            motionTimer?.invalidate()
            motionTimer = nil
            motion.position = motion.target
            motion.velocity = 0
            applyMotion()
        }
        let visible = settings.panelEnabled && (!settings.hideWhenIdle || playback.track != nil || state.expanded)
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        playback.setPresentation(expanded: state.expanded, visible: visible)
        updateHitTesting()
    }

    private func updateHitTesting() {
        let point = NSEvent.mouseLocation
        let local = CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
        let path = silhouette(in: frame.size)
        panel.ignoresMouseEvents = !path.contains(local)
    }

    private func startMotion() {
        guard motionTimer == nil else { return }
        lastMotionTime = ProcessInfo.processInfo.systemUptime
        let frames = min(ProcessInfo.processInfo.isLowPowerModeEnabled ? 60 : 120,
                         max(60, settings.selectedScreen?.maximumFramesPerSecond ?? 60))
        let timer = Timer(timeInterval: 1.0 / Double(frames), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepMotion() }
        }
        RunLoop.main.add(timer, forMode: .common)
        motionTimer = timer
    }

    private func stepMotion() {
        let now = ProcessInfo.processInfo.systemUptime
        motion.advance(by: now - lastMotionTime)
        lastMotionTime = now
        applyMotion()
        if motion.settled { motionTimer?.invalidate(); motionTimer = nil }
    }

    private func applyMotion() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { state.expansion = CGFloat(motion.position) }
        lastPointerPoint = nil
        let size = state.surfaceSize
        let path = silhouette(in: size).cgPath
        // NSHostingView uses flipped coordinates, matching the SwiftUI silhouette.
        var transform = CGAffineTransform(translationX: (state.canvasSize.width - size.width) / 2, y: 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surfaceMask.frame = CGRect(origin: .zero, size: state.canvasSize)
        surfaceMask.path = path.copy(using: &transform)
        surfaceMask.fillColor = NSColor.black.cgColor
        CATransaction.commit()
        updateHitTesting()
    }

    func pointerMoved(to point: NSPoint) {
        guard !displaySleeping, panel.isVisible, settings.panelEnabled else { return }
        let nearTop = point.y > screenTop - 100
        configurePointerTimer(nearTop: nearTop)
        guard lastPointerPoint != point else { return }
        lastPointerPoint = point
        let local = CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
        let path = silhouette(in: frame.size)
        panel.ignoresMouseEvents = !path.contains(local)
        // Include the camera itself and a small approach area just below the island.
        let inside = path.contains(local) || (!state.expanded && frame.insetBy(dx: -3, dy: -6).contains(point))
        if !inside, pointerInside, NSEvent.pressedMouseButtons & 1 != 0 { return }
        guard inside != pointerInside else { return }
        pointerInside = inside
        hover(inside)
    }

    private func tick() {
        guard settings.haptics else { return }
        hapticCount += 1
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func silhouette(in size: CGSize) -> Path {
        NotchShape().path(in: CGRect(origin: .zero, size: size))
    }

    func saveSnapshot(to url: URL) throws {
        guard let view = panel.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    func setHoverEnabledForCheck(_ enabled: Bool) { settings.hoverToOpen = enabled }

    private func configurePointerTimer(nearTop: Bool) {
        guard observePointer, !displaySleeping else { return }
        let interval: TimeInterval = nearTop ? 0.12 : 0.75
        guard interval != pointerInterval else { return }
        pointerTimer?.invalidate()
        pointerInterval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved(to: NSEvent.mouseLocation) }
        }
        timer.tolerance = interval * 0.25
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    private func restoreAcrossSpaces() {
        spaceRecovery?.cancel()
        spaceRecovery = Task { [weak self] in
            // Space transitions finish after the initial activation notification.
            // Re-order without activating our app or making the panel key.
            for delay in [0, 250, 500, 750] {
                if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) }
                guard !Task.isCancelled, let self else { return }
                self.update(animated: false)
            }
        }
    }

    func savePresentationDiagnostics(to url: URL) throws {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        let ownIndex = windows.firstIndex { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == panel.windowNumber }
        let frontIndex = windows.firstIndex {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == frontmost?.processIdentifier
                && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
        }
        let above = ownIndex != nil && frontIndex != nil && ownIndex! < frontIndex!
        let report: [String: Any] = [
            "onActiveSpace": panel.isOnActiveSpace, "visible": panel.isVisible,
            "frontmost": frontmost?.bundleIdentifier ?? "", "onScreen": ownIndex != nil,
            "aboveFrontmostWindow": above, "expanded": state.expanded,
            "joinsAllApplications": panel.collectionBehavior.contains(.canJoinAllApplications),
            "windowLevel": panel.level.rawValue, "requiredWindowLevel": NotchPanel.overlayLevel.rawValue,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "compactWidth": state.compactWidth, "menuBarHeight": state.topHeight,
            "topErrorPoints": abs(frame.maxY - screenTop),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
    }
}
