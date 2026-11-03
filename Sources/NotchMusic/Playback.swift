import Foundation

struct PlaybackSnapshot: Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let duration: Double
    var position: Double
    let isPlaying: Bool
    let volume: Double
    let shuffle: Bool
    let repeatEnabled: Bool
    var sampledAt = Date()

    func progress(at date: Date) -> Double {
        let elapsed = isPlaying ? max(0, date.timeIntervalSince(sampledAt)) : 0
        return min(max(0, duration), max(0, position + elapsed))
    }

    static let demo = PlaybackSnapshot(
        id: "demo", title: "Un momento para escuchar", artist: "Notch Music",
        album: "Vista de demostración", artworkURL: nil,
        duration: 218, position: 67, isPlaying: true, volume: 65,
        shuffle: false, repeatEnabled: false
    )
}

enum PlaybackCommand: Sendable {
    case toggle, next, previous, seek(Double), volume(Double), shuffle(Bool), repeating(Bool)

    var script: String {
        switch self {
        case .toggle: return "playpause"
        case .next: return "next track"
        case .previous: return "previous track"
        case .seek(let seconds): return "set player position to \(Self.number(seconds, upper: 86400))"
        case .volume(let volume): return "set sound volume to \(Int(Self.number(volume, upper: 100)))"
        case .shuffle(let value): return "set shuffling to \(value ? "true" : "false")"
        case .repeating(let value): return "set repeating to \(value ? "true" : "false")"
        }
    }

    private static func number(_ value: Double, upper: Double) -> Double {
        value.isFinite ? min(upper, max(0, value)) : 0
    }
}

enum SpotifyError: LocalizedError {
    case notRunning, noTrack, permission, failed(String)
    var errorDescription: String? {
        switch self {
        case .notRunning: return "Abre Spotify para empezar a escuchar."
        case .noTrack: return "Elige una canción en Spotify."
        case .permission: return "Permite el acceso a Spotify en Ajustes del Sistema → Privacidad y seguridad → Automatización."
        case .failed(let text): return text
        }
    }
}

protocol MusicProvider: AnyObject {
    func read() async throws -> PlaybackSnapshot
    func send(_ command: PlaybackCommand) async throws
}

/// A single queue preserves command order and keeps Apple Events off the UI thread.
final class SpotifyProvider: MusicProvider, @unchecked Sendable {
    private let queue = DispatchQueue(label: "music.notch.spotify", qos: .utility)

    func read() async throws -> PlaybackSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.execute("""
                    set t to current track
                    if t is missing value then return {"empty"}
                    return {id of t, name of t, artist of t, album of t, artwork url of t, duration of t, player position, (player state as string), sound volume, shuffling, repeating}
                    """)
                    guard result.numberOfItems == 11 else { throw SpotifyError.noTrack }
                    func item(_ index: Int) -> NSAppleEventDescriptor? { result.atIndex(index) }
                    func string(_ index: Int) -> String { item(index)?.stringValue ?? "" }
                    func number(_ index: Int) -> Double { item(index)?.doubleValue ?? 0 }
                    // Spotify's desktop implementation reports milliseconds despite its sdef description.
                    let duration = max(0, number(6) / 1000)
                    let position = min(duration, max(0, number(7)))
                    let artwork = URL(string: string(5)).flatMap { $0.scheme == "https" ? $0 : nil }
                    continuation.resume(returning: PlaybackSnapshot(
                        id: string(1), title: string(2), artist: string(3), album: string(4),
                        artworkURL: artwork, duration: duration, position: position,
                        isPlaying: string(8) == "playing", volume: number(9),
                        shuffle: item(10)?.booleanValue ?? false,
                        repeatEnabled: item(11)?.booleanValue ?? false
                    ))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func send(_ command: PlaybackCommand) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    _ = try self.execute(command.script)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func execute(_ body: String) throws -> NSAppleEventDescriptor {
        let source = """
        with timeout of 4 seconds
            if application id "com.spotify.client" is not running then error "Spotify is closed" number -600
            tell application id "com.spotify.client"
                \(body)
            end tell
        end timeout
        """
        guard let script = NSAppleScript(source: source) else { throw SpotifyError.failed("No se pudo preparar la conexión a Spotify.") }
        var details: NSDictionary?
        let result = script.executeAndReturnError(&details)
        if let details {
            if CommandLine.arguments.contains("--debug") { NSLog("Spotify Apple Event: %@", details) }
            let code = details[NSAppleScript.errorNumber] as? Int ?? 0
            switch code {
            case -1743, -1744: throw SpotifyError.permission
            case -600: throw SpotifyError.notRunning
            case -1728: throw SpotifyError.noTrack
            case -1712: throw SpotifyError.failed("Spotify no respondió. Vuelve a intentarlo.")
            default: throw SpotifyError.failed("No se pudo conectar con Spotify (\(code)).")
            }
        }
        return result
    }
}

func timeLabel(_ seconds: Double) -> String {
    let value = seconds.isFinite ? Int(min(86400, max(0, seconds))) : 0
    return String(format: "%d:%02d", value / 60, value % 60)
}
