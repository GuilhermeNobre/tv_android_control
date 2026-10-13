# TV Control — TCL 43P755 (Google TV)

Setup (uma vez):
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

Pareamento (uma vez): `.venv/bin/python tv.py pair` e digite o código mostrado na TV.
Depois: `.venv/bin/python tv.py power | mute | volup 5 | home | app youtube | status | text "olá"`.

IP padrão 10.0.0.47 (mude com `--host` ou `TV_HOST`). Certificados ficam em `certs/`.
Para novos comandos/apps: edite `KEYS` e `APPS` em `tvcontrol/client.py`.

## Documentação

- [Instalação](docs/instalacao.md)
- [Pareamento](docs/pareamento.md)
- [Comandos da CLI](docs/cli.md) (`on`, `off`, `screen on|off`, teclas, apps, texto)
- [Como o protocolo funciona](docs/protocolo.md) (portas 6467/6466, certificados)
- [Estrutura do código](docs/codigo.md)
- [Site / webserver](docs/site.md) (reservado)

## Interface web (celular)

    .venv/bin/pip install -r requirements.txt
    .venv/bin/python server.py            # escuta em 0.0.0.0:8000 (opções: --port, --host, --tv)

Abra `http://<IP-do-computador>:8000` no celular (mesma rede Wi-Fi). **Sem autenticação**: quem estiver na sua rede local controla a TV.
