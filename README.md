# CloudRedirect BR

Fork do [CloudRedirect](https://github.com/Selectively11/CloudRedirect) via o
[swwayps/cloudredirect-moon](https://github.com/swwayps/cloudredirect-moon), com a
**interface da GUI em português**.

O hook em si é o do upstream: um `cloud_redirect.so` de 32 bits, carregado na
Steam via `LD_PRELOAD`. O SLSsteam é quem entra por `LD_AUDIT`.

O que muda nesta fork:

- **GUI em pt-BR** — as 7 abas (Painel, Aplicativos, Backups, Provedor de
  nuvem, Instalação, Estatísticas, Migração), os diálogos, as mensagens de
  estado e as do backend, do deployer e do fluxo OAuth

## Instalar

SLSsteam e CloudRedirect vêm juntos, num instalador só: eles não funcionam
separados. O CloudRedirect implanta o hook na Steam pelo `LD_AUDIT` que o
SLSsteam instala, e precisa do `DisableCloud: no` no config do SLSsteam para não
ser bloqueado.

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install.sh | bash
```

Ele faz, nesta ordem:

**1. SLSsteam** — baixa a release oficial do
[AceSLS/SLSsteam](https://github.com/AceSLS/SLSsteam) e roda o `setup.sh` de
dentro do pacote, que copia os binários 32 bits, cria o wrapper `path/steam` e o
`steam.desktop` com o `LD_AUDIT`. Além disso o script injeta o `LD_AUDIT`
também no `steam.sh` (backup em `steam.sh.slssteam.bak`, modo `555` preservado) —
o `setup.sh` oficial não mexe nele, e quem chama a Steam digitando `steam` não
passa nem pelo wrapper nem pelo `.desktop`. Também deixa `DisableCloud: no` no
`config.yaml`, porque o padrão `yes` do upstream trava o CloudRedirect.

**2. CloudRedirect** — compila a interface Qt6 desta fork, instala o
`cloud_redirect.so` e a CLI (o mesmo que o botão **Instalar** da aba
**Instalação** faz, e que só funciona com o passo 1 feito) e cria a entrada de
menu. O `cloud_redirect.so` já vem commitado no repositório, em 32 bits.

**Reinicie a Steam** para o `LD_AUDIT` valer — ele só se aplica a processos
novos. Depois abra o CloudRedirect pelo menu.

Opções: `--skip-deps` (não instala dependências de sistema), `--verbose`,
`--help`. Rodar de novo atualiza.

## Remover

**Nenhum dos dois apaga dados**: config, tokens OAuth, saves, backups e logs do
CloudRedirect e o `config.yaml` do SLSsteam continuam no lugar.

```sh
curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/uninstall.sh | bash -s -- --yes
```

Desfaz o patch do `steam.sh` devolvendo-o byte a byte, apaga o wrapper, o
`steam.desktop`, o `PATH` do fish, os binários 32 bits, a GUI e as entradas de
menu. Patch de LD_AUDIT de outra ferramenta (o h3adcr-b, por exemplo) é
preservado: só sai o que este instalador escreveu.

Sem o `--yes` ele pergunta antes; em execução não interativa o `--yes` é
obrigatório.

## Fora do escopo

Isto aqui é só o par SLSsteam + CloudRedirect. O
[ASSella](https://github.com/niwia/ASSella) é um projeto independente, com
instalador e desinstalador próprios:

```sh
curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
```

### O que fica onde

| Caminho | O quê |
|---|---|
| `~/.local/share/CloudRedirect/app/` | GUI, `cloud_redirect.so` e `cloud_redirect_cli` |
| `~/.local/share/CloudRedirect/` | hook implantado (o `.so` e a CLI) |
| `~/.config/CloudRedirect/` | `config.json`, `storage/`, `backups/`, `tokens_*.json`, `r2_credentials.json`, logs |
| `~/.local/share/SLSsteam/` | `SLSsteam.so` e `library-inject.so` |
| `~/.config/SLSsteam/config.yaml` | config do SLSsteam |

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
