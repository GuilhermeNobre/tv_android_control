# Installation

## Requirements

- Python 3.9+ (the code uses `from __future__ import annotations`)
- TV and computer on the same local network
- The TV must be on (or with the screen off) and you must know its IP

## Steps

```bash
cd tv_control
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

The CLI depends on [`androidtvremote2`](https://pypi.org/project/androidtvremote2/) (`>=0.3.2`),
which implements the Android TV Remote v2 protocol. The web server also needs FastAPI and uvicorn;
all of them are listed in `requirements.txt`.

## Setting the TV's IP

The default IP is `10.0.0.47`. To change it:

```bash
# per command
.venv/bin/python tv.py --host 192.168.0.20 status

# or via environment variable
export TV_HOST=192.168.0.20
```

Tip: reserve the TV's IP in your router (DHCP reservation) so the address doesn't change.

Next step: [pairing](pairing.md).
