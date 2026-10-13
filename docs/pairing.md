# Pareamento

O pareamento é feito **uma única vez**. Ele cria um certificado de cliente que a TV passa a aceitar.

```bash
.venv/bin/python tv.py pair
```

1. O script gera `certs/cert.pem` e `certs/key.pem` (se ainda não existirem).
2. A TV exibe um código de 6 caracteres.
3. Digite o código no terminal. Se estiver errado, o script pede de novo.
4. Mensagem final: `Pareado com sucesso.`

Depois disso, qualquer comando (`tv.py power`, `tv.py status`, ...) funciona sem novo pareamento.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| `TV ainda não pareada. Rode: python tv.py pair` | A TV não reconhece o certificado em `certs/`. Pareie de novo. |
| `Não consegui conectar em <ip>` | IP errado, TV em outra rede, ou TV totalmente desligada (modo standby profundo). |
| `Conexão fechada durante o pareamento` | A TV fechou o canal; repita `tv.py pair`. |

## Re-parear

Apague `certs/cert.pem` e `certs/key.pem` e rode `tv.py pair` novamente. Se também quiser
remover o dispositivo na TV: Configurações → Sistema → Controle remoto/Acessórios.

## Segurança

`certs/key.pem` é a chave privada que dá controle da TV a quem a possuir. **Não versione** a pasta
`certs/` (ela já está no `.gitignore`).
