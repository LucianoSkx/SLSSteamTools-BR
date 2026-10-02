#!/usr/bin/env bash
# Liga/desliga os plugins Lua sem instalar nem remover arquivos.
# So alterna a chave Plugins do config.yaml do SLSsteam.
#
# Uso: ./scripts/toggle-plugins.sh on|off
set -euo pipefail

[ "${1:-}" = "on" ] || [ "${1:-}" = "off" ] \
    || [ "${1:-}" = "yes" ] || [ "${1:-}" = "no" ] \
    || { echo "uso: $0 on|off" >&2; exit 1; }
case "$1" in
    on|yes) VALOR="yes" ;;
    *)      VALOR="no" ;;
esac

NATIVE_CONFIG_DIR="$HOME/.config/SLSsteam"
FLATPAK_CONFIG_DIR="$HOME/.var/app/com.valvesoftware.Steam/.config/SLSsteam"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }

config_dirs() {
    printf '%s\n' "$NATIVE_CONFIG_DIR"
    if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
        printf '%s\n' "$FLATPAK_CONFIG_DIR"
    fi
}

alternar() {
    local cfg="$1"
    mkdir -p "$(dirname "$cfg")"
    [ -f "$cfg" ] || { printf 'Plugins: %s\n' "$VALOR" > "$cfg"; return 0; }
    if grep -qE '^[[:space:]]*Plugins:' "$cfg"; then
        sed -i -E "s/^([[:space:]]*Plugins:).*/\1 $VALOR/" "$cfg"
    else
        printf '\nPlugins: %s\n' "$VALOR" >> "$cfg"
    fi
}

while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    cfg="$dir/config.yaml"
    [ -f "$cfg" ] || { warn "sem config em $cfg; pulando"; continue; }
    alternar "$cfg"
    ok "Plugins: $VALOR em $cfg"
done < <(config_dirs)

echo "Reinicie a Steam para aplicar."
