# Code structure

```
tv_control/
├── tv.py                 # CLI (argparse), entry point
├── server.py             # FastAPI web server (see web-server.md)
├── tvcontrol/
│   ├── __init__.py
│   └── client.py         # TV access: KEYS, APPS, SCREEN, Session, pair
├── web/                  # web remote page (index.html)
├── macos/                # native macOS app (SwiftUI, SwiftPM) and build.sh
├── certs/                # cert.pem / key.pem (generated on pairing, git-ignored)
├── requirements.txt
└── docs/                 # this documentation
```

## `tvcontrol/client.py`

The TV access layer; the CLI and the server use only this.

| Item | Description |
|---|---|
| `DEFAULT_HOST` | `TV_HOST` from the environment, or `10.0.0.47`. |
| `CERT_DIR` | `certs/` at the project root. |
| `APPS` | Shortcut → link/package for `send_launch_app_command`. |
| `KEYS` | CLI command → Android `KEY_*` (`power`, `volup`, `ok`, `home`, ...). |
| `SCREEN` | `{"off": "SLEEP", "on": "WAKEUP"}`. |
| `TVError`, `NotPaired` | Errors handled by the CLI. |
| `pair(host, ask_code)` | Pairing flow; `ask_code()` returns the code the user typed. |
| `Session` | Async context manager: `key()`, `app()`, `text()`, `status()`; exposes `remote`. |

Programmatic use:

```python
from tvcontrol.client import Session

async with Session("10.0.0.47") as tv:
    await tv.key("mute")
    await tv.app("youtube")
```

### Adding a key or an app

- **New key:** add `"name": "KEYCODE"` to `KEYS`. The command shows up in the CLI by itself.
- **New app:** add `"name": "link-or-package"` to `APPS`; it becomes an option of `tv.py app name`.
- Any other one-off key: `tv.py key KEYCODE`.

## `tv.py`

- `build_parser()` creates one subcommand per `KEYS` entry, plus `pair`, `status`, `on`, `off`,
  `screen`, `key`, `app`, `text`.
- `run(args)` opens a `Session` and dispatches the command; it waits 0.3 s before closing so the
  command goes out. When `server.py` is running, commands go through it first (see [cli.md](cli.md)).
- `main()` turns `TVError` into `Erro: ...` and exit code 1.

## `server.py`, `web/` and `macos/`

See [web-server.md](web-server.md). The macOS app (`macos/`) is a SwiftUI remote window plus a
menu-bar icon; it starts `server.py` itself (bound to 127.0.0.1 only) when it isn't running.
