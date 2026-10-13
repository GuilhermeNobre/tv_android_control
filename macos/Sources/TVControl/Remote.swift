import Foundation
import SwiftUI

/// State shared between the window and the menu bar popover.
@MainActor
final class Remote: ObservableObject {
    enum Server { case checking, starting, ready, failed(String) }

    static let shared = Remote()

    @Published var server: Server = .checking
    @Published var tvOn: Bool?
    @Published var currentApp: String?
    @Published var apps: [String] = []
    @Published var message: String?
    @Published var volume: TVClient.Volume?
    @Published var deviceName: String?
    @Published var favorites: [String] {
        didSet { UserDefaults.standard.set(favorites, forKey: "favoriteApps") }
    }

    /// Value shown on the slider while the user drags / the TV catches up.
    @Published var volumeDisplay: Int?
    @Published private(set) var volumeBusy = false

    private var volumeTarget: Int?
    private var volumeWorker: Task<Void, Never>?

    private let client = TVClient()
    private let manager = ServerManager()
    private var timer: Timer?

    init() {
        favorites = UserDefaults.standard.stringArray(forKey: "favoriteApps")
            ?? ["youtube", "netflix", "primevideo", "disney"]
    }

    var isReady: Bool { if case .ready = server { return true } else { return false } }

    func boot() async {
        server = .checking
        if await !client.serverIsUp() {
            server = .starting
            if let err = manager.start() { server = .failed(err); return }
            var up = false
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if await client.serverIsUp() { up = true; break }
            }
            guard up else {
                server = .failed("O servidor não subiu. Veja ~/Library/Logs/TVControl-server.log")
                return
            }
        }
        server = .ready
        await refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func shutdown() { manager.stop() }

    func refresh() async {
        do {
            let s = try await client.status()
            tvOn = s.ligada
            currentApp = s.app_atual
            apps = s.apps
            if !volumeBusy { volume = s.volume }
            let parts = [s.dispositivo?.manufacturer, s.dispositivo?.model].compactMap { $0 }
            deviceName = parts.isEmpty ? nil : parts.joined(separator: " ")
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func run(_ op: @escaping () async throws -> Void) {
        Task {
            do { try await op(); message = nil }
            catch { message = error.localizedDescription }
        }
    }

    func key(_ name: String, times: Int = 1) {
        run {
            try await self.client.key(name, times: times)
            if ["volup", "voldown", "mute"].contains(name) {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self.refresh()
            }
        }
    }

    /// Called on every slider movement. The TV only accepts "volume +/-" (no absolute value),
    /// so a single worker steps the volume to the target in batches, one request at a time.
    func setVolume(_ target: Int) {
        volumeDisplay = target
        volumeTarget = target
        volumeBusy = true
        guard volumeWorker == nil else { return }
        volumeWorker = Task { await driveVolume() }
    }

    private func driveVolume() async {
        while let target = volumeTarget, let cur = volume?.level, target != cur {
            let step = min(abs(target - cur), 10)
            let up = target > cur
            do {
                try await client.key(up ? "volup" : "voldown", times: step)
            } catch {
                message = error.localizedDescription
                break
            }
            volume = TVClient.Volume(level: cur + (up ? step : -step), max: volume?.max, muted: false)
        }
        volumeTarget = nil
        volumeWorker = nil
        // Show the TV's real value once the last command has settled.
        try? await Task.sleep(nanoseconds: 500_000_000)
        if volumeTarget == nil && volumeWorker == nil {
            volumeBusy = false
            volumeDisplay = nil
            await refresh()
        }
    }

    func launch(_ app: String) { run { try await self.client.app(app) } }
    func sendText(_ t: String) { run { try await self.client.text(t) } }

    func setPower(_ on: Bool) {
        run {
            try await self.client.power(on)
            self.tvOn = on
        }
    }

    func togglePower() { setPower(!(tvOn ?? false)) }
    func setScreen(_ on: Bool) { run { try await self.client.screen(on) } }

    func toggleFavorite(_ app: String) {
        if let i = favorites.firstIndex(of: app) { favorites.remove(at: i) } else { favorites.append(app) }
    }
}

/// Name and logo of each known app; Android packages → friendly name.
enum AppCatalog {
    enum Glyph {
        case svg(String)       // SVG path (24 viewBox), single color
        case multi(MultiLogo)  // full-color logo with several shapes
        case symbol(String)    // SF Symbol
    }

    struct Info { let title: String; let glyph: Glyph; let tile: Color; let ink: Color }

    static func info(_ id: String) -> Info {
        switch id {
        case "youtube": return Info(title: "YouTube", glyph: .svg(BrandLogos.youtube), tile: .white, ink: Color(red: 1, green: 0, blue: 0))
        case "netflix": return Info(title: "Netflix", glyph: .svg(BrandLogos.netflix), tile: .black, ink: Color(red: 0.9, green: 0.035, blue: 0.078))
        case "primevideo": return Info(title: "Prime Video", glyph: .multi(BrandLogos.primevideo), tile: .white, ink: .black)
        case "disney": return Info(title: "Disney+", glyph: .multi(BrandLogos.disneyplus), tile: .white, ink: .black)
        case "spotify": return Info(title: "Spotify", glyph: .svg(BrandLogos.spotify), tile: Color(red: 0.12, green: 0.84, blue: 0.38), ink: .black)
        case "settings": return Info(title: "Ajustes", glyph: .symbol("gearshape.fill"), tile: Color(white: 0.45), ink: .white)
        case "play": return Info(title: "Play Store", glyph: .svg(BrandLogos.googleplay), tile: .white, ink: Color(red: 0.2, green: 0.66, blue: 0.33))
        default: return Info(title: id.capitalized, glyph: .symbol("app.fill"), tile: .accentColor, ink: .white)
        }
    }

    static func id(forPackage pkg: String?) -> String? {
        switch pkg {
        case "com.google.android.youtube.tv", "com.google.android.youtube.tvunplugged": return "youtube"
        case "com.netflix.ninja": return "netflix"
        case "com.amazon.amazonvideo.livingroom": return "primevideo"
        case "com.disney.disneyplus": return "disney"
        case "com.spotify.tv.android": return "spotify"
        case "com.android.tv.settings", "com.android.settings": return "settings"
        case "com.android.vending": return "play"
        default: return nil
        }
    }

    static func name(forPackage pkg: String?) -> String? {
        guard let pkg, !pkg.isEmpty else { return nil }
        switch pkg {
        case "com.google.android.youtube.tv", "com.google.android.youtube.tvunplugged": return "YouTube"
        case "com.netflix.ninja": return "Netflix"
        case "com.amazon.amazonvideo.livingroom": return "Prime Video"
        case "com.disney.disneyplus": return "Disney+"
        case "com.spotify.tv.android": return "Spotify"
        case "com.android.tv.settings", "com.android.settings": return "Ajustes"
        case "com.android.vending": return "Play Store"
        default:
            if pkg.contains("launcher") { return "Tela inicial" }
            return pkg.split(separator: ".").last.map { String($0).capitalized }
        }
    }
}
