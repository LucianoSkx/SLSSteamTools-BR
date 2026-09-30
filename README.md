# CloudRedirect BR

Fork do [CloudRedirect](https://github.com/Selectively11/CloudRedirect) via o
[swwayps/cloudredirect-moon](https://github.com/swwayps/cloudredirect-moon), com a
**interface da GUI em português** e um **instalador** que traz o conjunto todo.

O hook em si é o do upstream: um `cloud_redirect.so` de 32 bits, carregado na
Steam via `LD_PRELOAD`. O SLSsteam é quem entra por `LD_AUDIT`.

O que muda nesta fork:

- **GUI em pt-BR** — as 7 abas (Painel, Aplicativos, Backups, Provedor de
  nuvem, Instalação, Estatísticas, Migração), os diálogos, as mensagens de
  estado e as do backend, do deployer e do fluxo OAuth
- **`scripts/install.sh`** — instala SLSsteam + CloudRedirect + ASSella e cria
  as entradas de menu

## Instalação

```sh
./scripts/install.sh
```

Ou de qualquer lugar:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash
```

Opções: `--skip-deps` (não instala dependências de sistema), `--verbose`,
`--help`. Rodar de novo atualiza tudo.

O conjunto:

- **SLSsteam** — release oficial do [AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam)
- **CloudRedirect** — compilado da fonte desta fork, com Qt6
- **ASSella** — pelo instalador oficial dele,
  `curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh`

O que o instalador faz:

- instala dependências via `pacman`, `apt` ou `dnf`
- baixa o SLSsteam, copia as bibliotecas 32 bits e injeta o `LD_AUDIT` no
  `steam.sh` (backup em `steam.sh.slssteam.bak`, modo `555` preservado)
- deixa `DisableCloud: no` no `config.yaml` do SLSsteam — o padrão `yes` trava
  o CloudRedirect
- compila a GUI e instala em `~/.local/share/CloudRedirect/app/`
- implanta o `cloud_redirect.so` e a CLI, que é o que o botão **Instalar** da
  aba **Instalação** faz
- cria a entrada de menu do CloudRedirect e o ícone
- entrega o ASSella ao instalador oficial dele, que baixa o AppImage, cria a
  entrada de menu e o ícone

**Feche a Steam e abra de novo**: o `LD_AUDIT` só vale para processos novos.

O `ASSella` sai em inglês. A tradução pt-BR dele era de um fork que foi
deletado; o resto do conjunto é pt-BR.

### Desinstalar

```sh
./scripts/uninstall.sh
```

Remove os três programas, as entradas de menu e desfaz o patch do `steam.sh`
(devolvendo-o byte a byte). O ASSella é desinstalado pelo instalador oficial
dele. **Não apaga dados**: config, tokens OAuth, saves, backups e logs do
CloudRedirect, o `config.yaml` do SLSsteam e o banco do ASSella continuam.

### O que fica onde

| Caminho | O quê |
|---|---|
| `~/.local/share/CloudRedirect/app/` | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |
| `~/.local/share/SLSsteam/` | `SLSsteam.so` e `library-inject.so` |
| `~/.config/SLSsteam/config.yaml` | config do SLSsteam |
| `~/.local/share/ACCELA/` | AppImage e dados do ASSella |

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
