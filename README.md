# TV Control — TCL 43P755 (Google TV)

Local control of a TCL 43P755 (Google TV) over the Android TV Remote v2 protocol: CLI, web
interface and native macOS app.

> 🇧🇷 Versão em português: [docs/README.pt-BR.md](docs/README.pt-BR.md)

Setup (once):

    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

Pairing (once): `.venv/bin/python tv.py pair` and type the code shown on the TV.
Then: `.venv/bin/python tv.py power | mute | volup 5 | home | app youtube | status | text "hello"`.

Default IP is 10.0.0.47 (change it with `--host` or `TV_HOST`). Certificates live in `certs/`.
For new commands/apps: edit `KEYS` and `APPS` in `tvcontrol/client.py`.

## Documentation

- [Installation](docs/installation.md)
- [Pairing](docs/pairing.md)
- [CLI commands](docs/cli.md) (`on`, `off`, `screen on|off`, keys, apps, text)
- [How the protocol works](docs/protocol.md) (ports 6467/6466, certificates)
- [Code structure](docs/code-structure.md)
- [Web server](docs/web-server.md)

## Web interface (phone)

    .venv/bin/pip install -r requirements.txt
    .venv/bin/python server.py            # listens on 0.0.0.0:8000 (options: --port, --host, --tv)

Open `http://<computer-IP>:8000` on your phone (same Wi-Fi network). **No authentication**: anyone
on your local network can control the TV.

## macOS app

Native app (SwiftUI): remote-control window plus a menu-bar icon. It starts `server.py` by itself
(on 127.0.0.1 only) if it isn't running.

    macos/build.sh && open macos/build/TVControl.app

Needs only the Command Line Tools (`xcode-select --install`) and the `.venv` above. Server log:
`~/Library/Logs/TVControl-server.log`.

Logos dos apps: [Simple Icons](https://simpleicons.org) v13.21.0 (CC0); as marcas pertencem aos seus donos e são usadas só para identificar cada app. Prime Video e Disney+ não estão nessa biblioteca: usam os logotipos em SVG do Wikimedia Commons (logotipos em texto, sem proteção autoral nos EUA; marcas registradas dos donos). O ícone do app é desenhado em código (`macos/icon/make-icon.swift`) e gerado pelo `build.sh`.
