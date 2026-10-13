#!/usr/bin/env python3
"""Web server for the TV remote control (FastAPI).

Usage: .venv/bin/python server.py [--host 0.0.0.0] [--port 8000] [--tv 10.0.0.47]
WARNING: no authentication - anyone on your local network can control the TV.
"""
from __future__ import annotations

import argparse
import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

from tvcontrol import client
from tvcontrol.client import APPS, KEYS, SCREEN, NotPaired, Session, TVError

log = logging.getLogger("uvicorn.error")
WEB_DIR = Path(__file__).resolve().parent / "web"


class TV:
    """Keeps a single connection and reconnects on demand."""

    def __init__(self, host: str):
        self.host = host
        self._session: Session | None = None
        self._lock = asyncio.Lock()

    async def _connect(self) -> Session:
        if self._session is None:
            s = Session(self.host)
            await s.__aenter__()
            self._session = s
        return self._session

    async def _drop(self) -> None:
        s, self._session = self._session, None
        if s:
            try:
                await s.__aexit__(None, None, None)
            except Exception:
                pass

    async def call(self, fn):
        """Runs fn(session); on a connection failure, reconnects and retries once."""
        async with self._lock:
            for attempt in (1, 2):
                try:
                    s = await self._connect()
                    return await fn(s)
                except NotPaired:
                    raise
                except Exception as e:
                    await self._drop()
                    if attempt == 2:
                        raise TVError(str(e)) from e

    async def close(self) -> None:
        async with self._lock:
            await self._drop()


tv: TV


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield
    await tv.close()


app = FastAPI(title="TV Control", lifespan=lifespan)


async def _run(fn):
    try:
        return await tv.call(fn)
    except NotPaired as e:
        raise HTTPException(409, str(e))
    except TVError as e:
        raise HTTPException(503, str(e))


async def _after(s: Session, coro):
    await coro
    await asyncio.sleep(0.2)  # let the command go out
    return {"ok": True}


@app.get("/api/status")
async def status():
    return await _run(lambda s: _status(s))


async def _status(s: Session):
    return {**s.status(), "apps": list(APPS), "keys": list(KEYS)}


@app.post("/api/key/{name}")
async def key(name: str, times: int = 1):
    if name not in KEYS:
        raise HTTPException(404, f"tecla desconhecida: {name}")
    times = max(1, min(times, 20))

    async def go(s: Session):
        for _ in range(times):
            await s.key(name)
            await asyncio.sleep(0.12)
        return {"ok": True}

    return await _run(go)


@app.post("/api/power/{state}")
async def power(state: str):
    if state not in ("on", "off"):
        raise HTTPException(404, "use on ou off")

    async def go(s: Session):
        if s.remote.is_on != (state == "on"):
            await s.key("power")
        return {"ok": True, "ligada": state == "on"}

    return await _run(go)


@app.post("/api/screen/{state}")
async def screen(state: str):
    if state not in SCREEN:
        raise HTTPException(404, "use on ou off")
    return await _run(lambda s: _after(s, s.key(SCREEN[state])))


@app.post("/api/app/{name}")
async def launch(name: str):
    if name not in APPS:
        raise HTTPException(404, f"app desconhecido: {name}")
    return await _run(lambda s: _after(s, s.app(name)))


class Text(BaseModel):
    value: str


@app.post("/api/text")
async def text(body: Text):
    async def go(s: Session):
        r = s.remote
        proto = getattr(r, "_remote_message_protocol", None)
        log.info("text: ime_counter=%s field_counter=%s app=%s",
                 getattr(proto, "ime_counter", "?"), getattr(proto, "ime_field_counter", "?"), r.current_app)
        return await _after(s, s.text(body.value))

    return await _run(go)


@app.get("/")
async def index():
    return FileResponse(WEB_DIR / "index.html")


def main() -> None:
    global tv
    p = argparse.ArgumentParser(description="Servidor web do controle da TV")
    p.add_argument("--host", default="0.0.0.0", help="interface onde escutar (padrão: rede local)")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--tv", default=client.DEFAULT_HOST, help="IP da TV (env TV_HOST)")
    a = p.parse_args()
    tv = TV(a.tv)
    print(f"Controle da TV {a.tv} em http://{a.host}:{a.port}  (SEM autenticação)")
    uvicorn.run(app, host=a.host, port=a.port, log_level="info")


if __name__ == "__main__":
    main()
