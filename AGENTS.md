# slssteamtools-BR

Instalador do CloudRedirect pt-BR (hook 32-bit + CLI + UI Qt6). Bash + C++/Qt6 + Lua de terceiros.

Escopo: este repo instala **apenas** o CloudRedirect. Steam e SLSsteam são responsabilidade do [h3adcr-b](https://github.com/Deadboy666/h3adcr-b): `scripts/install.sh` baixa e roda `headcrab.pages.dev` e depois substitui o CloudRedirect que ele deixou (`.so`/CLI da release e app flatpak) pelo deste repo (`.so`/CLI próprios + UI Qt6 nativa). Pin do cliente, `dgsc`, manifestos, `steam.sh` e `config.yaml` do SLSsteam não são implementados aqui.

## Layout

- `scripts/install.sh` — roda o h3adcr-b → baixa `cloud_redirect.so`/`cloud_redirect_cli` do branch → compila a UI Qt6 → instala ícones e `.desktop`
- `scripts/install-plugins.sh`, `uninstall-plugins.sh`, `toggle-plugins.sh` — standalone, instaláveis via `curl | bash`
- `sls-plugins/` — `.lua` de terceiros; única alteração admitida é o esquema https dos endpoints remotos, registrada no cabeçalho de proveniência
- `src/`, `ui-linux/` — código próprio (hook C++ 32-bit + UI Qt6/QML em pt-BR)
- `cloud_redirect.so`, `cloud_redirect_cli` — binários i386 commitados; reconstruir com `./build.sh` toda vez que `src/` mudar
- `ui/` — UI Windows WPF herdada do upstream Selectively11/CloudRedirect, não buildada aqui
- `test/` (shell, registrado no ctest) e `tests/` (C++, declarados no CMake só se o `.cpp` existir)

## Scripts shell

- `#!/usr/bin/env bash` + `set -euo pipefail` (exceto `diagnose.sh`, que coleta diagnóstico e segue após falha), helpers `info/ok/warn/die` com cor
- Sem comentários no corpo do código (shebang, cabeçalho de uso e heredocs preservados)
- Scripts standalone: autocontidos, sem depender de checkout (fallback para `raw.githubusercontent.com/.../$BRANCH/...`, `BRANCH="${CR_BRANCH:-main}"`)
- Download é atômico (`baixar`: temp + `mv`); `HEADCRAB_URL` permite apontar o instalador do upstream para um stub em teste
- `install.sh` não edita `config.yaml` do SLSsteam, `steam.sh` nem `steam.cfg`: se o hook não estiver no launcher, ele apenas avisa (o h3adcr-b liga com `DisableCloud: no`)
- `uninstall.sh` remove só o CloudRedirect (hook, CLI, UI, ícones, `.desktop`); Steam/SLSsteam ficam intactos
- Somente Steam nativo (`~/.local/share/...`); flatpak não é suportada
- SLSsteam espera `Plugins: yes/no` (não `on/off`); `download.lua` exige seções `AdditionalDepots:` e `DecryptionKeys:` (vazias bastam)
- Guard de sinal do hook só via `src/common/crash_guard.h` (`CrashGuard`, jmp_buf por thread, um handler por processo); não reimplementar

## Docs

- README.md documenta a divisão de responsabilidades, a instalação em 1 comando e os one-liners `curl | bash` dos scripts standalone
- URLs raw do README precisam existir na `main` (conferir com `curl -o /dev/null -w '%{http_code}'`)
- Texto telegráfico, sem filler; mensagens e README em pt-BR

## Verificação

- `bash -n` em todo `.sh` alterado
- `./build.sh` (podman/docker) reconstrói o `.so` i386; `ctest --test-dir build` tem que fechar 9/9
- Teste funcional com `HOME` falso (ex.: `HOME=/tmp/fakehome HEADCRAB_URL=file:///tmp/stub.sh ./scripts/install.sh`), nunca rodar `install.sh` real sem o usuário pedir (mata a Steam, recompila Qt)
- `toggle off/on` precisa resultar em `Plugins: no/yes` literal
- Antes de dizer pronto: o `.so` do repo, o de `~/.local/share/CloudRedirect/` e o de `~/.local/share/cloud_redirect/` têm que ser o mesmo binário

## Commits

- Conventional Commits, descrição em pt-BR: `fix(install): ...`, `feat(plugins): ...`, `docs(readme): ...`, `refactor(scripts): ...`
