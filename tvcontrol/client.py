"""Camada de acesso à TV (Android TV Remote v2). A CLI usa só isto."""
from __future__ import annotations

import os
from pathlib import Path

from androidtvremote2 import (
    AndroidTVRemote,
    CannotConnect,
    ConnectionClosed,
    InvalidAuth,
)

DEFAULT_HOST = os.environ.get("TV_HOST", "10.0.0.47")
CERT_DIR = Path(__file__).resolve().parent.parent / "certs"
CLIENT_NAME = "TV Control"

# Atalhos de apps (nome -> link/pacote aceito por send_launch_app_command)
APPS = {
    "youtube": "https://www.youtube.com",
    "netflix": "https://www.netflix.com/title",
    "primevideo": "https://app.primevideo.com",
    "disney": "https://www.disneyplus.com",
    "spotify": "spotify://",
    "settings": "android-app://com.android.tv.settings",
    "play": "market://launch?id=com.google.android.youtube.tv",
}

# Comando da CLI -> KEY_* do Android
KEYS = {
    "power": "POWER",
    "mute": "MUTE",
    "volup": "VOLUME_UP",
    "voldown": "VOLUME_DOWN",
    "up": "DPAD_UP",
    "down": "DPAD_DOWN",
    "left": "DPAD_LEFT",
    "right": "DPAD_RIGHT",
    "ok": "DPAD_CENTER",
    "home": "HOME",
    "back": "BACK",
    "menu": "MENU",
    "input": "TV_INPUT",
    "play": "MEDIA_PLAY_PAUSE",
    "next": "MEDIA_NEXT",
    "prev": "MEDIA_PREVIOUS",
    "ch+": "CHANNEL_UP",
    "ch-": "CHANNEL_DOWN",
}


# `tv.py screen on|off`: apaga/acende a tela mantendo a TV acessível na rede
SCREEN = {"off": "SLEEP", "on": "WAKEUP"}


class TVError(Exception):
    pass


class NotPaired(TVError):
    pass


def _paths() -> tuple[str, str]:
    CERT_DIR.mkdir(exist_ok=True)
    return str(CERT_DIR / "cert.pem"), str(CERT_DIR / "key.pem")


def _remote(host: str) -> AndroidTVRemote:
    cert, key = _paths()
    return AndroidTVRemote(CLIENT_NAME, cert, key, host)


async def pair(host: str, ask_code) -> None:
    """Pareamento: a TV mostra um código; `ask_code()` devolve o que o usuário digitou."""
    r = _remote(host)
    await r.async_generate_cert_if_missing()
    await r.async_start_pairing()
    while True:
        code = ask_code()
        try:
            if await r.async_finish_pairing(code):
                return
        except InvalidAuth:
            print("Código incorreto, tente de novo.")
        except ConnectionClosed as e:
            raise TVError(f"Conexão fechada durante o pareamento: {e}")


class Session:
    """Conexão assíncrona: `async with Session(host) as tv: await tv.key("mute")`."""

    def __init__(self, host: str = DEFAULT_HOST):
        self.host = host
        self.remote = _remote(host)

    async def __aenter__(self) -> "Session":
        await self.remote.async_generate_cert_if_missing()
        try:
            await self.remote.async_connect()
        except InvalidAuth:
            raise NotPaired("TV ainda não pareada. Rode: python tv.py pair")
        except (CannotConnect, ConnectionClosed, OSError) as e:
            raise TVError(f"Não consegui conectar em {self.host}: {e}")
        return self

    async def __aexit__(self, *exc) -> None:
        self.remote.disconnect()

    async def key(self, name: str, direction: str = "SHORT") -> None:
        self.remote.send_key_command(KEYS.get(name, name.upper()), direction)

    async def app(self, name: str) -> None:
        self.remote.send_launch_app_command(APPS.get(name, name))

    async def text(self, s: str) -> None:
        self.remote.send_text(s)

    def status(self) -> dict:
        r = self.remote
        return {
            "host": self.host,
            "ligada": r.is_on,
            "app_atual": r.current_app,
            "volume": r.volume_info,
            "dispositivo": r.device_info,
        }
