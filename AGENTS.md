# slssteamtools-BR

Instalador do CloudRedirect pt-BR (hook 32-bit + CLI + UI Qt6). Bash + C++/Qt6 + Lua de terceiros.

Escopo: este repo instala **apenas** o CloudRedirect. Steam e SLSsteam são responsabilidade do [h3adcr-b](https://github.com/Deadboy666/h3adcr-b): `scripts/headcrab-run.sh` baixa `headcrab.pages.dev`, neutraliza as chamadas `crinstall` (instalaria o app CloudRedirect flatpak e baixaria o hook/CLI dele por cima) e `SetupHeadcrab_Updater` (sobrescreveria o atalho deste repo) e roda. **Nenhum script instala flatpak.** Do h3adcr-b vêm também o pin do cliente (`scripts/pin-client.sh`, só `steam.cfg`) e a entrada de menu do Headcrab Updater (`scripts/install-updater.sh`). `dgsc`, manifestos, `steam.sh` e `config.yaml` do SLSsteam não são implementados aqui.

## Layout

- `scripts/headcrab-run.sh` — único caminho para o h3adcr-b; aborta se as chamadas `crinstall`/`SetupHeadcrab_Updater` sumirem do script do upstream
- `scripts/install.sh` — roda `headcrab-run.sh` → baixa `cloud_redirect.so`/`cloud_redirect_cli` da release `latest` → compila a UI Qt6 → instala ícones e `.desktop` → instala o Headcrab Updater
- `scripts/toggle-plugins.sh` — standalone, instalável via `curl | bash`; mexe só em `Plugins: yes/no`
- `scripts/pin-client.sh` — standalone; `pin` (padrão)/`unpin`/`status`, mexe só em `~/.steam/steam/steam.cfg`
- `scripts/install-updater.sh` — standalone; `.desktop` + ícone do Headcrab Updater (Exec chama `headcrab-run.sh`), `--remove` desfaz
- `src/`, `ui-linux/` — código próprio (hook C++ 32-bit + UI Qt6/QML em pt-BR)
- `cloud_redirect.so`, `cloud_redirect_cli` — artefatos i386 fora do git: o instalador baixa da release `latest`, publicada pelo CI a cada push na `main`; `./build.sh` gera uma cópia local ignorada pelo git
- `test/` (shell, registrado no ctest) e `tests/` (C++, declarados no CMake só se o `.cpp` existir)

## Scripts shell

- `#!/usr/bin/env bash` + `set -euo pipefail` (exceto `diagnose.sh`, que coleta diagnóstico e segue após falha), helpers `info/ok/warn/die` com cor
- Sem comentários no corpo do código (shebang, cabeçalho de uso e heredocs preservados)
- Scripts standalone: autocontidos, sem depender de checkout (fallback para `raw.githubusercontent.com/.../$BRANCH/...`, `BRANCH="${CR_BRANCH:-main}"`)
- Download é atômico (`baixar`: temp + `mv`); `HEADCRAB_URL` permite apontar o instalador do upstream para um stub em teste
- `install.sh` não edita `config.yaml` do SLSsteam, `steam.sh` nem `steam.cfg`: se o hook não estiver no launcher, ele apenas avisa (o h3adcr-b liga com `DisableCloud: no`)
- `uninstall.sh` remove só o CloudRedirect (hook, CLI, UI, ícones, `.desktop`) e a entrada `headcrab.desktop` apontando para a URL raw deste repo; Steam/SLSsteam ficam intactos
- Somente Steam nativo (`~/.local/share/...`); flatpak não é suportada
- SLSsteam espera `Plugins: yes/no` (não `on/off`); os plugins Lua vêm do ASSella, e o `lobster.lua` lê as seções `AdditionalDepots:` e `DecryptionKeys:` (vazias bastam)
- Guard de sinal do hook só via `src/common/crash_guard.h` (`CrashGuard`, jmp_buf por thread, um handler por processo); não reimplementar

## Docs

- README.md documenta a divisão de responsabilidades, a instalação em 1 comando e os one-liners `curl | bash` dos scripts standalone
- URLs raw do README precisam existir na `main` (conferir com `curl -o /dev/null -w '%{http_code}'`)
- Texto telegráfico, sem filler; mensagens e README em pt-BR

## Verificação

- `bash -n` em todo `.sh` alterado
- `./build.sh` (podman/docker) reconstrói o `.so` i386; `ctest --test-dir build_host` tem que fechar 10/10 e `ctest --test-dir build` (LINUX_32BIT) 11/11
- CI em `.github/workflows/ci.yml` roda os dois conjuntos em Ubuntu 22.04; o job `linux32` usa o `Dockerfile.builder`
- Teste funcional com `HOME` falso (ex.: `HOME=/tmp/fakehome HEADCRAB_URL=file:///tmp/stub.sh ./scripts/install.sh`), nunca rodar `install.sh` real sem o usuário pedir (mata a Steam, recompila Qt)
- `toggle off/on` precisa resultar em `Plugins: no/yes` literal
- Antes de dizer pronto: o `.so` da release `latest` e os instalados em `~/.local/share/CloudRedirect/` e `~/.local/share/cloud_redirect/` têm que ser o mesmo binário

## Commits

- Conventional Commits, descrição em pt-BR: `fix(install): ...`, `feat(plugins): ...`, `docs(readme): ...`, `refactor(scripts): ...`
