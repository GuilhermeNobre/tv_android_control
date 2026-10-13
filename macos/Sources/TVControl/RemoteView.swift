import SwiftUI

struct RemoteView: View {
    @ObservedObject var remote: Remote
    @State private var text = ""

    var body: some View {
        VStack(spacing: 14) {
            switch remote.server {
            case .checking, .starting:
                ProgressView(remote.isReady ? "" : "Iniciando o servidor…").padding(40)
            case .failed(let msg):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                    Text(msg).multilineTextAlignment(.center).frame(maxWidth: 260)
                    Button("Tentar de novo") { Task { await remote.boot() } }
                }.padding(20)
            case .ready:
                controls
            }
        }
        .padding(18)
        .frame(width: 300)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { remote.togglePower() } label: { Image(systemName: "power") }
                    .tint(remote.tvOn == true ? .red : .green)
                    .help("Liga / desliga a TV")
            }

            // D-pad
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow { Color.clear; key("chevron.up", "up", .upArrow); Color.clear }
                GridRow {
                    key("chevron.left", "left", .leftArrow)
                    Button("OK") { remote.key("ok") }
                        .keyboardShortcut(.return, modifiers: [])
                        .controlSize(.large)
                    key("chevron.right", "right", .rightArrow)
                }
                GridRow { Color.clear; key("chevron.down", "down", .downArrow); Color.clear }
            }

            HStack {
                key("arrow.uturn.backward", "back", .escape, help: "Voltar (Esc)")
                key("house", "home", nil, help: "Início")
                key("line.3.horizontal", "menu", nil, help: "Menu")
            }

            HStack {
                key("speaker.minus", "voldown", .init("-"), help: "Volume −")
                key("speaker.slash", "mute", .init("m"), help: "Mudo")
                key("speaker.plus", "volup", .init("="), help: "Volume +")
            }

            HStack {
                key("backward.end", "prev", nil)
                key("playpause", "play", .space, help: "Play / pausa")
                key("forward.end", "next", nil)
            }

            HStack {
                Button("CH −") { remote.key("ch-") }
                Button("CH +") { remote.key("ch+") }
            }

            if !remote.apps.isEmpty {
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                    ForEach(remote.apps, id: \.self) { a in
                        Button(a.capitalized) { remote.launch(a) }.frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()
            HStack {
                TextField("Digitar na TV…", text: $text)
                    .onSubmit(sendText)
                Button("Enviar", action: sendText).disabled(text.isEmpty)
            }

            if let m = remote.message {
                Text(m).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
    }

    private func key(_ symbol: String, _ name: String, _ shortcut: KeyEquivalent?, help: String? = nil) -> some View {
        Button { remote.key(name) } label: {
            Image(systemName: symbol).frame(width: 34, height: 24)
        }
        .optionalShortcut(shortcut)
        .help(help ?? name)
    }

    private func sendText() {
        guard !text.isEmpty else { return }
        remote.sendText(text)
        text = ""
    }

    private var color: Color {
        switch remote.tvOn { case true?: return .green; case false?: return .gray; case nil: return .orange }
    }

    private var statusText: String {
        switch remote.tvOn {
        case true?: return "TV ligada" + (remote.currentApp.map { " · \($0)" } ?? "")
        case false?: return "TV desligada"
        case nil: return "Sem resposta da TV"
        }
    }
}

private extension View {
    @ViewBuilder func optionalShortcut(_ k: KeyEquivalent?) -> some View {
        if let k { self.keyboardShortcut(k, modifiers: []) } else { self }
    }
}
