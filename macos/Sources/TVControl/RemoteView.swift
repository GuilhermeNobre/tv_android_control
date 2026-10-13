import SwiftUI

private enum Tab: String, CaseIterable, Identifiable {
    case remote = "Controle", apps = "Apps", text = "Texto"
    var id: String { rawValue }
    var order: Int { Tab.allCases.firstIndex(of: self) ?? 0 }
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
    /// Espaço extra no topo para os botões da janela (semáforos) quando não há barra de título.
    var topInset: CGFloat = 0
    // `-initialTab apps|texto` na linha de comando abre direto numa aba (útil para testes).
    @State private var tab: Tab = Tab.allCases.first {
        $0.rawValue.lowercased() == UserDefaults.standard.string(forKey: "initialTab")?.lowercased()
    } ?? .remote
    @State private var text = ""
    @State private var slide: CGFloat = 1

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
                Picker("", selection: Binding(
                    get: { tab },
                    set: { new in
                        slide = new.order > tab.order ? 1 : -1
                        withAnimation(.easeInOut(duration: 0.28)) { tab = new }
                    }
                )) {
                    ForEach(Tab.allCases) { t in Label(t.rawValue, systemImage: t.symbol).tag(t) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                ZStack {
                    switch tab {
                    case .remote: remoteTab.transition(slideTransition)
                    case .apps: appsTab.transition(slideTransition)
                    case .text: textTab.transition(slideTransition)
                    }
                }

                if let m = remote.message {
                    Label(m, systemImage: "exclamationmark.circle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 16 + topInset)
        .frame(width: 320)
        .background(alignment: .top) {
            // Brilho suave no topo: azul quando a TV está ligada, quase neutro quando desligada.
            LinearGradient(colors: [Color.accentColor.opacity(remote.tvOn == true ? 0.20 : 0.05), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 220)
                .animation(.easeInOut(duration: 0.6), value: remote.tvOn)
        }
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: 36 * slide).combined(with: .opacity),
            removal: .offset(x: -36 * slide).combined(with: .opacity)
        )
    }

    // MARK: Cabeçalho

    private var header: some View {
        VStack(spacing: 12) {
            TVPreview(isOn: remote.tvOn, appId: AppCatalog.id(forPackage: remote.currentApp),
                      appName: AppCatalog.name(forPackage: remote.currentApp))
                .frame(height: 112)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(remote.deviceName ?? "Minha TV").font(.headline).lineLimit(1)
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
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
                    Image(systemName: "power").font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(remote.tvOn == true ? Color.white : Color.primary)
                .background(Circle().fill(remote.tvOn == true ? Color.green : Color.primary.opacity(0.1)))
                .animation(.easeInOut(duration: 0.3), value: remote.tvOn)
                .help("Liga / desliga a TV")
            }
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
                        set: { new in
                            let n = Int(new.rounded())
                            if n != (remote.volumeDisplay ?? remote.volume?.level) { remote.setVolume(n) }
                        }
                    ),
                    in: 0...max
                )
                .tint(muted ? .orange : .accentColor)
                .disabled(remote.volume?.level == nil)
                .help("Arraste para ajustar o volume")

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
        let rows = stride(from: 0, to: remote.apps.count, by: 3).map {
            Array(remote.apps[$0..<min($0 + 3, remote.apps.count)])
        }
        return VStack(spacing: 10) {
            Card {
                if remote.apps.isEmpty {
                    Text("Nenhum app disponível").font(.callout).foregroundStyle(.secondary)
                } else {
                    // Linhas fixas (não LazyVGrid) para a altura ser calculada de uma vez.
                    VStack(spacing: 14) {
                        ForEach(rows.indices, id: \.self) { r in
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(rows[r], id: \.self) { id in appTile(id, compact: false) }
                                ForEach(0..<(3 - rows[r].count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                                }
                            }
                        }
                    }
                }
            }
            Text("Clique com o botão direito num app para fixar nos favoritos.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
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
            case .multi(let logo):
                MultiLogoView(logo: logo).frame(width: size * 0.82, height: size * 0.5)
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

/// TV pequena: tela acesa com o app atual, ou preta quando desligada.
private struct TVPreview: View {
    let isOn: Bool?
    let appId: String?
    let appName: String?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(white: 0.08))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(screen)
                    .padding(5)
                content.padding(5)
                // reflexo
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(isOn == true ? 0.16 : 0.08), .clear],
                                         startPoint: .topLeading, endPoint: .center))
                    .padding(5)
                    .allowsHitTesting(false)
            }
            .frame(width: 148, height: 84)
            .shadow(color: (isOn == true ? Color.accentColor : .black).opacity(0.35), radius: 12, y: 4)

            // pé da TV
            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.25)).frame(width: 38, height: 5).padding(.top, 3)
        }
        .animation(.easeInOut(duration: 0.45), value: isOn)
        .animation(.easeInOut(duration: 0.35), value: appId)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOn == true ? "TV ligada" : isOn == false ? "TV desligada" : "TV sem resposta")
    }

    private var screen: AnyShapeStyle {
        switch isOn {
        case true?:
            let base = appId.map { AppCatalog.info($0).tile } ?? Color.accentColor
            let c = base == .white || base == .black ? Color.accentColor : base
            return AnyShapeStyle(LinearGradient(colors: [c.opacity(0.95), c.opacity(0.55)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(Color.black)
        }
    }

    @ViewBuilder private var content: some View {
        switch isOn {
        case true?:
            VStack(spacing: 4) {
                if let id = appId { BrandTile(info: AppCatalog.info(id), size: 34) }
                else { Image(systemName: "house.fill").font(.title2).foregroundStyle(.white.opacity(0.9)) }
                Text(appName ?? "Ligada").font(.caption2.weight(.medium)).foregroundStyle(.white).lineLimit(1)
            }
            .transition(.opacity)
        case false?:
            Image(systemName: "power").font(.title3).foregroundStyle(.white.opacity(0.18)).transition(.opacity)
        case nil:
            Image(systemName: "wifi.exclamationmark").font(.title3).foregroundStyle(.orange.opacity(0.8)).transition(.opacity)
        }
    }
}
