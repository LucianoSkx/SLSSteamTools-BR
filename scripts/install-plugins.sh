#!/usr/bin/env bash
# Instala so os plugins Lua do SLSsteam, sem o resto do instalador
# (sem headcrab, sem reinstalar o SLSsteam).
#
# Uso: ./scripts/install-plugins.sh
#      curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install-plugins.sh | bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$PWD")"
NATIVE_CONFIG_DIR="$HOME/.config/SLSsteam"
FLATPAK_CONFIG_DIR="$HOME/.var/app/com.valvesoftware.Steam/.config/SLSsteam"
REPO_RAW="https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR"
BRANCH="${CR_BRANCH:-master}"
FILES="download.lua spliced-tickets.lua"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()  { echo "[erro] $*" >&2; exit 1; }

config_dirs() {
    printf '%s\n' "$NATIVE_CONFIG_DIR"
    if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
        printf '%s\n' "$FLATPAK_CONFIG_DIR"
    fi
}

garantir_plugins_yes() {
    local cfg="$1"
    mkdir -p "$(dirname "$cfg")"
    [ -f "$cfg" ] || { printf 'Plugins: yes\n' > "$cfg"; return 0; }
    if grep -qE '^[[:space:]]*Plugins:' "$cfg"; then
        sed -i -E 's/^([[:space:]]*Plugins:).*/\1 yes/' "$cfg"
    else
        printf '\nPlugins: yes\n' >> "$cfg"
    fi
}

obter_lua() {
    local nome="$1" dest="$2"
    if [ -f "$SCRIPT_DIR/../sls-plugins/$nome" ]; then
        cp -f "$SCRIPT_DIR/../sls-plugins/$nome" "$dest"
    else
        curl -fsSL -o "$dest" "$REPO_RAW/$BRANCH/sls-plugins/$nome" \
            || die "falha ao baixar $nome"
    fi
}

command -v curl >/dev/null 2>&1 || die "curl ausente"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for f in $FILES; do obter_lua "$f" "$TMP/$f"; done

while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    mkdir -p "$dir/plugins"
    cp -f "$TMP"/download.lua "$TMP"/spliced-tickets.lua "$dir/plugins/"
    garantir_plugins_yes "$dir/config.yaml"
    ok "plugins Lua em $dir/plugins (Plugins: yes)"
done < <(config_dirs)

echo "Reinicie a Steam para carregar os plugins."
