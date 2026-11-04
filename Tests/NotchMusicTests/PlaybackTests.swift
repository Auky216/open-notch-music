import XCTest
@testable import NotchMusic

final class PlaybackTests: XCTestCase {
    func testProgressIsBoundedAndPausedDoesNotAdvance() {
        let date = Date(timeIntervalSince1970: 100)
        let playing = PlaybackSnapshot(id: "1", title: "Track", artist: "Artist", album: "Album", artworkURL: nil,
                                       duration: 120, position: 110, isPlaying: true, volume: 50,
                                       shuffle: false, repeatEnabled: false, sampledAt: date)
        XCTAssertEqual(playing.progress(at: date.addingTimeInterval(5)), 115)
        XCTAssertEqual(playing.progress(at: date.addingTimeInterval(50)), 120)
        XCTAssertEqual(playing.progress(at: date.addingTimeInterval(-50)), 110)
        let paused = PlaybackSnapshot(id: "2", title: "Track", artist: "Artist", album: "Album", artworkURL: nil,
                                      duration: 120, position: 30, isPlaying: false, volume: 50,
                                      shuffle: false, repeatEnabled: false, sampledAt: date)
        XCTAssertEqual(paused.progress(at: date.addingTimeInterval(50)), 30)
    }

    func testInvalidCommandValuesNeverEnterAppleScript() {
        XCTAssertEqual(PlaybackCommand.seek(.nan).script, "set player position to 0.0")
        XCTAssertEqual(PlaybackCommand.seek(-5).script, "set player position to 0.0")
        XCTAssertEqual(PlaybackCommand.volume(.infinity).script, "set sound volume to 0")
        XCTAssertEqual(PlaybackCommand.volume(200).script, "set sound volume to 100")
        XCTAssertEqual(PlaybackCommand.volume(44.999999999).script, PlaybackCommand.volume(45).script)
        XCTAssertEqual(PlaybackCommand.volume(-1).script, "set sound volume to 0")
    }

    func testVolumeCompensatesOnlyTheOnePointSpotifyDiscrepancy() {
        let script = PlaybackCommand.volume(45).script
        XCTAssertTrue(script.contains("if sound volume is 44 then\n    set sound volume to 46"))
        XCTAssertTrue(script.contains("repeat 6 times"))
        XCTAssertEqual(PlaybackCommand.volume(100).script, "set sound volume to 100")
        XCTAssertEqual(PlaybackCommand.volume(0).script, "set sound volume to 0")
    }

    func testTimeLabelsHandleInvalidAndNegativeValues() {
        XCTAssertEqual(timeLabel(61.9), "1:01")
        XCTAssertEqual(timeLabel(-5), "0:00")
        XCTAssertEqual(timeLabel(.nan), "0:00")
    }
}
