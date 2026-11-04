import XCTest
@testable import NotchMusic

final class VolumeFeedbackTests: XCTestCase {
    func testDraggingDoesNotTickForEveryPixelOrJitter() {
        var gate = VolumeFeedbackGate()
        gate.reset(at: 50)
        XCTAssertFalse(gate.update(50, at: 0))
        XCTAssertFalse(gate.update(59.9, at: 0.1))
        XCTAssertTrue(gate.update(60, at: 0.2))
        for value in [59.8, 60.2, 59.7, 60.1] {
            XCTAssertFalse(gate.update(value, at: 0.4))
        }
        XCTAssertTrue(gate.update(70, at: 0.5))
        XCTAssertTrue(gate.update(60, at: 0.7))
    }

    func testEndpointsRateLimitAndInvalidValues() {
        var gate = VolumeFeedbackGate()
        gate.reset(at: 96)
        XCTAssertTrue(gate.update(100, at: 0))
        XCTAssertFalse(gate.update(100, at: 1))
        XCTAssertFalse(gate.update(.nan, at: 2))
        XCTAssertFalse(gate.update(0, at: .infinity))
        gate.reset(at: 4)
        XCTAssertTrue(gate.update(0, at: 2))
        XCTAssertFalse(gate.update(50, at: 2.01))
        XCTAssertTrue(gate.update(50, at: 2.1))
    }
}
