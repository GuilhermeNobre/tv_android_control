# TV Control — TCL 43P755 (Google TV)

Setup (uma vez):
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

Pareamento (uma vez): `.venv/bin/python tv.py pair` e digite o código mostrado na TV.
Depois: `.venv/bin/python tv.py power | mute | volup 5 | home | app youtube | status | text "olá"`.

IP padrão 10.0.0.47 (mude com `--host` ou `TV_HOST`). Certificados ficam em `certs/`.
Para novos comandos/apps: edite `KEYS` e `APPS` em `tvcontrol/client.py`.
