import AppKit

/// Exercises the real panel and its animation, without sending playback commands.
@MainActor
enum AnimationCheck {
    static func run(controller: NotchWindowController, directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var results: [String: Bool] = [:]
        for appearance in IslandAppearance.allCases {
            controller.setAppearanceForCheck(appearance)
            try await Task.sleep(for: .milliseconds(60))
            let destination = directory.appendingPathComponent(appearance.rawValue)
            try await runScenario(controller: controller, directory: destination, appearance: appearance)
            let data = try Data(contentsOf: destination.appendingPathComponent("animations.json"))
            let report = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            results[appearance.rawValue] = report?["allPassed"] as? Bool ?? false
        }
        try JSONSerialization.data(withJSONObject: ["appearances": results, "allPassed": results.values.allSatisfy { $0 }], options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("animations.json"))
    }

    private static func runScenario(controller: NotchWindowController, directory: URL, appearance: IslandAppearance) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var checks: [[String: Any]] = []
        func record(_ name: String, samples: [NSRect], expectedExpanded: Bool) {
            let end = controller.frame
            let topError = samples.map { abs($0.maxY - controller.screenTop) }.max() ?? 0
            checks.append([
                "name": name,
                "sampleCount": samples.count,
                "distinctWidths": Set(samples.map { Int(($0.width * 10).rounded()) }).count,
                "maxTopErrorPoints": topError,
                "width": end.width, "height": end.height,
                "expanded": controller.state.expanded,
                "passed": topError < 1 && controller.state.expanded == expectedExpanded
                    && abs(end.height - (expectedExpanded ? controller.state.topHeight + NotchWindowController.expandedBodyHeight : controller.state.topHeight)) < 1
            ])
        }
        func sample(_ tag: String? = nil) async -> [NSRect] {
            var frames: [NSRect] = []
            var film: [[String: Any]] = []
            for index in 0..<30 {
                frames.append(controller.frame)
                if let tag, index % 2 == 0 {
                    let name = "\(tag)-\(String(format: "%02d", index)).png"
                    try? controller.saveSnapshot(to: directory.appendingPathComponent(name))
                    film.append(["file": name, "width": controller.frame.width, "height": controller.frame.height,
                                 "appearance": appearance.rawValue,
                                 "canvasWidth": controller.state.canvasSize.width, "canvasHeight": controller.state.canvasSize.height])
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
            if let tag {
                try? JSONSerialization.data(withJSONObject: film, options: [.prettyPrinted])
                    .write(to: directory.appendingPathComponent("\(tag)-frames.json"))
            }
            return frames
        }
        controller.show()
        let openFrames = await sample("open")
        record("open", samples: openFrames, expectedExpanded: true)
        try controller.saveSnapshot(to: directory.appendingPathComponent("expanded.png"))
        controller.toggle()
        record("close", samples: await sample("close"), expectedExpanded: false)
        try controller.saveSnapshot(to: directory.appendingPathComponent("compact.png"))
        controller.show()
        try? await Task.sleep(for: .milliseconds(60))
        controller.toggle()
        try? await Task.sleep(for: .milliseconds(60))
        controller.show()
        record("rapid-reversal", samples: await sample(), expectedExpanded: true)
        controller.reducedMotionOverride = true
        controller.toggle()
        record("reduced-motion-close", samples: [controller.frame], expectedExpanded: false)
        controller.show()
        record("reduced-motion-open", samples: [controller.frame], expectedExpanded: true)
        controller.toggle()
        controller.reducedMotionOverride = false
        let inside = NSPoint(x: controller.frame.midX, y: controller.screenTop - 12)
        let outside = NSPoint(x: controller.frame.minX - 100, y: controller.screenTop - 400)
        controller.pointerMoved(to: outside)
        controller.setHoverEnabledForCheck(true)
        for offset in 0..<5 {
            controller.pointerMoved(to: NSPoint(x: inside.x + CGFloat(offset), y: inside.y))
            try? await Task.sleep(for: .milliseconds(30))
        }
        record("hover-camera-opens", samples: await sample(), expectedExpanded: true)
        controller.pointerMoved(to: outside)
        try? await Task.sleep(for: .milliseconds(150))
        controller.pointerMoved(to: inside)
        try? await Task.sleep(for: .milliseconds(600))
        record("hover-reentry-keeps-open", samples: [controller.frame], expectedExpanded: true)
        controller.state.pinned = true
        controller.pointerMoved(to: outside)
        try? await Task.sleep(for: .milliseconds(650))
        record("pinned-stays-open", samples: [controller.frame], expectedExpanded: true)
        controller.state.pinned = false
        controller.pointerMoved(to: inside)
        controller.pointerMoved(to: outside)
        try? await Task.sleep(for: .milliseconds(850))
        record("hover-exit-closes", samples: [controller.frame], expectedExpanded: false)
        controller.setHoverEnabledForCheck(false)
        controller.pointerMoved(to: inside)
        try? await Task.sleep(for: .milliseconds(500))
        record("hover-disabled", samples: [controller.frame], expectedExpanded: false)
        let result: [String: Any] = [
            "checks": checks,
            "hapticRequests": controller.hapticCount,
            "physicalHapticVerified": false,
            "note": "Las llamadas hápticas se ejecutaron; la sensación física requiere un trackpad compatible y confirmación humana.",
            "allPassed": checks.allSatisfy { $0["passed"] as? Bool == true }
        ]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("animations.json"))
    }
}
