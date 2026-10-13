import SwiftUI

private enum Tab: String, CaseIterable, Identifiable {
    case remote = "Controle", apps = "Apps", text = "Texto"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .remote: return "dpad"
        case .apps: return "square.grid.2x2"
        case .text: return "keyboard"
        }
    }
}

// MARK: - Estilos

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Botão de controle: fundo suave, destaque ao passar o mouse e ao pressionar.
private struct PadButton: ButtonStyle {
    var prominent = false
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color.primary.opacity(hover ? 0.14 : 0.08))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .onHover { hover = $0 }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Tela principal

struct RemoteView: View {
    @ObservedObject var remote: Remote
    @State private var tab: Tab = .remote
    @State private var text = ""

    var body: some View {
        VStack(spacing: 12) {
            switch remote.server {
            case .checking, .starting:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Iniciando o servidor…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            case .failed(let msg):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle).foregroundStyle(.orange)
                    Text(msg).font(.callout).multilineTextAlignment(.center)
                    Button("Tentar de novo") { Task { await remote.boot() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            case .ready:
                header
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in Label(t.rawValue, systemImage: t.symbol).tag(t) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch tab {
                case .remote: remoteTab
                case .apps: appsTab
                case .text: textTab
                }

                if let m = remote.message {
                    Label(m, systemImage: "exclamationmark.circle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(statusColor.opacity(0.18))
                Image(systemName: remote.tvOn == true ? "tv.fill" : "tv")
                    .foregroundStyle(statusColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(remote.deviceName ?? "Minha TV").font(.headline).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)

            Menu {
                Button("Atualizar") { Task { await remote.refresh() } }
                Divider()
                Button("Apagar a tela") { remote.setScreen(false) }
                Button("Acender a tela") { remote.setScreen(true) }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()

            Button { remote.togglePower() } label: {
                Image(systemName: "power").font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(remote.tvOn == true ? Color.white : Color.primary)
            .background(Circle().fill(remote.tvOn == true ? Color.green : Color.primary.opacity(0.1)))
            .help("Liga / desliga a TV")
        }
    }

    private var statusColor: Color {
        switch remote.tvOn { case true?: return .green; case false?: return .secondary; case nil: return .orange }
    }

    private var subtitle: String {
        switch remote.tvOn {
        case true?:
            if let app = AppCatalog.name(forPackage: remote.currentApp) { return "Ligada · \(app)" }
            return "Ligada"
        case false?: return "Desligada"
        case nil: return "Sem resposta da TV"
        }
    }

    // MARK: Aba Controle

    private var remoteTab: some View {
        VStack(spacing: 12) {
            volumeCard
            Card {
                VStack(spacing: 14) {
                    dpad
                    HStack(spacing: 8) {
                        round("arrow.uturn.backward", "back", .escape, help: "Voltar (Esc)")
                        round("house", "home", nil, help: "Início")
                        round("line.3.horizontal", "menu", nil, help: "Menu")
                        round("tv.and.mediabox", "input", nil, help: "Trocar entrada (HDMI)")
                    }
                    HStack(spacing: 8) {
                        round("backward.end.fill", "prev", nil, help: "Anterior")
                        round("playpause.fill", "play", .space, help: "Play / pausa")
                        round("forward.end.fill", "next", nil, help: "Próximo")
                    }
                }
            }
            if !favoriteApps.isEmpty {
                HStack(spacing: 8) {
                    ForEach(favoriteApps, id: \.self) { id in appTile(id, compact: true) }
                }
            }
        }
    }

    private var favoriteApps: [String] {
        remote.favorites.filter { remote.apps.contains($0) }.prefix(4).map { $0 }
    }

    private var volumeCard: some View {
        let max = Double(remote.volume?.max ?? 100)
        let level = remote.volumeDisplay ?? remote.volume?.level
        let muted = remote.volume?.muted ?? false
        return Card {
            HStack(spacing: 8) {
                Button { remote.key("mute") } label: {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.fill")
                        .foregroundStyle(muted ? Color.orange : Color.secondary)
                        .frame(width: 22)
                }
                .buttonStyle(.plain).help("Mudo (M)")
                .keyboardShortcut("m", modifiers: [])

                Slider(
                    value: Binding(
                        get: { Double(remote.volumeDisplay ?? remote.volume?.level ?? 0) },
                        set: { remote.setVolume(Int($0.rounded())) }
                    ),
                    in: 0...max, step: 1
                )
                .tint(muted ? .orange : .accentColor)
                .disabled(remote.volume?.level == nil)
                .help("Arraste para ajustar o volume")

                Button { remote.key("voldown") } label: { Image(systemName: "minus").frame(width: 24, height: 22) }
                    .buttonStyle(PadButton()).keyboardShortcut("-", modifiers: []).help("Volume −")
                Button { remote.key("volup") } label: { Image(systemName: "plus").frame(width: 24, height: 22) }
                    .buttonStyle(PadButton()).keyboardShortcut("=", modifiers: []).help("Volume +")

                Text(level.map(String.init) ?? "—")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit().frame(width: 26, alignment: .trailing)
            }
        }
    }

    /// Anel direcional. Arrastar na área também navega (deslizar = seta).
    private var dpad: some View {
        ZStack {
            Circle().fill(.quaternary.opacity(0.8))
            VStack { arrow("chevron.up", "up", .upArrow); Spacer(); arrow("chevron.down", "down", .downArrow) }
                .padding(8)
            HStack { arrow("chevron.left", "left", .leftArrow); Spacer(); arrow("chevron.right", "right", .rightArrow) }
                .padding(8)
            Button { remote.key("ok") } label: {
                Text("OK").font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
        }
        .frame(width: 176, height: 176)
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                if abs(dx) > abs(dy) { remote.key(dx > 0 ? "right" : "left") }
                else { remote.key(dy > 0 ? "down" : "up") }
            }
        )
    }

    private func arrow(_ symbol: String, _ key: String, _ shortcut: KeyEquivalent) -> some View {
        Button { remote.key(key) } label: {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: [])
    }

    private func round(_ symbol: String, _ key: String, _ shortcut: KeyEquivalent?, help: String) -> some View {
        Button { remote.key(key) } label: {
            Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 34)
        }
        .buttonStyle(PadButton())
        .optionalShortcut(shortcut)
        .help(help)
    }

    // MARK: Aba Apps

    private var appsTab: some View {
        Card {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(remote.apps, id: \.self) { id in appTile(id, compact: false) }
            }
            if remote.apps.isEmpty {
                Text("Nenhum app disponível").font(.callout).foregroundStyle(.secondary)
            }
            Text("Clique com o botão direito para fixar nos favoritos.")
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
        }
    }

    private func appTile(_ id: String, compact: Bool) -> some View {
        let info = AppCatalog.info(id)
        let size: CGFloat = compact ? 46 : 54
        return Button { remote.launch(id) } label: {
            VStack(spacing: 6) {
                BrandTile(info: info, size: size)
                Text(info.title).font(.caption2).lineLimit(1).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Abrir \(info.title) na TV")
        .contextMenu {
            Button(remote.favorites.contains(id) ? "Remover dos favoritos" : "Fixar nos favoritos") {
                remote.toggleFavorite(id)
            }
        }
    }

    // MARK: Aba Texto

    private var textTab: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Digitar na TV").font(.subheadline.weight(.semibold))
                HStack {
                    TextField("Digite aqui…", text: $text).textFieldStyle(.roundedBorder).onSubmit(sendText)
                    Button("Enviar", action: sendText).buttonStyle(.borderedProminent).disabled(text.isEmpty)
                }
                Label("Antes, selecione um campo de texto na TV (por exemplo a busca do YouTube).",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func sendText() {
        guard !text.isEmpty else { return }
        remote.sendText(text)
        text = ""
    }
}

private extension View {
    @ViewBuilder func optionalShortcut(_ k: KeyEquivalent?) -> some View {
        if let k { self.keyboardShortcut(k, modifiers: []) } else { self }
    }
}

/// Ícone arredondado do app: fundo da marca + logo.
private struct BrandTile: View {
    let info: AppCatalog.Info
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).fill(info.tile)
            switch info.glyph {
            case .svg(let d):
                SVGShape(d: d).fill(info.ink).frame(width: size * 0.62, height: size * 0.62)
            case .text(let t):
                Text(t).font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                    .foregroundStyle(info.ink).minimumScaleFactor(0.6).lineLimit(1)
                    .padding(.horizontal, 3)
            case .symbol(let s):
                Image(systemName: s).font(.system(size: size * 0.45, weight: .medium)).foregroundStyle(info.ink)
            }
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}
