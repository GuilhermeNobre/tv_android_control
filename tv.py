#!/usr/bin/env python3
"""CLI para controlar a TV TCL 43P755 (Google TV) pela rede local.

Uso:  python tv.py pair | status | screen on|off | power | mute | volup [N] | voldown [N]
      python tv.py up|down|left|right|ok|home|back|menu|play|next|prev
      python tv.py app youtube|netflix|... | text "abc" | key KEYCODE
"""
from __future__ import annotations

import argparse
import asyncio
import sys

from tvcontrol import client
from tvcontrol.client import APPS, KEYS, SCREEN, Session, TVError


async def run(args: argparse.Namespace) -> None:
    host = args.host
    if args.cmd == "pair":
        print(f"Pareando com {host}. Um código de 6 caracteres vai aparecer na TV.")
        await client.pair(host, lambda: input("Código mostrado na TV: ").strip())
        print("Pareado com sucesso.")
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
            # igual ao servidor web (conexão persistente): dá tempo para a TV
            # terminar o handshake antes da tecla e para processá-la antes de fechar
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
        await asyncio.sleep(0.3)  # deixa o comando sair antes de fechar


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
