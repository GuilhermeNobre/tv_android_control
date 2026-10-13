# Comandos da CLI

Forma geral:

```bash
.venv/bin/python tv.py [--host IP] <comando> [argumentos]
```

`--host` (ou `TV_HOST`) define o IP da TV; padrão `10.0.0.47`.

## Conexão e estado

| Comando | O que faz |
|---|---|
| `pair` | Pareia com a TV (uma vez). Ver [pareamento](pareamento.md). |
| `status` | Mostra `host`, `ligada`, `app_atual`, `volume` e `dispositivo`. |

## Energia

| Comando | O que faz |
|---|---|
| `on` | Liga a TV, **somente se estiver desligada** (consulta `is_on` antes). |
| `off` | Desliga a TV, **somente se estiver ligada**. |
| `power` | Alterna (envia a tecla POWER sem verificar o estado). |
| `screen off` | Apaga a tela (tecla `SLEEP`) mantendo a TV conectada na rede. |
| `screen on` | Acende a tela (tecla `WAKEUP`). |

`on`/`off` são idempotentes: se a TV já está no estado pedido, imprimem
`TV já está ligada.` / `TV já está desligada.` e não fazem nada.

## Teclas

Cada comando envia uma tecla do controle remoto (tabela `KEYS`, ver [código](codigo.md)):

| Grupo | Comandos |
|---|---|
| Volume | `mute`, `volup [N]`, `voldown [N]` (N = repetições, padrão 1) |
| Navegação | `up`, `down`, `left`, `right`, `ok`, `home`, `back`, `menu` |
| Mídia | `play` (play/pause), `next`, `prev` |
| Canais | `ch+`, `ch-` |

Exemplos:

```bash
.venv/bin/python tv.py volup 5
.venv/bin/python tv.py home
```

## Apps, texto e teclas brutas

| Comando | O que faz |
|---|---|
| `app <nome>` | Abre um app. Atalhos: `youtube`, `netflix`, `primevideo`, `disney`, `spotify`, `settings`, `play`. Também aceita link ou pacote (ex.: `app https://www.youtube.com`). |
| `text "abc"` | Digita texto no campo de texto focado na TV. |
| `key KEYCODE` | Envia um `KEYCODE_*` bruto do Android, sem o prefixo `KEY`/`KEYCODE_` (ex.: `key HDMI_1`). |

## Códigos de saída

`0` sucesso; `1` erro de conexão/pareamento (mensagem `Erro: ...` em stderr).
