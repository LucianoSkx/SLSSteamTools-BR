# CloudRedirect BR

Fork do [CloudRedirect](https://github.com/Selectively11/CloudRedirect) via o
[swwayps/cloudredirect-moon](https://github.com/swwayps/cloudredirect-moon), com a
**interface da GUI em português**.

O hook é o do upstream: um `cloud_redirect.so` de 32 bits, carregado na Steam via
`LD_PRELOAD`. O SLSsteam é quem entra por `LD_AUDIT`.

O que muda nesta fork:

- **GUI em pt-BR** — as 7 abas (Painel, Aplicativos, Backups, Provedor de
  nuvem, Instalação, Estatísticas, Migração), os diálogos, as mensagens de
  estado e as do backend, do deployer e do fluxo OAuth

## Requisitos

- Linux x86_64 com Steam
- distro com `pacman`, `apt` ou `dnf` (as dependências são instaladas pelo
  script)
- compilador e Qt6, se for instalar o CloudRedirect — o script compila a GUI

## Instalar

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

### Opções

| Opção | Efeito |
|---|---|
| `--skip-deps` | não instala dependências de sistema |
| `--verbose` | mostra a saída de todos os comandos |
| `--help` | mostra a ajuda |

Rodar o instalador de novo atualiza tudo.

Variáveis de ambiente: `CR_INSTALL_SKIP_DEPS=1`, `VERBOSE=1`, `CR_BRANCH`,
`GITHUB_TOKEN` (evita o limite de requisições da API).

## Remover

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/uninstall.sh | bash -s -- --yes
```

Desfaz o patch do `steam.sh` devolvendo-o byte a byte e apaga o wrapper, o
`steam.desktop`, o `PATH` do fish, os binários 32 bits, a GUI e as entradas de
menu. Um patch de `LD_AUDIT` de outra ferramenta é preservado: só sai o que este
instalador escreveu.

**Nenhum dos dois apaga dados.** Ficam no lugar:

- `~/.config/CloudRedirect/` — config, tokens OAuth, saves, backups e logs
- `~/.config/SLSsteam/config.yaml` — config do SLSsteam

Sem o `--yes` o script pergunta antes; em execução não interativa o `--yes` é
obrigatório.

## O que fica onde

| Caminho | O quê |
|---|---|
| `~/.local/share/CloudRedirect/app/` | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |
| `~/.local/share/SLSsteam/` | `SLSsteam.so`, `library-inject.so` e o wrapper `path/` |
| `~/.config/SLSsteam/config.yaml` | config do SLSsteam |

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

## Fora do escopo

Isto aqui cobre só o par SLSsteam + CloudRedirect.

O [ASSella](https://github.com/niwia/ASSella) é um projeto independente e
mantém o próprio instalador:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
```

Ele não é traduzido aqui e o instalador dele sai em inglês.

## Credits

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
