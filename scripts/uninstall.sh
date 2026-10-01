#!/usr/bin/env bash
set -euo pipefail

MARCADOR_SLS="# --- SLSsteam injetado pelo instalador do CloudRedirect ---"
FIM_MARCADOR_SLS="# --- fim da injecao SLSsteam ---"

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_SLS="$DIR_DADOS/SLSsteam"
DIR_CR="$DIR_DADOS/CloudRedirect"

ASSUMIR="${CR_UNINSTALL_ASSUME:-0}"
VERBOSE="${VERBOSE:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
aviso(){ printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

show_help() {
    cat <<'EOF'
Removedor do SLSsteam + CloudRedirect

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/uninstall.sh [opcoes]

Restaura o steam.sh a partir do steam.sh.slssteam.bak (ou remove o bloco
antigo com marcadores), apaga o client.sh do modo h3adcr-b, o steam.cfg
que travava os updates, o wrapper, os binarios, a GUI e as entradas de
menu. A Steam volta a se atualizar sozinha depois disso.

Nao apaga dados: config, tokens OAuth, saves, backups e logs do CloudRedirect
e o config.yaml do SLSsteam continuam no lugar.

Opcoes:
  --yes, -y     nao pede confirmacao
  --verbose     Mostra a saida dos comandos
  -h, --help    Mostra esta ajuda
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y)  ASSUMIR=1 ;;
        --verbose) VERBOSE=1 ;;
        -h|--help) show_help ;;
        *) die "opcao desconhecida: $arg" ;;
    esac
done

confirmar() {
    [ "$ASSUMIR" = "1" ] && return 0
    [ -t 0 ] || die "execucao nao interativa: rode com --yes"
    local r
    read -r -p "Remover o SLSsteam e o CloudRedirect? (s/N) " r
    case "$r" in s|S|y|Y) return 0 ;; *) die "cancelado" ;; esac
}

declare -A VISTOS=()
despatch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 0

    local inode; inode="$(stat -c '%i' "$sh")"
    [ -n "${VISTOS[$inode]:-}" ] && return 0
    VISTOS[$inode]=1

    local raiz; raiz="$(cd "$(dirname "$sh")" && pwd)"

    if [ -f "$sh.slssteam.bak" ]; then
        local modo; modo="$(stat -c '%a' "$sh")"
        chmod u+w "$sh"
        cat "$sh.slssteam.bak" > "$sh"
        chmod "$modo" "$sh"
        rm -f "$sh.slssteam.bak" "$raiz/client.sh" "$raiz/steam.cfg"
        ok "steam.sh restaurado do backup em $sh (updates da Steam liberados)"
        return 0
    fi

    # Formato antigo (bloco com marcadores do instalador anterior).
    grep -q 'LD_AUDIT' "$sh" && grep -q 'SLSsteam\.so' "$sh" || return 0

    if ! grep -q "$MARCADOR_SLS" "$sh"; then
        aviso "$sh tem um patch do SLSsteam de outra ferramenta; preservado como esta"
        return 0
    fi

    local tmp modo; tmp="$(mktemp)"
    modo="$(stat -c '%a' "$sh")"
    awk -v inicio="$MARCADOR_SLS" -v fim="$FIM_MARCADOR_SLS" '
        $0 == inicio { pulando=1; next }
        $0 == fim    { pulando=0; next }
        !pulando
    ' "$sh" > "$tmp"

    chmod u+w "$sh"
    cat "$tmp" > "$sh"
    chmod "$modo" "$sh"
    rm -f "$tmp"
    ok "patch do instalador removido de $sh"
}

main() {
    printf "${c_bold}Removedor do SLSsteam + CloudRedirect${c_reset}\n"
    confirmar

    titulo "1/3  CloudRedirect"
    rm -f "$DIR_APPS/cloudredirect.desktop"
    for tam in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
        rm -f "$DIR_DADOS/icons/hicolor/$tam/apps/cloudredirect.png"
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$DIR_DADOS/icons/hicolor" 2>/dev/null || true
    fi
    rm -rf "$DIR_CR"
    ok "interface, hook e CLI removidos de $DIR_CR"
    aviso "ficaram intactos: $HOME/.config/CloudRedirect (config, tokens, saves e backups)"

    titulo "2/3  SLSsteam"
    despatch_steam "$HOME/.local/share/Steam/steam.sh"
    despatch_steam "$HOME/.steam/steam/steam.sh"
    despatch_steam "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steam.sh"
    rm -f "$HOME/.local/share/Steam/steam.sh.slssteam.bak" \
          "$HOME/.steam/steam/steam.sh.slssteam.bak"
    rm -rf "$HOME/.headcrab"
    rm -f "$DIR_APPS/steam.desktop" "$DIR_APPS/steam-native.desktop" \
          "$HOME/.config/fish/conf.d/SLSsteam.fish"
    rm -rf "$DIR_SLS"
    ok "binarios e wrapper removidos de $DIR_SLS"
    aviso "o config $HOME/.config/SLSsteam foi preservado"

    titulo "3/3  Menu"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$DIR_APPS" 2>/dev/null || true
    fi
    ok "entradas de menu atualizadas"

    printf "\n${c_green}Removido.${c_reset} Os saves continuam. Reinicie a Steam.\n"
}

main "$@"
