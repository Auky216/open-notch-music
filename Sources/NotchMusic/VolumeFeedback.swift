import Foundation

/// Distance-based steps avoid repeated ticks when the pointer jitters around a boundary.
struct VolumeFeedbackGate {
    private var lastVolume = 0.0
    private var lastTime = -Double.infinity

    mutating func reset(at volume: Double) {
        lastVolume = volume.isFinite ? min(100, max(0, volume)) : 0
        lastTime = -Double.infinity
    }

    mutating func update(_ volume: Double, at time: TimeInterval) -> Bool {
        guard volume.isFinite, time.isFinite else { return false }
        let value = min(100, max(0, volume))
        let endpoint = (value == 0 || value == 100) && value != lastVolume
        guard abs(value - lastVolume) >= 10 || endpoint, time - lastTime >= 0.08 else { return false }
        lastVolume = value
        lastTime = time
        return true
    }
}
