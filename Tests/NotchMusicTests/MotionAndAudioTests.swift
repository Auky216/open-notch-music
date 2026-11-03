import XCTest
@testable import NotchMusic

final class MotionAndAudioTests: XCTestCase {
    func testLiquidSpringIsContinuousAndStaysWithinTheSilhouette() {
        var spring = LiquidMotion()
        spring.target = 1
        var last = 0.0
        for _ in 0..<90 {
            spring.advance(by: 1.0 / 120)
            XCTAssertGreaterThanOrEqual(spring.position, last)
            XCTAssertLessThanOrEqual(spring.position, 1)
            XCTAssertLessThan(spring.position - last, 0.09)
            last = spring.position
        }
        XCTAssertEqual(spring.position, 1)
        spring.target = 0
        for _ in 0..<10 { spring.advance(by: 1.0 / 120) }
        let position = spring.position
        let velocity = spring.velocity
        spring.target = 1
        XCTAssertEqual(spring.position, position)
        XCTAssertEqual(spring.velocity, velocity)
        for _ in 0..<120 {
            spring.advance(by: 1.0 / 120)
            XCTAssertTrue((0...1).contains(spring.position))
        }
        XCTAssertEqual(spring.position, 1)
    }

    func testAudioBandsReactToActualFrequencyAndSilence() {
        func measure(frequency: Double) -> [Double] {
            var analyzer = AudioBands()
            let samples = (0..<8192).map { Float(0.4 * sin(2 * .pi * frequency * Double($0) / 48000)) }
            return samples.withUnsafeBufferPointer { analyzer.measure($0, channels: 1, sampleRate: 48000) }
        }
        let bass = measure(frequency: 70)
        let treble = measure(frequency: 9000)
        XCTAssertGreaterThan(bass[0], bass[3])
        XCTAssertGreaterThan(treble[3], treble[0])
        var analyzer = AudioBands()
        let silence = [Float](repeating: 0, count: 2048)
        XCTAssertEqual(silence.withUnsafeBufferPointer { analyzer.measure($0, channels: 1, sampleRate: 48000) }, [0, 0, 0, 0])
    }
}
