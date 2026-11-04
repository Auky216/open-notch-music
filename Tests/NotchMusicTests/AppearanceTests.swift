import AppKit
import XCTest
@testable import NotchMusic

final class AppearanceTests: XCTestCase {
    @MainActor func testAppearanceAndBarsPersistIndependentlyWithSafeDefaults() async {
        let suite = "NotchMusic.AppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.appearance, .normal)
        XCTAssertEqual(settings.visualizerColor, .white)
        settings.appearance = .liquidGlass
        settings.visualizerColor = .album
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.appearance, .liquidGlass)
        XCTAssertEqual(restored.visualizerColor, .album)
        restored.appearance = .albumGradient
        XCTAssertEqual(restored.visualizerColor, .album)
        defaults.set("unknown", forKey: "islandAppearance")
        defaults.set("unknown", forKey: "visualizerColor")
        let fallback = SettingsStore(defaults: defaults)
        XCTAssertEqual(fallback.appearance, .normal)
        XCTAssertEqual(fallback.visualizerColor, .white)
    }

    @MainActor func testPalettePreservesArtworkHueAndBrightensDarkArt() async {
        func sample(_ color: NSColor) -> ArtworkPalette {
            let image = NSImage(size: CGSize(width: 64, height: 64))
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 64, height: 64).fill()
            color.setFill()
            NSRect(x: 0, y: 0, width: 48, height: 64).fill()
            image.unlockFocus()
            return ArtworkPalette.extract(from: image)
        }
        let red = sample(NSColor(srgbRed: 0.5, green: 0.03, blue: 0.03, alpha: 1))
        let blue = sample(NSColor(srgbRed: 0.02, green: 0.02, blue: 0.18, alpha: 1))
        XCTAssertLessThan(red.background.hueComponent, 0.05)
        XCTAssertEqual(blue.background.hueComponent, 2.0 / 3, accuracy: 0.04)
        XCTAssertGreaterThanOrEqual(blue.background.brightnessComponent, 0.57)
        XCTAssertGreaterThan(blue.accent.brightnessComponent, 0.9)
        let neutral = sample(.black)
        XCTAssertLessThan(neutral.background.saturationComponent, 0.01)
        XCTAssertLessThan(neutral.accent.saturationComponent, 0.01)
    }
}
