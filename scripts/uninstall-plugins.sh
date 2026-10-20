#!/usr/bin/env bash
set -euo pipefail

NATIVE_CONFIG_DIR="$HOME/.config/SLSsteam"
FILES="download.lua spliced-tickets.lua"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }

config_dirs() {
    printf '%s\n' "$NATIVE_CONFIG_DIR"
}

removidos=0
while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    for f in $FILES; do
        if [ -f "$dir/plugins/$f" ]; then
            rm -f "$dir/plugins/$f"
            ok "removido $dir/plugins/$f"
            removidos=$((removidos + 1))
        fi
    done
done < <(config_dirs)

[ "$removidos" -gt 0 ] || warn "nenhum plugin deste repo encontrado"
echo "Reinicie a Steam para descarregar os plugins."
