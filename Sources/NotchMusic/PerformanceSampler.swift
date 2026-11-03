import AppKit
import Darwin

/// Opt-in diagnostics: measures only this process, never other apps or their content.
@MainActor
final class PerformanceSampler {
    private var timer: Timer?
    private var lastCPU = 0.0
    private var lastTime = 0.0
    private var readings: [Double] = []
    private var ticks = 0

    func start(to url: URL, playback: PlaybackStore, panel: PanelState) {
        lastCPU = cpuTime()
        lastTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self, weak playback, weak panel] _ in
            MainActor.assumeIsolated {
                guard let self, let playback, let panel else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let cpu = self.cpuTime()
                let percent = max(0, 100 * (cpu - self.lastCPU) / max(0.001, now - self.lastTime))
                self.lastCPU = cpu
                self.lastTime = now
                self.ticks += 1
                if self.ticks > 5 { self.readings.append(percent) }
                if self.readings.count > 60 { self.readings.removeFirst() }
                var info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
                let result = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                    }
                }
                let report: [String: Any] = [
                    "cpuPercentOfOneCore": percent,
                    "meanCPUPercentAfterWarmup": self.readings.isEmpty ? 0 : self.readings.reduce(0, +) / Double(self.readings.count),
                    "samplesAfterWarmup": self.readings.count,
                    "residentMB": result == KERN_SUCCESS ? Double(info.resident_size) / 1048576 : 0,
                    "playing": playback.track?.isPlaying ?? false, "expanded": panel.expanded,
                    "audioCaptureRunning": playback.audioMeter.isCapturing,
                    "pollIntervalSeconds": playback.pollInterval,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
                try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func cpuTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
}
