# Site / webserver

Interface web para controlar a TV pelo celular, servida por FastAPI (`server.py`) com a página
estática em `web/index.html`.

## Iniciar

```bash
.venv/bin/pip install -r requirements.txt
.venv/bin/python server.py            # padrão: 0.0.0.0:8000
.venv/bin/python server.py --port 8080 --tv 192.168.0.20
```

Opções: `--host` (endereço de escuta), `--port`, `--tv` (IP da TV). Abra
`http://<IP-do-computador>:8000` no celular, na mesma rede Wi-Fi.

## API

| Rota | O que faz |
|---|---|
| `GET /api/status` | Estado da TV, mais listas `apps` e `keys` disponíveis. |
| `POST /api/key/{nome}?times=N` | Envia uma tecla de `KEYS` (N de 1 a 20). |
| `POST /api/power/{on\|off}` | Liga/desliga só se o estado atual for diferente. |
| `POST /api/screen/{on\|off}` | Acende/apaga a tela (`WAKEUP`/`SLEEP`). |
| `POST /api/app/{nome}` | Abre um app de `APPS`. |
| `POST /api/text` | Digita texto (`{"value": "..."}`). |

Erros: `404` para tecla/app desconhecido, `409` se a TV não foi pareada, `503` se não conectou.

## Como funciona

A classe `TV` mantém **uma única conexão** com a TV (porta 6466) protegida por lock e reconecta
sob demanda, com uma nova tentativa em caso de falha. Os comandos reutilizam `Session`,
`KEYS`, `APPS` e `SCREEN` de `tvcontrol/client.py`. O pareamento continua sendo feito pela CLI
(`tv.py pair`) antes de usar o site.

## Segurança

**Não há autenticação.** Qualquer dispositivo na sua rede local que alcance a porta controla a TV.
Não exponha a porta à internet.
