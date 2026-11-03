import AppKit
import CoreAudio
import os

/// Four actual frequency bands, with no clock-driven or random animation.
struct AudioBands {
    private var low: Float = 0
    private var middle: Float = 0
    private var high: Float = 0
    private var rate: Double = 0
    private var a: Float = 0
    private var b: Float = 0
    private var c: Float = 0

    mutating func measure(_ samples: UnsafeBufferPointer<Float>, channels: Int, sampleRate: Double) -> [Double] {
        let count = samples.count / max(1, channels)
        guard count > 0 else { return [0, 0, 0, 0] }
        if sampleRate != rate {
            rate = sampleRate
            a = Float(1 - exp(-2 * .pi * 180 / sampleRate))
            b = Float(1 - exp(-2 * .pi * 800 / sampleRate))
            c = Float(1 - exp(-2 * .pi * 3000 / sampleRate))
        }
        var e0 = 0.0, e1 = 0.0, e2 = 0.0, e3 = 0.0
        for frame in 0..<count {
            let sample = samples[frame * max(1, channels)]
            guard sample.isFinite else { continue }
            low += a * (sample - low)
            middle += b * (sample - middle)
            high += c * (sample - high)
            let m = middle - low, h = high - middle, t = sample - high
            e0 += Double(low * low)
            e1 += Double(m * m)
            e2 += Double(h * h)
            e3 += Double(t * t)
        }
        return [e0, e1, e2, e3].map {
            let rms = sqrt($0 / Double(count))
            // Fixed dB range: silence is zero; no automatic gain that turns noise into movement.
            return min(1, max(0, (20 * log10(max(0.000001, rms)) + 54) / 48))
        }
    }
}

private final class AudioMailbox: @unchecked Sendable {
    struct Reading {
        var levels = [Double](repeating: 0, count: 4)
        var timestamp: TimeInterval = 0
        var buffers = 0
        var maximum: Double = 0
    }
    private let lock = OSAllocatedUnfairLock(initialState: Reading())
    func publish(_ values: [Double]) {
        lock.withLock {
            $0.levels = values
            $0.timestamp = ProcessInfo.processInfo.systemUptime
            $0.buffers += 1
            $0.maximum = max($0.maximum, values.max() ?? 0)
        }
    }
    func read() -> Reading { lock.withLock { $0 } }
}

@available(macOS 14.2, *)
private final class SpotifyTap {
    private var tap: AudioObjectID = 0
    private var device: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private var analyzer = AudioBands()
    private let mailbox: AudioMailbox
    private let queue = DispatchQueue(label: "music.notch.audio-analysis", qos: .userInitiated)

    init(mailbox: AudioMailbox) { self.mailbox = mailbox }

    func start() throws {
        do {
            let processes = try spotifyProcessObjects()
            guard !processes.isEmpty else { throw MeterError.message("Reproduce una canción de Spotify en este Mac y vuelve a activar el ritmo.") }
            let description = CATapDescription(stereoMixdownOfProcesses: processes)
            description.name = "Notch Music · Spotify"
            description.isPrivate = true
            description.muteBehavior = .unmuted
            if #available(macOS 26, *) {
                description.bundleIDs = ["com.spotify.client"]
                description.isProcessRestoreEnabled = true
            }
            try check(AudioHardwareCreateProcessTap(description, &tap))
            var format = AudioStreamBasicDescription()
            var address = property(kAudioTapPropertyFormat)
            var bytes = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try check(AudioObjectGetPropertyData(tap, &address, 0, nil, &bytes, &format))
            guard format.mFormatID == kAudioFormatLinearPCM, format.mBitsPerChannel == 32,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0 else {
                throw MeterError.message("El formato de audio actual no es compatible con el visualizador.")
            }
            let composition: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Notch Music · Visualizador",
                kAudioAggregateDeviceUIDKey: "local.antoniomac.NotchMusic.meter.\(UUID().uuidString)",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString,
                                                   kAudioSubTapDriftCompensationKey: true]]
            ]
            try check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &device))
            let rate = format.mSampleRate
            try check(AudioDeviceCreateIOProcIDWithBlock(&ioProc, device, queue) { [weak self] _, input, _, _, _ in
                guard let self else { return }
                let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard let buffer = buffers.first, let data = buffer.mData else { return }
                let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
                let levels = self.analyzer.measure(samples, channels: Int(buffer.mNumberChannels), sampleRate: rate)
                self.mailbox.publish(levels)
            })
            try check(AudioDeviceStart(device, ioProc))
        } catch { stop(); throw error }
    }

    func stop() {
        if let ioProc, device != 0 {
            AudioDeviceStop(device, ioProc)
            AudioDeviceDestroyIOProcID(device, ioProc)
        }
        ioProc = nil
        if device != 0 { AudioHardwareDestroyAggregateDevice(device); device = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
    }

    private func spotifyProcessObjects() throws -> [AudioObjectID] {
        var address = property(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        try objects.withUnsafeMutableBytes { bytes in
            try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, bytes.baseAddress!))
        }
        return objects.filter { object in
            var nameAddress = property(kAudioProcessPropertyBundleID)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(object, &nameAddress, 0, nil, &nameSize, &name) == noErr,
                  let name else { return false }
            let bundle = name.takeRetainedValue() as String
            return bundle == "com.spotify.client" || bundle.hasPrefix("com.spotify.client.")
        }
    }

    private func property(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private func check(_ status: OSStatus) throws {
        guard status == noErr else { throw MeterError.status(status) }
    }
}

private enum MeterError: LocalizedError {
    case message(String), status(OSStatus)
    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        case .status(let code): return "No se pudo iniciar el ritmo real (\(code)). Revisa el permiso de Audio del sistema para Notch Music."
        }
    }
}

@MainActor
final class SpotifyAudioMeter: ObservableObject {
    @Published private(set) var levels = [Double](repeating: 0, count: 4)
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "realAudioEnabled")
    @Published private(set) var message = "Solo el audio de Spotify; se analiza en tu Mac y no se guarda."
    @Published private(set) var receiving = false
    private let mailbox = AudioMailbox()
    private var capture: AnyObject?
    private var timer: Timer?
    private var failed = false
    private var pid: pid_t?
    private var playbackActive = false

    var isCapturing: Bool { capture != nil }

    func setPlaybackActive(_ value: Bool) {
        guard playbackActive != value else { return }
        playbackActive = value
        if value { reconcile() } else { stop() }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "realAudioEnabled")
        failed = false
        if value { reconcile() } else { stop() }
    }

    func reconcile() {
        guard enabled, !failed, playbackActive else { return }
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first else { stop(); return }
        guard capture == nil || application.processIdentifier != pid else { return }
        stop()
        guard #available(macOS 14.2, *) else { message = "El ritmo real requiere macOS 14.2 o posterior."; failed = true; return }
        do {
            let tap = SpotifyTap(mailbox: mailbox)
            try tap.start()
            capture = tap
            pid = application.processIdentifier
            message = "Audio de Spotify conectado. El análisis es local."
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateLevels() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } catch {
            message = error.localizedDescription
            failed = true
        }
    }

    private func updateLevels() {
        let reading = mailbox.read()
        let fresh = ProcessInfo.processInfo.systemUptime - reading.timestamp < 0.25
        let isReceiving = fresh && reading.maximum > 0
        if receiving != isReceiving { receiving = isReceiving }
        let target = fresh ? reading.levels : [0, 0, 0, 0]
        let nextLevels = zip(levels, target).map { current, next in
            let value = current + (next - current) * (next > current ? 0.78 : 0.30)
            return value < 0.008 ? 0 : value
        }
        if zip(levels, nextLevels).contains(where: { abs($0 - $1) > 0.004 }) || (nextLevels.allSatisfy { $0 == 0 } && levels != nextLevels) {
            levels = nextLevels
        }
        if !fresh, message != "Esperando audio de Spotify en este Mac…" { message = "Esperando audio de Spotify en este Mac…" }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if #available(macOS 14.2, *), let tap = capture as? SpotifyTap { tap.stop() }
        capture = nil
        pid = nil
        levels = [0, 0, 0, 0]
        receiving = false
    }

    func saveDiagnostics(to url: URL) throws {
        let reading = mailbox.read()
        let report: [String: Any] = ["enabled": enabled, "buffers": reading.buffers, "peak": reading.maximum,
                                     "levels": reading.levels, "receiving": receiving, "message": message,
                                     "source": "Spotify process tap only", "savedAudio": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
    }
}
