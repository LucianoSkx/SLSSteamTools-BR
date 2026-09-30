# cloudredirect-moon

A fork of [CloudRedirect](https://github.com/Selectively11/CloudRedirect). This
fork adds cross-distro attach fixes, legacy save-layout healing, and
worker-thread crash containment on the Linux 32-bit hook.

The result is a 32-bit `cloud_redirect.so`, loaded into Steam via `LD_PRELOAD`.

## Instalação (pt-BR)

Um instalador que traz os três programas e cria as entradas de menu:

- **SLSsteam** — do repositório oficial [AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam)
- **CloudRedirect** — a GUI nativa desta fork, com a interface inteira em português
- **ASSella** — pelo próprio instalador oficial dele,
  `curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh`

```sh
./scripts/install.sh
```

Ou, de qualquer lugar:

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash
```

Opções: `--skip-deps` (não instala dependências de sistema), `--verbose`,
`--help`. Rodar de novo atualiza tudo.

O que ele faz:

- instala as dependências via `pacman`, `apt` ou `dnf`
- baixa o SLSsteam da release oficial, copia as bibliotecas 32 bits e injeta o
  `LD_AUDIT` no `steam.sh` (com backup em `steam.sh.slssteam.bak`)
- deixa `DisableCloud: no` no `config.yaml` do SLSsteam, que é o padrão que
  trava o CloudRedirect
- compila a GUI desta fork com Qt6 e instala em `~/.local/share/CloudRedirect/app/`
- implanta o `cloud_redirect.so` e a CLI, que é o mesmo que o botão **Instalar**
  da aba **Montagem** faz
- cria a entrada de menu do CloudRedirect com o ícone
- entrega o ASSella ao instalador oficial dele, que baixa o AppImage, cria a
  entrada de menu e o ícone — e continua sendo ele quem atualiza isso depois

O `ASSella` sai em inglês: a tradução pt-BR que existia era de um fork que foi
deletado. O resto do conjunto é pt-BR.

**Feche a Steam e abra de novo** depois de instalar: o `LD_AUDIT` só vale para
processos novos.

### Desinstalar

```sh
./scripts/uninstall.sh
```

Remove os três programas, as entradas de menu e desfaz o patch do `steam.sh`.
O ASSella é desinstalado pelo instalador oficial dele. **Não apaga dados**:
config e tokens do CloudRedirect, saves sincronizados, `config.yaml` do
SLSsteam e o banco do ASSella continuam no lugar.

### O que fica onde

| Caminho | O quê |
|---|---|
| `~/.local/share/CloudRedirect/app/` | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | hook implantado + saves |
| `~/.config/CloudRedirect/` | config, tokens OAuth, cache |
| `~/.local/share/SLSsteam/` | `SLSsteam.so` e `library-inject.so` |
| `~/.config/SLSsteam/config.yaml` | config do SLSsteam |
| `~/.local/share/ACCELA/` | AppImage e dados do ASSella (`ASSella.AppImage`) |

> O app do ASSella grava em `ACCELA` (1 L). Se os dados estiverem em `ACCELLA`
> (2 L, do fork pt-BR antigo), o instalador copia de um para o outro e
> preserva a pasta antiga.

## Credits

Upstream:

- [Selectively11](https://github.com/Selectively11) and contributors —
  the CloudRedirect hook this fork builds on.

## Support

Open an issue: https://github.com/swwayps/cloudredirect-moon/issues
