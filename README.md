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

O passo 2 é um port fiel do instalador
[h3adcr-b](https://github.com/Deadboy666/h3adcr-b) — mesma ordem de etapas, mesmo
pin do cliente Steam (`1791918634`, via dgsc), mesmos manifestos e o mesmo
launcher `steam.sh` com `LD_AUDIT` (SLSsteam) + `LD_PRELOAD` (CloudRedirect).

A única diferença é o CloudRedirect: em vez do `.so` da release h3adcr-b e do
app flatpak de OAuth, usa o `cloud_redirect.so` deste repositório (com
`CrashGuard` e `StopWorkers` limitados) e a UI Qt6 nativa dele para o login.

Também instala o SLSsteam mais recente direto do upstream, grava
`~/.local/share/SLSsteam/version` (usado pelo ASSella), garante
`DisableCloud: no` / `NotifyInit: yes` / `Plugins: yes` no `config.yaml` e instala
os plugins Lua — `download.lua` e `spliced-tickets.lua` são **obrigatórios**,
sem eles depots extras e jogos com DRM não funcionam.

Cria também a entrada **Headcrab Updater** no menu, que roda este mesmo
instalador (não o do h3adcr-b), pra reatualizar o cliente depois.

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
- [Deadboy666](https://github.com/Deadboy666/h3adcr-b) — h3adcr-b (base do instalador, port fiel)

## Licença

Segue a licença do upstream. Ver [LICENSE](LICENSE).

## Support

Issues: https://github.com/LucianoSkx/SLSSteamTools-BR/issues
