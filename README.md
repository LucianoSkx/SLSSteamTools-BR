# CloudRedirect BR

Fork do [CloudRedirect](https://github.com/Selectively11/CloudRedirect) via o
[swwayps/cloudredirect-moon](https://github.com/swwayps/cloudredirect-moon), com a
**interface da GUI em português** e um instalador para cada programa do
conjunto.

O hook em si é o do upstream: um `cloud_redirect.so` de 32 bits, carregado na
Steam via `LD_PRELOAD`. O SLSsteam é quem entra por `LD_AUDIT`.

O que muda nesta fork:

- **GUI em pt-BR** — as 7 abas (Painel, Aplicativos, Backups, Provedor de
  nuvem, Instalação, Estatísticas, Migração), os diálogos, as mensagens de
  estado e as do backend, do deployer e do fluxo OAuth
- **Um instalador por programa** — cada um instala e remove só o seu, sem
  depender dos outros

## Instalar

Um link por programa. Rode na ordem que quiser; só o CloudRedirect depende do
SLSsteam instalado.

### CloudRedirect

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install-cloudredirect.sh | bash
```

Compila a interface Qt6 desta fork, instala o `cloud_redirect.so` e a CLI (o
mesmo que o botão **Instalar** da aba **Instalação** faz) e cria a entrada de
menu. O `cloud_redirect.so` já vem commitado no repositório, em 32 bits.

### SLSsteam

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install-slssteam.sh | bash
```

Baixa a release oficial do [AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam)
e roda o `setup.sh` de dentro do pacote, que copia os binários 32 bits, cria o
wrapper `path/steam` e o `steam.desktop` com o `LD_AUDIT`. Além disso o script
injeta o `LD_AUDIT` também no `steam.sh` (backup em `steam.sh.slssteam.bak`,
modo `555` preservado) — o `setup.sh` oficial não mexe nele, e quem chama a
Steam digitando `steam` não passa nem pelo wrapper nem pelo `.desktop`.

Também deixa `DisableCloud: no` no `config.yaml`: o padrão `yes` do upstream
trava o CloudRedirect.

**Feche a Steam e abra de novo** — o `LD_AUDIT` só vale para processos novos.

### ASSella

O próprio upstream mantém o instalador:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
```

Não embrulhamos num link nosso: quem instala e quem desinstala é o mesmo script
do upstream, que se mantém em dia junto com o app. Ele baixa o AppImage, cria a
entrada de menu e o ícone.

O `ASSella` sai em inglês. A tradução pt-BR que existia era de um fork que foi
deletado.

### Opções

Todos os instaladores aceitam `--skip-deps` (não instala dependências de
sistema), `--verbose` e `--help`. Rodar de novo atualiza.

## Remover

Um link por programa também. **Nenhum dos três apaga dados**: config, tokens,
saves, backups e o banco continuam no lugar.

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/remove-cloudredirect.sh | bash -s -- --yes

curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/remove-slssteam.sh | bash -s -- --yes

curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/remove-assella.sh | bash -s -- --yes
```

O do SLSsteam desfaz o patch do `steam.sh` devolvendo-o byte a byte e apaga o
wrapper, o `steam.desktop` e o `PATH` do fish. O do ASSella chama o
desinstalador do upstream.

Sem o `--yes` cada um pergunta antes; em execução não interativa o `--yes` é
obrigatório.

### O que fica onde

| Caminho | O quê |
|---|---|
| `~/.local/share/CloudRedirect/app/` | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |
| `~/.local/share/SLSsteam/` | `SLSsteam.so` e `library-inject.so` |
| `~/.config/SLSsteam/config.yaml` | config do SLSsteam |
| `~/.local/share/ACCELA/` | AppImage e dados do ASSella |

> O app do ASSella grava em `ACCELA` (1 L), que é o nome no próprio código dele
> (`src/utils/settings.py`, `APP_NAME`).

### Compilar o hook de 32 bits

O `cloud_redirect.so` e a CLI já estão commitados no repositório e é isso que o
instalador usa. Para recompilar (precisa de podman ou docker, porque o build
roda em container glibc-2.35 para o runtime da Steam):

```sh
./build.sh
```

## Credits

- [Selectively11](https://github.com/Selectively11) e colaboradores — o
  CloudRedirect original, e o hook que esta fork usa
- [swwayps](https://github.com/swwayps) — o `cloudredirect-moon`, de onde veio
  o hook de 32 bits e a GUI em Qt6

## Support

Issues: https://github.com/LucianoSkx/cloudredirect-BR/issues
