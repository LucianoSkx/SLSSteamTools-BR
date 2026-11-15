#!/usr/bin/env bash
set -euo pipefail

NATIVE_CONFIG_DIR="$HOME/.config/SLSsteam"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
die()  { echo "[erro] $*" >&2; exit 1; }

BACKUPS_FEITOS=""
backup_cfg() {
    local cfg="$1" bkp
    [ -f "$cfg" ] || return 0
    case " $BACKUPS_FEITOS " in *" $cfg "*) return 0 ;; esac
    bkp="$(mktemp "${cfg}.instbackup-XXXXXX")" || die "impossivel criar backup de $cfg"
    cp -p "$cfg" "$bkp" || die "falha ao copiar $cfg para $bkp"
    BACKUPS_FEITOS="$BACKUPS_FEITOS $cfg"
    ok "backup em $bkp"
}

config_dirs() {
    printf '%s\n' "$NATIVE_CONFIG_DIR"
}

garantir_plugins_yes() {
    local cfg="$1"
    mkdir -p "$(dirname "$cfg")"
    [ -f "$cfg" ] || { printf 'Plugins: yes\n' > "$cfg"; return 0; }
    grep -qE '^[[:space:]]*Plugins:[[:space:]]*yes[[:space:]]*$' "$cfg" && return 0
    backup_cfg "$cfg"
    if grep -qE '^[[:space:]]*Plugins:' "$cfg"; then
        sed -i -E 's/^([[:space:]]*Plugins:).*/\1 yes/' "$cfg"
    else
        printf '\nPlugins: yes\n' >> "$cfg"
    fi
}

garantir_secoes_download() {
    local cfg="$1" chave faltando=0
    for chave in AdditionalDepots DecryptionKeys; do
        grep -qE "^[[:space:]]*$chave:" "$cfg" 2>/dev/null || faltando=1
    done
    [ "$faltando" = 1 ] || return 0
    backup_cfg "$cfg"
    for chave in AdditionalDepots DecryptionKeys; do
        grep -qE "^[[:space:]]*$chave:" "$cfg" 2>/dev/null \
            || printf '\n%s:\n' "$chave" >> "$cfg"
    done
}

while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    mkdir -p "$dir/plugins"
    garantir_plugins_yes "$dir/config.yaml"
    garantir_secoes_download "$dir/config.yaml"
    ok "config pronta para plugins em $dir (Plugins: yes)"
done < <(config_dirs)

echo "Os .lua são instalados pelo ASSella; reinicie a Steam depois."
