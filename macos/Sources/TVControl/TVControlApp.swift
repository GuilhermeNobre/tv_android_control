import SwiftUI

@main
struct TVControlApp: App {
    @StateObject private var remote = Remote.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        // Inicia o servidor já no launch, mesmo que a janela ainda não tenha aparecido.
        Task { @MainActor in await Remote.shared.boot() }
    }

    var body: some Scene {
        Window("TV Control", id: "remote") {
            RemoteView(remote: remote)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    remote.shutdown()
                }
        }
        .windowResizability(.contentSize)

        // Popover nativo (material translúcido do sistema) com o mesmo controle da janela.
        MenuBarExtra {
            RemoteView(remote: remote)
            Divider()
            HStack {
                Button("Abrir janela") {
                    openWindow(id: "remote")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .buttonStyle(.link)
            .padding(.horizontal, 16).padding(.vertical, 8)
        } label: {
            Image(systemName: remote.tvOn == true ? "tv.fill" : "tv")
        }
        .menuBarExtraStyle(.window)
    }
}
