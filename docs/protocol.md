# How the Android TV Remote v2 protocol works

The TV (Google TV / Android TV) exposes a remote-control service on the local network. It is the
same one used by the "Google TV" phone app. This project uses the `androidtvremote2` library,
which implements the protocol; this document explains what happens underneath.

## Two ports, two roles

| Port | Role | When it is used |
|---|---|---|
| **6467** | Pairing | Only in `tv.py pair` |
| **6466** | Remote control | Every command (`Session`) |

Both are TCP connections with **TLS and mutual authentication**: the TV requires a client
certificate, and the client accepts the TV's (self-signed) certificate. Messages are
Protocol Buffers.

## Certificates

- The client generates a `cert.pem` / `key.pem` pair on first run
  (`async_generate_cert_if_missing`), stored in `certs/`.
- **Pairing** is the act of the TV registering that certificate as trusted.
- Whoever holds `key.pem` can control the TV: treat it as a secret.

## Pairing flow (port 6467)

1. The client opens TLS with its certificate and sends the pairing request (client name:
   `TV Control`).
2. The TV shows a 6-character hexadecimal code.
3. The client sends the code; it is validated against a secret derived (SHA-256) from the
   moduli/exponents of both certificates plus the code. Only someone who saw the TV and holds the
   certificates gets it right.
4. Once accepted, the TV stores the client certificate.

## Control flow (port 6466)

1. TLS with the same certificate. If the TV doesn't know it, the connection is refused
   (`InvalidAuth`, translated to `NotPaired`).
2. Configuration/version messages are exchanged; the TV reports its `device_info`.
3. The TV periodically sends **state**: on or off (`is_on`), current app (`current_app`),
   volume (`volume_info`). This is where `status`, `on` and `off` get their data.
4. The client sends commands:
   - **key**: `send_key_command(KEYCODE, direction)` (`SHORT`, `START_LONG`, `END_LONG`)
   - **launch app**: `send_launch_app_command(link_or_package)`
   - **text**: `send_text(str)`
5. Ping/pong keeps the connection alive.

## Notes

- The TV must be in standby with networking active to be turned on by `on`/`power`; in deep
  standby port 6466 may not answer.
- `screen off` sends `SLEEP`: the screen goes dark and the TV stays reachable. `screen on` sends
  `WAKEUP`.
- Key codes are Android's `KEYCODE_*` (`KeyEvent`).
