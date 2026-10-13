#!/usr/bin/env python3
"""CLI to control the TCL 43P755 TV (Google TV) over the local network.

Usage: python tv.py pair | status | screen on|off | power | mute | volup [N] | voldown [N]
      python tv.py up|down|left|right|ok|home|back|menu|play|next|prev
      python tv.py app youtube|netflix|... | text "abc" | key KEYCODE
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import urllib.error
import urllib.request

from tvcontrol import client
from tvcontrol.client import APPS, KEYS, SCREEN, Session, TVError


SERVER_URL = os.environ.get("TV_SERVER", "http://127.0.0.1:8000")


def via_server(args: argparse.Namespace) -> bool:
    """If server.py is running, sends the command through it and returns True.

    The TV only serves ONE remote at a time: with server.py connected, a second
    direct connection from the CLI is ignored. So the CLI uses the server when it exists.
    """
    c = args.cmd
    if c == "screen":
        path, body = f"/api/screen/{args.state}", None
    elif c in ("on", "off"):
        path, body = f"/api/power/{c}", None
    elif c in KEYS:
        path, body = f"/api/key/{c}?times={getattr(args, 'times', 1)}", None
    elif c == "app" and args.name in APPS:
        path, body = f"/api/app/{args.name}", None
    elif c == "text":
        path, body = "/api/text", {"value": args.value}
    elif c == "status":
        path, body = "/api/status", None
    else:
        return False
    method = "GET" if c == "status" else "POST"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(SERVER_URL + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            out = json.load(r)
    except urllib.error.HTTPError as e:
        try:
            detail = json.load(e).get("detail", e.reason)
        except Exception:
            detail = e.reason
        raise TVError(f"servidor respondeu {e.code}: {detail}")
    except OSError:
        return False  # server is down: connect directly
    if c == "status":
        for k in ("host", "ligada", "app_atual", "volume", "dispositivo"):
            print(f"{k}: {out.get(k)}")
    elif c in ("on", "off"):
        print(f"TV {'ligada' if out.get('ligada') else 'desligada'}.")
    return True


async def run(args: argparse.Namespace) -> None:
    host = args.host
    if args.cmd == "pair":
        print(f"Pareando com {host}. Um código de 6 caracteres vai aparecer na TV.")
        await client.pair(host, lambda: input("Código mostrado na TV: ").strip())
        print("Pareado com sucesso.")
        return

    if args.host == client.DEFAULT_HOST and via_server(args):
        return

    async with Session(host) as tv:
        if args.cmd == "status":
            for k, v in tv.status().items():
                print(f"{k}: {v}")
        elif args.cmd in ("on", "off"):
            want = args.cmd == "on"
            if tv.remote.is_on == want:
                print(f"TV já está {'ligada' if want else 'desligada'}.")
            else:
                await tv.key("power")
        elif args.cmd == "screen":
            # same as the web server (persistent connection): give the TV time to
            # finish the handshake before the key and to process it before closing
            await asyncio.sleep(0.5)
            await tv.key(SCREEN[args.state])
            await asyncio.sleep(1.5)
        elif args.cmd in KEYS:
            n = getattr(args, "times", 1)
            for _ in range(n):
                await tv.key(args.cmd)
                await asyncio.sleep(0.15)
        elif args.cmd == "key":
            await tv.key(args.code)
        elif args.cmd == "app":
            await tv.app(args.name)
        elif args.cmd == "text":
            await tv.text(args.value)
        await asyncio.sleep(0.3)  # let the command go out before closing


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Controle da TV TCL (Android TV Remote)")
    p.add_argument("--host", default=client.DEFAULT_HOST, help="IP da TV (env TV_HOST)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("pair", help="parear com a TV (uma vez)")
    sub.add_parser("status", help="mostrar estado da TV")
    sp = sub.add_parser("screen", help="apagar/acender a tela, mantendo a TV conectada")
    sp.add_argument("state", choices=list(SCREEN))
    sub.add_parser("on", help="ligar (só se estiver desligada)")
    sub.add_parser("off", help="desligar (só se estiver ligada)")
    for name in KEYS:
        sp = sub.add_parser(name, help=f"tecla {name}")
        if name in ("volup", "voldown"):
            sp.add_argument("times", nargs="?", type=int, default=1)
    sp = sub.add_parser("key", help="enviar KEYCODE bruto (ex: HDMI_1)")
    sp.add_argument("code")
    sp = sub.add_parser("app", help="abrir app: " + ", ".join(APPS) + " ou link/pacote")
    sp.add_argument("name")
    sp = sub.add_parser("text", help="digitar texto no campo focado")
    sp.add_argument("value")
    return p


def main() -> int:
    args = build_parser().parse_args()
    try:
        asyncio.run(run(args))
    except TVError as e:
        print(f"Erro: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
