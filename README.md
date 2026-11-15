# SLSSteamTools-BR

Ferramentas para Steam no Linux, com a GUI em pt-BR. Três partes:

| | |
|---|---|
| **[ASSella](https://github.com/niwia/ASSella)** | Baixa depots e chaves e instala os plugins Lua no `config.yaml` do SLSsteam. |
| **[SLSsteam](https://github.com/AceSLS/SLSsteam)** | Libera Steam Cloud, tempo de jogo e conquistas em jogos não possuídos. |
| **[CloudRedirect](https://github.com/LucianoSkx/SLSSteamTools-BR)** | Leva os saves para nuvem externa (Drive, OneDrive, S3, R2, pasta). |

## Instalar

### 1. ASSella

Baixa depots, chaves e os plugins Lua que o SLSsteam usa. Instalador do
próprio upstream (precisa de `libfuse2`; no Arch, `fuse2`):

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash -s -- --uninstall
```

Dados em `~/.local/share/ACCELA/`.

### 2. Steam + SLSsteam + CloudRedirect (1 comando)

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/install.sh | bash
```

O script tem três partes:

1. Roda o instalador do [h3adcr-b](https://github.com/Deadboy666/h3adcr-b)
   (`headcrab.pages.dev`). É ele que instala e mantém **Steam e SLSsteam**: pin
   do cliente, `dgsc`, manifestos e o `steam.sh` com `LD_AUDIT` (SLSsteam) +
   `LD_PRELOAD` (CloudRedirect).
2. Instala o **CloudRedirect deste repositório**: `cloud_redirect.so` (com
   `CrashGuard` e `StopWorkers` limitados), a CLI e a UI Qt6 nativa no lugar do
   app flatpak de OAuth do upstream, mais ícones e entrada de menu.
3. Registra o atalho **Headcrab Updater** no menu: abre um terminal e roda o
   instalador do h3adcr-b com a parte de CloudRedirect neutralizada — só Steam
   e SLSsteam, nada de flatpak.

Steam e SLSsteam são do h3adcr-b — se ele mudar, acompanham sozinhos, nada é
duplicado aqui.

Requisitos da parte 2: `curl`, `git`, `cmake` e Qt6 em desenvolvimento (Core,
Quick, QuickControls2, DBus, Network). Só Steam nativa; flatpak não é suportada.

O hook só é carregado quando o SLSsteam está com `DisableCloud: no` no
`~/.config/SLSsteam/config.yaml` (padrão do h3adcr-b).

Os plugins Lua (spacebunny, styx, lobster, lettuce) são baixados e instalados
pelo ASSella, junto com `Plugins: yes` e as seções
`AdditionalDepots:`/`DecryptionKeys:` no `config.yaml` do SLSsteam.

Reinicie a Steam depois (os hooks só valem para processos novos).

### Travar a atualização do cliente (opcional)

O h3adcr-b já trava o cliente na instalação. Para conferir, travar ou destravar
sem rodar o instalador inteiro:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/pin-client.sh | bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/pin-client.sh | bash -s -- status
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/pin-client.sh | bash -s -- unpin
```

`pin` grava `BootStrapperInhibitAll=enable` e `BootStrapperForceSelfUpdate=disable`
em `~/.steam/steam/steam.cfg` (com backup) e compara a versão do cliente com a
build que o h3adcr-b declara para o SLSsteam (lida do script dele em
`headcrab.pages.dev`; offline, cai em `1794424036`). `unpin` remove só essas duas
chaves. Para comparar com outra build, `CR_CLIENT_VERSION=... bash -s -- status`.

Se a Steam ficar presa em "Iniciando a sessão" depois de um update do cliente,
é o pin barrando o handoff: rode `unpin`, abra a Steam para ela concluir o
update e rode `pin` de novo.

### Headcrab Updater: reinstalar ou remover

A entrada já é criada pela instalação (passo 3). Para recriar ou apagar sozinho:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/install-updater.sh | bash
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/install-updater.sh | bash -s -- --remove
```

Depois de rodar o updater, o `headcrab-run.sh` recoloca a linha `INJECT_CR`
(LD_PRELOAD do hook) no `steam.sh`: o upstream hoje só injeta o CloudRedirect
pelo app flatpak, que este repo não usa.

### Plugins: ligar/desligar

Os `.lua` são instalados pelo ASSella. Para desligar (ou religar) todos sem
mexer nos arquivos:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/toggle-plugins.sh | bash -s -- off
```

## Diagnóstico

Coleta logs da Steam, SLSsteam e CloudRedirect, remove dados pessoais e sobe
o pacote pra um paste público (link impresso no terminal). Me manda o link
junto com a issue:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/diagnose.sh | bash
```

Para gerar o tarball local sem subir nada:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/diagnose.sh -o diagnose.sh && DIAG_OUT=~/diag.tar.gz bash diagnose.sh
```

O scrub remove home, usuário, SteamID, e-mail, IPv4, query strings de URL e
cabeçalhos `Authorization`. Minidumps de `/tmp/dumps` são memória do processo e
ficam de fora por padrão; para incluí-los:

```sh
DIAG_INCLUDE_DUMPS=1 DIAG_OUT=~/diag.tar.gz bash diagnose.sh
```

## Remover

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/uninstall.sh | bash -s -- --yes
```

Apaga hook, CLI, UI, ícones e entrada de menu do CloudRedirect. Steam, SLSsteam
e o `steam.sh` não são tocados (são do h3adcr-b).
Dados preservados: `~/.config/CloudRedirect/`, `~/.config/SLSsteam/config.yaml`,
`~/.local/share/ACCELA/`.

## O que fica onde

Linhas de SLSsteam são instaladas pelo h3adcr-b; as de CloudRedirect, por este repo.

| Caminho | Programa | O quê |
|---|---|---|
| `~/.local/share/ACCELA/` | ASSella | AppImage, depots, banco de manifests e plugins Lua |
| `~/.local/share/SLSsteam/` | SLSsteam | `SLSsteam.so`, `library-inject.so` e o wrapper `path/` |
| `~/.config/SLSsteam/config.yaml` | SLSsteam | config, com `DisableCloud: no` |
| `~/.local/share/CloudRedirect/app/` | CloudRedirect | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | CloudRedirect | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | CloudRedirect | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |
| `~/.steam/steam/steam.cfg` | `pin-client.sh` | `BootStrapperInhibitAll` / `BootStrapperForceSelfUpdate` (trava do cliente) |
| `~/.local/share/applications/headcrab.desktop` | Headcrab Updater | atalho que roda o instalador do h3adcr-b |

O hook só é implantado com o SLSsteam instalado. Se você removeu o SLSsteam, o
CloudRedirect exibe "Não implantado" na aba **Instalação** e o botão
**Instalar** volta a funcionar.

## Compilar o hook de 32 bits

O CI compila o `cloud_redirect.so` e a CLI a cada push na `main`, em container
glibc-2.35, e publica na release `latest`. É de lá que o instalador baixa. Para
recompilar localmente, é preciso podman ou docker:

```sh
./build.sh
```

Só a interface (`ui-linux/`) é compilada direto no host, com Qt6.

## Credits

- [niwia](https://github.com/niwia) — ASSella
- [crghofficial](https://github.com/crghofficial/cloudredirect) — CloudRedirect original
- [AceSLS](https://github.com/AceSLS/SLSsteam) — SLSsteam
- [Deadboy666](https://github.com/Deadboy666/h3adcr-b) — h3adcr-b (instala e mantém Steam e SLSsteam; dependência do instalador)

## Licença

Segue a licença do upstream. Ver [LICENSE](LICENSE). Issues em
https://github.com/LucianoSkx/SLSSteamTools-BR/issues.
