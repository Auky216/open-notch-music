import AppKit
import SwiftUI
import XCTest
@testable import NotchMusic

final class OverlayTests: XCTestCase {
    @MainActor func testFloatingSetupRetainsFullScreenOverlayLevel() async {
        _ = NSApplication.shared
        let panel = NotchPanel.makeOverlay()
        XCTAssertEqual(panel.level, NotchPanel.overlayLevel)
        XCTAssertGreaterThan(panel.level.rawValue, NSWindow.Level.mainMenu.rawValue)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllApplications))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(panel.hidesOnDeactivate)
        panel.close()
    }

    func testIslandRemainsOneContinuousContourDuringExpansion() {
        for fraction in [0.0, 0.02, 0.1, 0.3, 0.6, 1.0] {
            let width = 321 + (480 - 321) * fraction
            let height = 38 + 214 * fraction
            let path = NotchShape().path(in: CGRect(x: 0, y: 0, width: width, height: height))
            var contours = 0
            path.cgPath.applyWithBlock { element in
                if element.pointee.type == .moveToPoint { contours += 1 }
            }
            XCTAssertEqual(contours, 1)
            XCTAssertTrue(path.contains(CGPoint(x: width / 2, y: 18)))
            // The opened island covers the underlying menu items instead of letting them shine through.
            if fraction > 0 { XCTAssertTrue(path.contains(CGPoint(x: 35, y: 20))) }
            XCTAssertFalse(path.contains(CGPoint(x: 1, y: height - 1)))
        }
    }
}
