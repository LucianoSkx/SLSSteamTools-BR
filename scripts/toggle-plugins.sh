#!/usr/bin/env bash
set -euo pipefail

[ "${1:-}" = "on" ] || [ "${1:-}" = "off" ] \
    || [ "${1:-}" = "yes" ] || [ "${1:-}" = "no" ] \
    || { echo "uso: $0 on|off" >&2; exit 1; }
case "$1" in
    on|yes) VALOR="yes" ;;
    *)      VALOR="no" ;;
esac

NATIVE_CONFIG_DIR="$HOME/.config/SLSsteam"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }

BACKUPS_FEITOS=""
backup_cfg() {
    local cfg="$1" bkp
    [ -f "$cfg" ] || return 0
    case " $BACKUPS_FEITOS " in *" $cfg "*) return 0 ;; esac
    bkp="$(mktemp "${cfg}.instbackup-XXXXXX")" || { warn "impossivel criar backup de $cfg"; return 0; }
    cp -p "$cfg" "$bkp" || { warn "falha ao copiar $cfg"; return 0; }
    BACKUPS_FEITOS="$BACKUPS_FEITOS $cfg"
    ok "backup em $bkp"
}

config_dirs() {
    printf '%s\n' "$NATIVE_CONFIG_DIR"
}

alternar() {
    local cfg="$1" atual
    mkdir -p "$(dirname "$cfg")"
    [ -f "$cfg" ] || { printf 'Plugins: %s\n' "$VALOR" > "$cfg"; return 0; }
    atual="$(awk '/^[[:space:]]*Plugins:/ {print $2; exit}' "$cfg")"
    [ "$atual" = "$VALOR" ] && return 0
    backup_cfg "$cfg"
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
