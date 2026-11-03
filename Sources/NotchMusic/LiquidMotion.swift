import Foundation

/// Exact critically damped spring. Reversals preserve velocity instead of restarting a tween.
struct LiquidMotion {
    var position: Double = 0
    var velocity: Double = 0
    var target: Double = 0

    mutating func advance(by interval: Double) {
        let dt = max(0, min(0.05, interval))
        let frequency = 25.0
        let displacement = position - target
        let coefficient = velocity + frequency * displacement
        let decay = exp(-frequency * dt)
        position = target + (displacement + coefficient * dt) * decay
        velocity = (velocity - frequency * coefficient * dt) * decay
        if position < 0 { position = 0; velocity = max(0, velocity) }
        if position > 1 { position = 1; velocity = min(0, velocity) }
        if abs(position - target) < 0.0002 && abs(velocity) < 0.005 {
            position = target
            velocity = 0
        }
    }

    var settled: Bool { position == target && velocity == 0 }
}
