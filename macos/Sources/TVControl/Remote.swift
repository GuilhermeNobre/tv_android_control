import Foundation
import SwiftUI

/// Estado compartilhado entre a janela e o ícone da barra de menus.
@MainActor
final class Remote: ObservableObject {
    enum Server { case checking, starting, ready, failed(String) }

    static let shared = Remote()

    @Published var server: Server = .checking
    @Published var tvOn: Bool?
    @Published var currentApp: String?
    @Published var apps: [String] = []
    @Published var message: String?

    private let client = TVClient()
    private let manager = ServerManager()
    private var timer: Timer?

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

    func key(_ name: String, times: Int = 1) { run { try await self.client.key(name, times: times) } }
    func launch(_ app: String) { run { try await self.client.app(app) } }
    func sendText(_ t: String) { run { try await self.client.text(t) } }

    func setPower(_ on: Bool) {
        run {
            try await self.client.power(on)
            self.tvOn = on
        }
    }

    func togglePower() { setPower(!(tvOn ?? false)) }
}
