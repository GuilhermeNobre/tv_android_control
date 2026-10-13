# TV Control — TCL 43P755 (Google TV)

Setup (uma vez):
    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

Pareamento (uma vez): `.venv/bin/python tv.py pair` e digite o código mostrado na TV.
Depois: `.venv/bin/python tv.py power | mute | volup 5 | home | app youtube | status | text "olá"`.

IP padrão 10.0.0.47 (mude com `--host` ou `TV_HOST`). Certificados ficam em `certs/`.
Para novos comandos/apps: edite `KEYS` e `APPS` em `tvcontrol/client.py`.

## Documentação

> A documentação detalhada está em inglês; este README é a versão em português do README principal.

- [Instalação](installation.md)
- [Pareamento](pairing.md)
- [Comandos da CLI](cli.md) (`on`, `off`, `screen on|off`, teclas, apps, texto)
- [Como o protocolo funciona](protocol.md) (portas 6467/6466, certificados)
- [Estrutura do código](code-structure.md)
- [Site / webserver](web-server.md)

## Interface web (celular)

    .venv/bin/pip install -r requirements.txt
    .venv/bin/python server.py            # escuta em 0.0.0.0:8000 (opções: --port, --host, --tv)

Abra `http://<IP-do-computador>:8000` no celular (mesma rede Wi-Fi). **Sem autenticação**: quem estiver na sua rede local controla a TV.

## App para macOS

App nativo (SwiftUI): janela de controle remoto + ícone na barra de menus. Ele inicia o `server.py` sozinho (só em 127.0.0.1) se não estiver rodando.

    macos/build.sh && open macos/build/TVControl.app

Precisa só das Command Line Tools (`xcode-select --install`) e do `.venv` acima. Log do servidor: `~/Library/Logs/TVControl-server.log`.
