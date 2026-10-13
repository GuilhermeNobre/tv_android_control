import Foundation
import SwiftUI

/// Estado compartilhado entre a janela e o popover da barra de menus.
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
            volume = s.volume
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

/// Nome, ícone e cor de cada app conhecido; pacotes Android → nome amigável.
enum AppCatalog {
    struct Info { let title: String; let symbol: String; let color: Color }

    static func info(_ id: String) -> Info {
        switch id {
        case "youtube": return Info(title: "YouTube", symbol: "play.rectangle.fill", color: .red)
        case "netflix": return Info(title: "Netflix", symbol: "n.square.fill", color: Color(red: 0.9, green: 0.04, blue: 0.08))
        case "primevideo": return Info(title: "Prime Video", symbol: "play.tv.fill", color: Color(red: 0.0, green: 0.66, blue: 0.88))
        case "disney": return Info(title: "Disney+", symbol: "sparkles.tv.fill", color: Color(red: 0.07, green: 0.2, blue: 0.55))
        case "spotify": return Info(title: "Spotify", symbol: "music.note", color: Color(red: 0.12, green: 0.73, blue: 0.33))
        case "settings": return Info(title: "Ajustes", symbol: "gearshape.fill", color: .gray)
        case "play": return Info(title: "Play Store", symbol: "bag.fill", color: .green)
        default: return Info(title: id.capitalized, symbol: "app.fill", color: .accentColor)
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
