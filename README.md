# CloudRedirect BR

Conjunto de ferramentas para Steam no Linux, com a **interface do CloudRedirect
em português**.

São três programas que se completam, e **o ASSella é o ponto de partida dos
três**:

| | |
|---|---|
| **[ASSella](https://github.com/niwia/ASSella)** | Gerencia manifestos, depots e scripts Lua. É o que permite baixar e instalar jogos que a Steam não reconhece. Sem ele os outros dois não têm o que sincronizar. |
| **[SLSsteam](https://github.com/AceSLS/SLSsteam)** | Modifica o Steamclient para liberar a Steam Cloud em jogos não possuídos, além de tempo de jogo e conquistas. |
| **[CloudRedirect](https://github.com/LucianoSkx/cloudredirect-BR)** | Redireciona o Steam Cloud para um provedor externo (Google Drive, OneDrive, S3, R2 ou uma pasta). É o que faz o save sair da máquina. |

O fluxo é: **ASSella** libera o jogo → **SLSsteam** engana a Steam Cloud →
**CloudRedirect** leva o save para a nuvem. Tirou um, a cadeia quebra.

Este repositório é fork do
[CloudRedirect](https://github.com/Selectively11/CloudRedirect) via o
[swwayps/cloudredirect-moon](https://github.com/swwayps/cloudredirect-moon). O
que muda aqui:

- **GUI do CloudRedirect em pt-BR** — as 7 abas (Painel, Aplicativos, Backups,
  Provedor de nuvem, Instalação, Estatísticas, Migração), os diálogos, as
  mensagens de estado e as do backend, do deployer e do fluxo OAuth
- **Um instalador** que traz o SLSsteam e o CloudRedirect já configurados entre
  si, e deixa o link do instalador do ASSella logo ao lado

O ASSella não é traduzido aqui nem reempacotado — ele mantém o instalador
próprio, e o README aponta para ele.

O hook em si é o do upstream: um `cloud_redirect.so` de 32 bits, carregado na
Steam via `LD_PRELOAD`. O SLSsteam é quem entra por `LD_AUDIT`.

## Requisitos

- Linux x86_64 com Steam
- distro com `pacman`, `apt` ou `dnf` (as dependências são instaladas pelo
  script)
- compilador e Qt6, se for instalar o CloudRedirect — o script compila a GUI
- `libfuse2` (no Arch, `fuse2`) para o AppImage do ASSella

## Instalar

### 1. ASSella

O instalador é o do próprio upstream — este repositório não o reempacota, para
que o caminho, a versão e o `.desktop` se mantenham em dia junto com o app:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
```

Baixa o AppImage, cria a entrada de menu e o ícone. Precisa de `libfuse2`
funcionando, senão o AppImage não abre.

O app sai em inglês. A tradução pt-BR que existia era de um fork que foi
deletado, e não foi reconstruída aqui.

### 2. SLSsteam + CloudRedirect

Esses dois vêm juntos, num instalador só: eles não funcionam separados. O
CloudRedirect implanta o hook na Steam pelo `LD_AUDIT` que o SLSsteam instala, e
precisa do `DisableCloud: no` no config do SLSsteam para não ser bloqueado.

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash
```

O que o script faz:

**1. SLSsteam** — baixa a release oficial do
[AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam) e roda o `setup.sh` de
dentro do pacote, que copia os binários 32 bits, cria o wrapper `path/steam` e o
`steam.desktop` com o `LD_AUDIT`. O script injeta o `LD_AUDIT` também no
`steam.sh`, porque o `setup.sh` oficial não mexe nele e quem chama a Steam
digitando `steam` não passa nem pelo wrapper nem pelo `.desktop`. O `steam.sh`
vai com backup em `steam.sh.slssteam.bak` e com o modo `555` original.

O `config.yaml` do SLSsteam fica com `DisableCloud: no`, porque o padrão `yes` do
upstream trava o CloudRedirect.

**2. CloudRedirect** — compila a interface Qt6 desta fork, instala o
`cloud_redirect.so` e a CLI, e cria a entrada de menu. O `.so` já vem commitado
no repositório, em 32 bits, e a implantação é a mesma que o botão **Instalar** da
aba **Instalação** faz.

Depois de instalar, **reinicie a Steam** — o `LD_AUDIT` só se aplica a processos
novos — e abra o CloudRedirect pelo menu.

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash
```

SLSsteam e CloudRedirect vêm juntos, num instalador só: eles não funcionam
separados. O CloudRedirect implanta o hook na Steam pelo `LD_AUDIT` que o
SLSsteam instala, e precisa do `DisableCloud: no` no config do SLSsteam para não
ser bloqueado.

O que o script faz:

**1. SLSsteam** — baixa a release oficial do
[AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam) e roda o `setup.sh` de
dentro do pacote, que copia os binários 32 bits, cria o wrapper `path/steam` e o
`steam.desktop` com o `LD_AUDIT`. O script injeta o `LD_AUDIT` também no
`steam.sh`, porque o `setup.sh` oficial não mexe nele e quem chama a Steam
digitando `steam` não passa nem pelo wrapper nem pelo `.desktop`. O `steam.sh`
vai com backup em `steam.sh.slssteam.bak` e com o modo `555` original.

O `config.yaml` do SLSsteam fica com `DisableCloud: no`, porque o padrão `yes` do
upstream trava o CloudRedirect.

**2. CloudRedirect** — compila a interface Qt6 desta fork, instala o
`cloud_redirect.so` e a CLI, e cria a entrada de menu. O `.so` já vem commitado
no repositório, em 32 bits, e a implantação é a mesma que o botão **Instalar** da
aba **Instalação** faz.

Depois de instalar, **reinicie a Steam** — o `LD_AUDIT` só se aplica a processos
novos — e abra o CloudRedirect pelo menu.

#### Opções

| Opção | Efeito |
|---|---|
| `--skip-deps` | não instala dependências de sistema |
| `--verbose` | mostra a saída de todos os comandos |
| `--help` | mostra a ajuda |

Rodar o instalador de novo atualiza tudo.

Variáveis de ambiente: `CR_INSTALL_SKIP_DEPS=1`, `VERBOSE=1`, `CR_BRANCH`,
`GITHUB_TOKEN` (evita o limite de requisições da API).

## Remover

O ASSella sai pelo próprio desinstalador do upstream:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash -s -- --uninstall
```

Para o par SLSsteam + CloudRedirect:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/uninstall.sh | bash -s -- --yes
```

Desfaz o patch do `steam.sh` devolvendo-o byte a byte e apaga o wrapper, o
`steam.desktop`, o `PATH` do fish, os binários 32 bits, a GUI e as entradas de
menu. Um patch de `LD_AUDIT` de outra ferramenta é preservado: só sai o que este
instalador escreveu.

**Nenhum dos três apaga dados.** Ficam no lugar:

- `~/.local/share/ACCELA/` — banco de manifestos, chaves de depot, logs
- `~/.config/CloudRedirect/` — config, tokens OAuth, saves, backups e logs
- `~/.config/SLSsteam/config.yaml` — config do SLSsteam

Sem o `--yes` o script pergunta antes; em execução não interativa o `--yes` é
obrigatório.

## O que fica onde

| Caminho | Programa | O quê |
|---|---|---|
| `~/.local/share/ACCELA/` | ASSella | AppImage, banco de manifestos, chaves de depot, `manifests/`, `tor_data/` |
| `~/.local/share/SLSsteam/` | SLSsteam | `SLSsteam.so`, `library-inject.so` e o wrapper `path/` |
| `~/.config/SLSsteam/config.yaml` | SLSsteam | config, com `DisableCloud: no` |
| `~/.local/share/CloudRedirect/app/` | CloudRedirect | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | CloudRedirect | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | CloudRedirect | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |

O nome `ACCELA` (1 L) é o que o código do ASSella usa. Se os seus dados
estiverem em `ACCELLA` (2 L), mova a pasta — o app não acha o outro nome.

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

## Credits

- [niwia](https://github.com/niwia) — o [ASSella](https://github.com/niwia/ASSella),
  que abre os manifestos e depots
- [Selectively11](https://github.com/Selectively11) e colaboradores — o
  CloudRedirect original, e o hook que esta fork usa
- [AceSLS](https://github.com/AceSLS/SLSsteam) — o SLSsteam e o `setup.sh` que o
  instalador executa
- [swwayps](https://github.com/swwayps) — o `cloudredirect-moon`, de onde vieram
  o hook de 32 bits e a GUI em Qt6

## Licença

Segue a licença do upstream. Ver [LICENSE](LICENSE).

## Support

Issues: https://github.com/LucianoSkx/cloudredirect-BR/issues
