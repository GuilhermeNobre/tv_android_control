# Instalação

## Requisitos

- Python 3.9+ (usa `from __future__ import annotations`)
- TV e computador na mesma rede local
- A TV precisa estar ligada (ou com a tela apagada) e com o IP conhecido

## Passos

```bash
cd tv_control
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

A única dependência é [`androidtvremote2`](https://pypi.org/project/androidtvremote2/) (`>=0.3.2`),
que implementa o protocolo Android TV Remote v2.

## Configurando o IP da TV

O IP padrão é `10.0.0.47`. Para mudar:

```bash
# por comando
.venv/bin/python tv.py --host 192.168.0.20 status

# ou por variável de ambiente
export TV_HOST=192.168.0.20
```

Dica: fixe o IP da TV no roteador (reserva DHCP) para o endereço não mudar.

Próximo passo: [pareamento](pareamento.md).
