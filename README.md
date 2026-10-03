# CloudRedirect BR

Conjunto de ferramentas para Steam no Linux, com a **interface do CloudRedirect
em português**.

São três programas que se completam, e **o psyche-BR é o ponto de partida
dos três**:

| | |
|---|---|
| **[psyche-BR](https://github.com/LucianoSkx/psyche-BR)** | Busca pacotes na Hubcap e mescla no `config.yaml` do SLSsteam. É o que prepara depots, chaves e tickets para os outros dois sincronizarem. |
| **[SLSsteam](https://github.com/AceSLS/SLSsteam)** | Modifica o Steamclient para liberar a Steam Cloud em jogos não possuídos, além de tempo de jogo e conquistas. |
| **[CloudRedirect](https://github.com/LucianoSkx/cloudredirect-BR)** | Redireciona o Steam Cloud para um provedor externo (Google Drive, OneDrive, S3, R2 ou uma pasta). É o que faz o save sair da máquina. |

O fluxo é: **psyche-BR** prepara o config → **SLSsteam** engana a Steam Cloud →
**CloudRedirect** leva o save para a nuvem. Tirou um, a cadeia quebra.

Este repositório é fork do
[CloudRedirect](https://github.com/Selectively11/CloudRedirect) via o
[swwayps/cloudredirect-moon](https://github.com/swwayps/cloudredirect-moon). O
que muda aqui:

- **GUI do CloudRedirect em pt-BR** — as 7 abas (Painel, Aplicativos, Backups,
  Provedor de nuvem, Instalação, Estatísticas, Migração), os diálogos, as
  mensagens de estado e as do backend, do deployer e do fluxo OAuth
- **Um instalador** que traz o SLSsteam e o CloudRedirect já configurados entre
  si, com o psyche-BR como companion principal

O ASSella ([niwia/ASSella](https://github.com/niwia/ASSella)) segue como extra
opcional — ver seção **Extra: ASSella** no fim.

O hook em si é o do upstream: um `cloud_redirect.so` de 32 bits, carregado na
Steam via `LD_PRELOAD`. O SLSsteam é quem entra por `LD_AUDIT`.

## Requisitos

- Linux x86_64 com Steam
- distro com `pacman`, `apt`, `dnf` ou `xbps` (as dependências são instaladas pelo
  script; no Debian/Ubuntu inclui `libcurl4:i386`, no Void via `xbps`)
- compilador e Qt6, se for instalar o CloudRedirect — o script compila a GUI

## Instalar

### 1. psyche-BR

Companion principal: busca na Hubcap, importa pacotes Lua/ZIP e mescla no
`config.yaml` do SLSsteam (interface em pt-BR). Detalhes no
[repo](https://github.com/LucianoSkx/psyche-BR):

```sh
# pegue um *-setup.zip em https://github.com/LucianoSkx/psyche-BR/releases,
# extraia e rode:
./install.sh
~/.local/share/psyche/bin/psyche
```

Sem ele o SLSsteam não tem depots, chaves e tickets para sincronizar.

### 2. SLSsteam + CloudRedirect

Esses dois vêm juntos, num instalador só: eles não funcionam separados. Cada um
entra na Steam por um mecanismo próprio — o SLSsteam por `LD_AUDIT`, o
`cloud_redirect.so` por `LD_PRELOAD` — e o CloudRedirect precisa do
`DisableCloud: no` no config do SLSsteam para não ser bloqueado.

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash
```

O que o script faz (modo [h3adcr-b](https://github.com/Deadboy666/h3adcr-b),
com o CloudRedirect desta fork no lugar do flatpak deles):

**1. Cliente Steam** — lê o manifesto instalado e compara com a versão
compatível com o SLSsteam. Se divergir, encerra a Steam e rebaixa o cliente
pelo servidor de depot local (dgsc), e grava o `steam.cfg` com
`BootStrapperInhibitAll=enable` para a Steam não se autoatualizar e quebrar
o hook. O manifesto segue o h3adcr-b: deck (`steamdeck_stable`) no SteamOS e,
no Bazzite/CachyOS, deck quando o `.installed` do deck existe, senão o
`ubuntu12`. Para pular essa trava: `--no-pin-client`.

**2. SLSsteam** — baixa a release oficial do
[AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam) e instala por extração
direta dos binários 32 bits (sem o `setup.sh` oficial, sem wrapper
`path/steam`). O `config.yaml` existente é mesclado com o novo modelo
preservando as suas chaves (backup em `config.yaml.instbackup-*`), e o script
garante `DisableCloud: no`, porque o padrão `yes` do upstream trava o
CloudRedirect. O resto do config segue o h3adcr-b por distro: no SteamOS
`SafeMode: yes`; no CachyOS `SafeMode: no` com `LogLevels: 0x3f`; nas demais
`SafeMode: no` com o bit `NotifyShort` somado ao `LogLevels`. `NotifyInit: yes`
sempre, que é o que faz o SLSsteam avisar que carregou.

**3. CloudRedirect** — compila a interface Qt6 desta fork, instala o
`cloud_redirect.so` e a CLI, e cria a entrada de menu. O `.so` já vem commitado
no repositório, em 32 bits, e a implantação é a mesma que o botão **Instalar** da
aba **Instalação** faz. Com Steam flatpak o `.so` e a CLI são espelhados em
`~/.var/app/com.valvesoftware.Steam/.local/share/CloudRedirect/`, que é o
caminho que o lançador flatpak injeta.

**4. Plugins Lua** — `download.lua` (baixa depots de `AdditionalDepots` e
descriptografa com `DecryptionKeys`) e `spliced-tickets.lua` (compatibilidade
com jogos com Steam DRM). Código de terceiros, fonte anônima; quebram quando o
cliente Steam atualiza.

Só os plugins, sem o resto (sem headcrab, sem reinstalar o SLSsteam):

```sh
# instalar (copia para ~/.config/SLSsteam/plugins/, liga Plugins: yes)
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install-plugins.sh | bash
# remover (apaga só os dois deste repo)
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/uninstall-plugins.sh | bash
# ligar/desligar sem mexer nos arquivos
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/toggle-plugins.sh | bash -s -- off
```

O `steam.sh` é substituído pelo lançador no estilo do h3adcr-b (variante CR):
`GameLauncher` com `CheckClientInfo` por distro, `notify-send` com a versão do
cliente e `export` do `LD_AUDIT` do SLSsteam junto do `LD_PRELOAD` do
`cloud_redirect.so`, com backup em `steam.sh.slssteam.bak` e modo `555`
(`client.sh` com `+x`). Caminhos nativo/flatpak resolvidos por raiz: no flatpak
o `LD_AUDIT` e o `LD_PRELOAD` apontam para dentro de
`~/.var/app/com.valvesoftware.Steam/`. Um patch antigo com marcadores é
migrado, um de outra ferramenta é substituído com aviso.

Depois de instalar, **reinicie a Steam** — `LD_AUDIT` e `LD_PRELOAD` só se
aplicam a processos novos — e abra o CloudRedirect pelo menu.

#### Opções

| Opção | Efeito |
|---|---|
| `--skip-deps` | não instala dependências de sistema |
| `--update-sls` | baixa de novo a última release do SLSsteam mesmo se já existir, sem comparar versão |
| `--no-pin-client` | não trava nem rebaixa o cliente Steam (não recomendado) |
| `--verbose` | mostra a saída de todos os comandos |
| `--help` | mostra a ajuda |

Rodar o instalador de novo atualiza tudo, exceto o SLSsteam quando já
instalado — o script só puxa a última release, sem comparar versão. Para
forçar baixar a mais nova sem apagar `~/.local/share/SLSsteam` manualmente:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash -s -- --update-sls
```

Variáveis de ambiente: `CR_INSTALL_SKIP_DEPS=1`, `CR_UPDATE_SLS=1`,
`CR_PIN_CLIENT=0`, `CR_CLIENT_VER=<build-do-cliente>`, `VERBOSE=1`, `CR_BRANCH`,
`GITHUB_TOKEN` (evita o limite de requisições da API).

## Remover

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/uninstall.sh | bash -s -- --yes
```

Desfaz o `steam.sh` restaurando o `steam.sh.slssteam.bak` (formato antigo com
marcadores também é removido), apaga o `client.sh` do modo h3adcr-b, o
`steam.cfg` — a Steam volta a se atualizar sozinha —, o wrapper, o
`steam.desktop`, o `PATH` do fish, os binários 32 bits, a GUI e as entradas de
menu. Um patch de `LD_AUDIT` de outra ferramenta é preservado: só sai o que este
instalador escreveu.

**Nenhum apaga dados.** Ficam no lugar:

- `~/.config/CloudRedirect/` — config, tokens OAuth, saves, backups e logs
- `~/.config/SLSsteam/config.yaml` — config do SLSsteam
- `~/.local/share/psyche/` — binário, settings e chave Hubcap do psyche-BR

Sem o `--yes` o script pergunta antes; em execução não interativa o `--yes` é
obrigatório.

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

Gerencia manifestos, depots e scripts Lua — alternativa ao psyche-BR para
baixar e instalar jogos que a Steam não reconhece. Não é traduzido aqui nem
reempacotado; o instalador é o do próprio upstream:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
```

Precisa de `libfuse2` funcionando (no Arch, `fuse2`), senão o AppImage não
abre. No Arch há pacote também (`assella-*-x86_64.pkg.tar.zst` nos
[releases](https://github.com/niwia/ASSella)); não passe a URL direto para o
`pacman -U` — o pacote não é assinado e dá erro, baixe antes e instale o
arquivo local. Sai pelo próprio desinstalador:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash -s -- --uninstall
```

Dados em `~/.local/share/ACCELA/` (banco de manifestos, chaves de depot,
logs). O psyche-BR lê a chave Hubcap do ASSella como fallback
(`morrenus_api_key` em `$XDG_CONFIG_HOME/Tachibana Labs/ACCELA.conf`).

## Credits

- [ciscosweater](https://github.com/ciscosweater) — o
  [psyche](https://github.com/ciscosweater/psyche) original, companion que
  prepara o `config.yaml`
- [niwia](https://github.com/niwia) — o [ASSella](https://github.com/niwia/ASSella),
  extra opcional
- [Selectively11](https://github.com/Selectively11) e colaboradores — o
  CloudRedirect original, e o hook que esta fork usa
- [AceSLS](https://github.com/AceSLS/SLSsteam) — o SLSsteam e o `setup.sh` que o
  instalador executa
- [Deadboy666](https://github.com/Deadboy666/h3adcr-b) — o h3adcr-b, de onde vêm
  o travamento do cliente via dgsc, o `client.sh`, o merge do `config.yaml`, o
  ajuste por distro e o formato do lançador `steam.sh`
- [swwayps](https://github.com/swwayps) — o `cloudredirect-moon`, de onde vieram
  o hook de 32 bits e a GUI em Qt6

## Licença

Segue a licença do upstream. Ver [LICENSE](LICENSE).

## Support

Issues: https://github.com/LucianoSkx/cloudredirect-BR/issues
