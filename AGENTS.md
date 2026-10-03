# slssteamtools-BR

Instalador SLSsteam + CloudRedirect (pt-BR, modo h3adcr-b). Bash + Qt6/C++ + Lua de terceiros.

## Layout

- `scripts/install.sh` — instalador principal (1/4 Steam, 2/4 SLSsteam, 3/4 CloudRedirect, 4/4 plugins Lua)
- `scripts/install-plugins.sh`, `uninstall-plugins.sh`, `toggle-plugins.sh` — standalone, instaláveis via `curl | bash`
- `sls-plugins/` — `.lua` de terceiros, não alterar além do cabeçalho de proveniência
- `ui-linux/`, `src/`, `flatpak/`, `ui/` — código próprio

## Scripts shell

- `#!/usr/bin/env bash` + `set -euo pipefail`, helpers `info/ok/warn/die` com cor
- Sem comentários no código (shebang e corpos de heredoc preservados)
- Scripts standalone: autocontidos, sem depender de checkout (fallback para `raw.githubusercontent.com/.../$BRANCH/...`, `BRANCH="${CR_BRANCH:-master}"`)
- Edição de config do usuário: idempotente (nunca duplica chave), preserva chaves existentes, backup antes (`config.yaml.bak`, `config.yaml.instbackup-*`, `steam.sh.slssteam.bak`)
- Sempre cobrir Steam nativo (`~/.config/SLSsteam`, `~/.local/share/...`) + Flatpak (`~/.var/app/com.valvesoftware.Steam/...`, só quando o prefixo existe)
- SLSsteam espera `Plugins: yes/no` (não `on/off`); `download.lua` exige seções `AdditionalDepots:` e `DecryptionKeys:` (vazias bastam)

## Docs

- README.md documenta cada etapa do instalador + one-liners `curl | bash` dos scripts standalone
- URLs raw do README precisam existir no `master` (conferir com `curl -o /dev/null -w '%{http_code}'`)
- Texto telegráfico, sem filler; mensagens e README em pt-BR

## Verificação

- `bash -n` em todo `.sh` alterado
- Teste funcional com `HOME` falso (ex.: `HOME=/tmp/fakehome ./scripts/install-plugins.sh`), nunca rodar `install.sh` real (mata a Steam, rebaixa o cliente, recompila Qt)
- `toggle off/on` precisa resultar em `Plugins: no/yes` literal

## Commits

- Conventional Commits, descrição em pt-BR: `fix(install): ...`, `feat(plugins): ...`, `docs(readme): ...`, `refactor(scripts): ...`
