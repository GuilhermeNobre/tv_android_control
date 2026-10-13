# CLI commands

General form:

```bash
.venv/bin/python tv.py [--host IP] <command> [arguments]
```

`--host` (or `TV_HOST`) sets the TV's IP; default `10.0.0.47`.

## Connection and state

| Command | What it does |
|---|---|
| `pair` | Pairs with the TV (once). See [pairing](pairing.md). |
| `status` | Shows `host`, `ligada` (on), `app_atual` (current app), `volume` and `dispositivo` (device). |

## Power

| Command | What it does |
|---|---|
| `on` | Turns the TV on, **only if it is off** (checks `is_on` first). |
| `off` | Turns the TV off, **only if it is on**. |
| `power` | Toggles (sends the POWER key without checking state). |
| `screen off` | Turns the screen off (`SLEEP` key) while keeping the TV connected to the network. |
| `screen on` | Turns the screen on (`WAKEUP` key). |

`on`/`off` are idempotent: if the TV is already in the requested state they print
`TV já está ligada.` / `TV já está desligada.` ("TV is already on/off") and do nothing.

## Keys

Each command sends a remote-control key (the `KEYS` table, see [code structure](code-structure.md)):

| Group | Commands |
|---|---|
| Volume | `mute`, `volup [N]`, `voldown [N]` (N = repetitions, default 1) |
| Navigation | `up`, `down`, `left`, `right`, `ok`, `home`, `back`, `menu` |
| Media | `play` (play/pause), `next`, `prev` |
| Channels | `ch+`, `ch-` |

Examples:

```bash
.venv/bin/python tv.py volup 5
.venv/bin/python tv.py home
```

## Apps, text and raw keys

| Command | What it does |
|---|---|
| `app <name>` | Opens an app. Shortcuts: `youtube`, `netflix`, `primevideo`, `disney`, `spotify`, `settings`, `play`. Also accepts a link or package (e.g. `app https://www.youtube.com`). |
| `text "abc"` | Types text into the text field focused on the TV. |
| `key KEYCODE` | Sends a raw Android `KEYCODE_*` without the `KEY`/`KEYCODE_` prefix (e.g. `key HDMI_1`). |

## Exit codes

`0` success; `1` connection/pairing error (`Erro: ...` message on stderr).

## When the server is running

If `server.py` is running (port 8000, or `TV_SERVER=http://host:port`), the CLI sends commands
through it instead of opening another connection. The TV only handles one remote at a time well:
with the server connected, a direct CLI connection was ignored (which is why `screen`/`power`
"were not sent"). Without the server, the CLI connects directly to the TV. `key KEYCODE` and
arbitrary app links always use the direct connection.
