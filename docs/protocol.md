# Como o protocolo Android TV Remote v2 funciona

A TV (Google TV / Android TV) expõe um serviço de controle remoto na rede local. É o mesmo usado
pelo app "Google TV" no celular. O projeto usa a biblioteca `androidtvremote2`, que implementa o
protocolo; este documento explica o que acontece por baixo.

## Duas portas, dois papéis

| Porta | Função | Quando é usada |
|---|---|---|
| **6467** | Pareamento | Só em `tv.py pair` |
| **6466** | Controle remoto | Em todo comando (`Session`) |

Ambas são conexões TCP com **TLS e autenticação mútua**: a TV exige um certificado de cliente, e o
cliente aceita o certificado (autoassinado) da TV. As mensagens trafegam como Protocol Buffers.

## Certificados

- O cliente gera um par `cert.pem` / `key.pem` na primeira execução
  (`async_generate_cert_if_missing`), salvo em `certs/`.
- O **pareamento** é o ato de a TV registrar esse certificado como confiável.
- Quem possui `key.pem` pode controlar a TV: trate como segredo.

## Fluxo de pareamento (porta 6467)

1. O cliente abre TLS com seu certificado e envia o pedido de pareamento (nome do cliente: `TV Control`).
2. A TV mostra um código de 6 caracteres hexadecimais.
3. O cliente envia o código; ele é validado por um *secret* derivado (SHA‑256) dos módulos/expoentes
   dos dois certificados mais o código. Só quem viu a TV e conhece os certificados acerta.
4. Aceito, a TV guarda o certificado do cliente.

## Fluxo de controle (porta 6466)

1. TLS com o mesmo certificado. Se a TV não o conhece, a conexão é recusada (`InvalidAuth`,
   traduzido para `NotPaired`).
2. Troca de mensagens de configuração/versão; a TV informa `device_info`.
3. A TV envia periodicamente **estado**: ligada ou não (`is_on`), app atual (`current_app`),
   volume (`volume_info`). É daí que vêm `status`, `on` e `off`.
4. O cliente envia comandos:
   - **tecla**: `send_key_command(KEYCODE, direction)` (`SHORT`, `START_LONG`, `END_LONG`)
   - **abrir app**: `send_launch_app_command(link_ou_pacote)`
   - **texto**: `send_text(str)`
5. Há *ping/pong* para manter a conexão viva.

## Observações

- A TV precisa estar em standby com rede ativa para ligar por `on`/`power`; em standby profundo a
  porta 6466 pode não responder.
- `screen off` envia `SLEEP`: a tela apaga e a TV segue acessível. `screen on` envia `WAKEUP`.
- Os códigos de tecla são os `KEYCODE_*` do Android (`KeyEvent`).
