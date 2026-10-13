# Pairing

Pairing is done **once**. It creates a client certificate that the TV then accepts.

```bash
.venv/bin/python tv.py pair
```

1. The script generates `certs/cert.pem` and `certs/key.pem` (if they don't exist yet).
2. The TV shows a 6-character code.
3. Type the code in the terminal. If it is wrong, the script asks again.
4. Final message: `Pareado com sucesso.` (paired successfully).

After that, every command (`tv.py power`, `tv.py status`, ...) works without pairing again.

## Common problems

| Symptom | Likely cause |
|---|---|
| `TV ainda não pareada. Rode: python tv.py pair` (TV not paired yet) | The TV doesn't recognize the certificate in `certs/`. Pair again. |
| `Não consegui conectar em <ip>` (could not connect) | Wrong IP, TV on another network, or TV fully off (deep standby). |
| `Conexão fechada durante o pareamento` (connection closed during pairing) | The TV closed the channel; run `tv.py pair` again. |

The CLI messages are in Portuguese.

## Re-pairing

Delete `certs/cert.pem` and `certs/key.pem` and run `tv.py pair` again. To also remove the old
device on the TV: Settings → System → Remotes/Accessories.

## Security

`certs/key.pem` is the private key that gives control of the TV to whoever holds it. **Do not
commit** the `certs/` folder (it is already in `.gitignore`).
