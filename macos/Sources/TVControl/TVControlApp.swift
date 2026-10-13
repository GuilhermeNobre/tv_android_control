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

        MenuBarExtra("TV Control", systemImage: "tv") {
            Button(remote.tvOn == true ? "Desligar TV" : "Ligar TV") { remote.togglePower() }
            Divider()
            Button("Volume +") { remote.key("volup") }
            Button("Volume −") { remote.key("voldown") }
            Button("Mudo") { remote.key("mute") }
            Divider()
            Button("Início") { remote.key("home") }
            Button("Voltar") { remote.key("back") }
            Menu("Abrir app") {
                ForEach(remote.apps, id: \.self) { a in
                    Button(a.capitalized) { remote.launch(a) }
                }
            }
            Divider()
            Button("Mostrar controle remoto") {
                openWindow(id: "remote")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Sair") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
