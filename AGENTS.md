# slssteamtools-BR

Instalador SLSsteam + CloudRedirect (pt-BR). Bash + Qt6/C++ + Lua de terceiros.

`scripts/install.sh` é um **port fiel do [h3adcr-b](https://github.com/Deadboy666/h3adcr-b)** (`headcrab.sh`): mesmas funções, mesma ordem de etapas, mesmo pin de cliente (`1791918634`), mesmos manifestos/dgsc/client.sh, mesmo launcher `steam.sh`. Só o CloudRedirect é deste repo (`.so`+CLI próprios e UI Qt6 nativa no lugar do app flatpak de OAuth).

## Layout

- `scripts/install.sh` — instalador principal (port do h3adcr-b): deps → `DisableSLSsteamPath` → Headcrab Updater → pin do cliente → SLSsteam → `crinstall` (CloudRedirect) → `editconfig` → patch do `steam.sh` → `version` (ASSella) → config → plugins Lua
- `scripts/install-plugins.sh`, `uninstall-plugins.sh`, `toggle-plugins.sh` — standalone, instaláveis via `curl | bash`
- `sls-plugins/` — `.lua` de terceiros; única alteração admitida é o esquema https dos endpoints remotos, registrada no cabeçalho de proveniência
- `src/`, `ui-linux/` — código próprio (hook C++ 32-bit + UI Qt6/QML em pt-BR)
- `cloud_redirect.so`, `cloud_redirect_cli` — binários i386 commitados; reconstruir com `./build.sh` toda vez que `src/` mudar
- `ui/` — UI Windows WPF herdada do upstream Selectively11/CloudRedirect, não buildada aqui
- `test/` (shell, registrado no ctest) e `tests/` (C++, declarados no CMake só se o `.cpp` existir)

## Scripts shell

- `scripts/install.sh` mantém o `set -uo pipefail` e a estrutura/indentação do h3adcr-b (tabs, funções com nome em CamelCase) — divergences do upstream precisam ser justificadas, não cosméticas
- Demais scripts: `#!/usr/bin/env bash` + `set -euo pipefail` (exceto `diagnose.sh`, que coleta diagnóstico e segue após falha), helpers `info/ok/warn/die` com cor
- Sem comentários no corpo do código (shebang, cabeçalho de uso e heredocs preservados)
- Scripts standalone: autocontidos, sem depender de checkout (fallback para `raw.githubusercontent.com/.../$BRANCH/...`, `BRANCH="${CR_BRANCH:-master}"`)
- Download é atômico (`baixar`: temp + `mv`); binários de terceiros (`dgsc`, `netsock.so`) têm SHA256 fixado em `install.sh` — trocar a versão exige novo hash e commit separado
- Edição de config do usuário: idempotente (nunca duplica chave), preserva chaves existentes, backup antes (`config.yaml.bak`, `config.yaml.instbackup-*`, `steam.sh.slssteam.bak`)
- Somente Steam nativo (`~/.config/SLSsteam`, `~/.local/share/...`); sem suporte a Steam flatpak
- SLSsteam espera `Plugins: yes/no` (não `on/off`); `download.lua` exige seções `AdditionalDepots:` e `DecryptionKeys:` (vazias bastam)
- Guard de sinal do hook só via `src/common/crash_guard.h` (`CrashGuard`, jmp_buf por thread, um handler por processo); não reimplementar

## Docs

- README.md documenta cada etapa do instalador + one-liners `curl | bash` dos scripts standalone
- URLs raw do README precisam existir no `master` (conferir com `curl -o /dev/null -w '%{http_code}'`)
- Texto telegráfico, sem filler; mensagens e README em pt-BR

## Verificação

- `bash -n` em todo `.sh` alterado
- `./build.sh` (podman/docker) reconstrói o `.so` i386; `ctest --test-dir build` tem que fechar 9/9
- Teste funcional com `HOME` falso (ex.: `HOME=/tmp/fakehome ./scripts/install-plugins.sh`), nunca rodar `install.sh` real sem o usuário pedir (mata a Steam, rebaixa o cliente, recompila Qt)
- `install.sh` diverge do h3adcr-b em: URLs do CloudRedirect (repo BR), `crinstall` (UI Qt6 em vez de flatpak), `download` atômico, SHA256 de `dgsc`/`netsock`, `rm -f`, e as funções BR `registrar_versao_slssteam`/`garantir_config_slssteam`/`instalar_plugins_sls`. Qualquer outra divergência é bug
- O `.desktop` do Headcrab Updater gerado pelo `install.sh` deve apontar pro `install.sh` deste repo, nunca pro `headcrab.sh` do h3adcr-b
- `toggle off/on` precisa resultar em `Plugins: no/yes` literal
- Antes de dizer pronto: o `.so` do repo, o de `~/.local/share/CloudRedirect/` e o de `~/.local/share/cloud_redirect/` têm que ser o mesmo binário

## Commits

- Conventional Commits, descrição em pt-BR: `fix(install): ...`, `feat(plugins): ...`, `docs(readme): ...`, `refactor(scripts): ...`
