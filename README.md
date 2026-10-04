# SLSSteamTools-BR

Ferramentas para Steam no Linux, com a GUI em pt-BR. Três partes:

| | |
|---|---|
| **[psyche-BR](https://github.com/LucianoSkx/psyche-BR)** | Busca pacotes na Hubcap e mescla no `config.yaml` do SLSsteam. |
| **[SLSsteam](https://github.com/AceSLS/SLSsteam)** | Libera Steam Cloud, tempo de jogo e conquistas em jogos não possuídos. |
| **[CloudRedirect](https://github.com/LucianoSkx/SLSSteamTools-BR)** | Leva os saves para nuvem externa (Drive, OneDrive, S3, R2, pasta). |

## Instalar

### 1. psyche-BR

Baixe o `*-setup.zip`:

```sh
https://github.com/LucianoSkx/psyche-BR/releases
```

Extraia e rode:

```sh
./install.sh
```

### 2. SLSsteam + CloudRedirect + plugins Lua (obrigatórios)

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/install.sh | bash
```

O passo 2 trava o cliente Steam na versão compatível (via dgsc, modo
[h3adcr-b](https://github.com/Deadboy666/h3adcr-b)), instala o SLSsteam com
`DisableCloud: no`, compila a GUI, injeta `LD_AUDIT`+`LD_PRELOAD` no `steam.sh`
e instala os plugins Lua — `download.lua` e `spliced-tickets.lua` são
**obrigatórios**, sem eles depots extras e jogos com DRM não funcionam.

Reinicie a Steam depois (os hooks só valem para processos novos).

### Plugins: reparar

Instalar:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/install-plugins.sh | bash
```

Remover:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/uninstall-plugins.sh | bash
```

Ligar/desligar:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/toggle-plugins.sh | bash -s -- off
```

Bloquear depots de um jogo (mods que a Steam restauraria):

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/block-depots.sh | bash -s -- list
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/block-depots.sh | bash -s -- block "chrono trigger"
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/block-depots.sh | bash -s -- unblock "chrono trigger"
```

O `block` estaciona as entradas como comentário (o lua ignora, chaves preservadas); `unblock` devolve.

Opções: `--update-sls` (força última release), `--no-pin-client` (não trava o
cliente), `--skip-deps`, `--verbose`.

## Diagnóstico

Coleta logs da Steam, SLSsteam e CloudRedirect, remove dados pessoais e sobe
o pacote pra um paste público (link impresso no terminal). Me manda o link
junto com a issue:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/diagnose.sh | bash
```

Para gerar o tarball local sem subir nada:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/diagnose.sh -o diagnose.sh && DIAG_OUT=~/diag.tar.gz bash diagnose.sh
```

## Remover

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/uninstall.sh | bash -s -- --yes
```

Restaura o `steam.sh` do backup e apaga binários, GUI e entradas de menu.
Dados preservados: `~/.config/CloudRedirect/`, `~/.config/SLSsteam/config.yaml`,
`~/.local/share/psyche/`.

## O que fica onde

| Caminho | Programa | O quê |
|---|---|---|
| `~/.local/share/psyche/` | psyche-BR | binário, `settings.json` (chave Hubcap), runtime Qt |
| `~/.local/share/SLSsteam/` | SLSsteam | `SLSsteam.so`, `library-inject.so` e o wrapper `path/` |
| `~/.config/SLSsteam/config.yaml` | SLSsteam | config, com `DisableCloud: no` |
| `~/.local/share/CloudRedirect/app/` | CloudRedirect | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | CloudRedirect | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | CloudRedirect | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |

O hook só é implantado com o SLSsteam instalado. Se você removeu o SLSsteam, o
CloudRedirect exibe "Não implantado" na aba **Instalação** e o botão
**Instalar** volta a funcionar.

## Compilar o hook de 32 bits

O `cloud_redirect.so` e a CLI já estão commitados no repositório, e é isso que o
instalador usa. Para recompilar, é preciso podman ou docker, porque o build roda
em container glibc-2.35 para casar com o runtime da Steam:

```sh
./build.sh
```

Só a interface (`ui-linux/`) é compilada direto no host, com Qt6.

## Extra: ASSella (opcional)

Alternativa ao psyche-BR para jogos que a Steam não reconhece. Instalador do
próprio upstream (precisa de `libfuse2`; no Arch, `fuse2`):

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash -s -- --uninstall
```

Dados em `~/.local/share/ACCELA/`.

## Credits

- [ciscosweater](https://github.com/ciscosweater) — psyche original
- [niwia](https://github.com/niwia) — ASSella (extra)
- [Selectively11](https://github.com/Selectively11) — CloudRedirect original
- [AceSLS](https://github.com/AceSLS/SLSsteam) — SLSsteam
- [Deadboy666](https://github.com/Deadboy666/h3adcr-b) — h3adcr-b (base do instalador)
- [swwayps](https://github.com/swwayps) — cloudredirect-moon (hook 32 bits, GUI Qt6)

## Licença

Segue a licença do upstream. Ver [LICENSE](LICENSE).

## Support

Issues: https://github.com/LucianoSkx/SLSSteamTools-BR/issues
