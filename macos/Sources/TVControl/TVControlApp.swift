import SwiftUI

@main
struct TVControlApp: App {
    @StateObject private var remote = Remote.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        // Start the server at launch, even before the window has appeared.
        Task { @MainActor in await Remote.shared.boot() }
    }

    var body: some Scene {
        Window("TV Control", id: "remote") {
            RemoteView(remote: remote)
                .background(WindowChrome())
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    remote.shutdown()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Native popover (system translucent material) with the same controls as the window.
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
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Makes the window draggable by its background and title-less, keeping only the system buttons.
private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.isMovableByWindowBackground = true
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.backgroundColor = .windowBackgroundColor
            w.styleMask.insert(.fullSizeContentView)
            w.titlebarSeparatorStyle = .none
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
