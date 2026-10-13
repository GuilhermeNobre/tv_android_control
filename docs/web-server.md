# Web server

A web interface to control the TV from a phone, served by FastAPI (`server.py`) with the static
page in `web/index.html`.

## Starting

```bash
.venv/bin/pip install -r requirements.txt
.venv/bin/python server.py            # default: 0.0.0.0:8000
.venv/bin/python server.py --port 8080 --tv 192.168.0.20
```

Options: `--host` (listen address), `--port`, `--tv` (TV IP). Open
`http://<computer-IP>:8000` on the phone, on the same Wi-Fi network.

## API

| Route | What it does |
|---|---|
| `GET /api/status` | TV state, plus the available `apps` and `keys` lists. |
| `POST /api/key/{name}?times=N` | Sends a key from `KEYS` (N from 1 to 20). |
| `POST /api/power/{on\|off}` | Turns on/off only if the current state differs. |
| `POST /api/screen/{on\|off}` | Screen on/off (`WAKEUP`/`SLEEP`). |
| `POST /api/app/{name}` | Opens an app from `APPS`. |
| `POST /api/text` | Types text (`{"value": "..."}`). |

Errors: `404` for unknown key/app, `409` if the TV isn't paired, `503` if it couldn't connect.

## How it works

The `TV` class keeps **a single connection** to the TV (port 6466) guarded by a lock and
reconnects on demand, retrying once on failure. Commands reuse `Session`, `KEYS`, `APPS` and
`SCREEN` from `tvcontrol/client.py`. Pairing is still done through the CLI (`tv.py pair`) before
using the server.

## Security

**There is no authentication.** Any device on your local network that can reach the port controls
the TV. Do not expose the port to the internet.
