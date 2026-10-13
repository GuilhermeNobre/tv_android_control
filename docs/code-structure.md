# Estrutura do código

```
tv_control/
├── tv.py                 # CLI (argparse) — ponto de entrada
├── tvcontrol/
│   ├── __init__.py
│   └── client.py         # acesso à TV: KEYS, APPS, SCREEN, Session, pair
├── certs/                # cert.pem / key.pem (gerados no pareamento)
├── requirements.txt      # androidtvremote2>=0.3.2
└── docs/                 # esta documentação
```

## `tvcontrol/client.py`

Camada de acesso à TV; a CLI usa só isto.

| Item | Descrição |
|---|---|
| `DEFAULT_HOST` | `TV_HOST` do ambiente, ou `10.0.0.47`. |
| `CERT_DIR` | `certs/` na raiz do projeto. |
| `APPS` | Atalho → link/pacote para `send_launch_app_command`. |
| `KEYS` | Comando da CLI → `KEY_*` do Android (`power`, `volup`, `ok`, `home`, ...). |
| `SCREEN` | `{"off": "SLEEP", "on": "WAKEUP"}`. |
| `TVError`, `NotPaired` | Erros tratados pela CLI. |
| `pair(host, ask_code)` | Fluxo de pareamento; `ask_code()` devolve o código digitado. |
| `Session` | Context manager assíncrono: `key()`, `app()`, `text()`, `status()`; expõe `remote`. |

Uso programático:

```python
from tvcontrol.client import Session

async with Session("10.0.0.47") as tv:
    await tv.key("mute")
    await tv.app("youtube")
```

### Adicionar uma tecla ou app

- **Tecla nova:** adicione `"nome": "KEYCODE"` em `KEYS`. O comando aparece sozinho na CLI.
- **App novo:** adicione `"nome": "link-ou-pacote"` em `APPS`; vira opção de `tv.py app nome`.
- Qualquer outra tecla pontual: `tv.py key KEYCODE`.

## `tv.py`

- `build_parser()` cria um subcomando por entrada de `KEYS`, mais `pair`, `status`, `on`, `off`,
  `screen`, `key`, `app`, `text`.
- `run(args)` abre uma `Session` e despacha o comando; espera 0,3 s antes de fechar para o comando sair.
- `main()` converte `TVError` em `Erro: ...` + código de saída 1.
