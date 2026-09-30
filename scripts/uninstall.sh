#!/usr/bin/env bash
set -euo pipefail

# Remove o que o install.sh instalou. Nao apaga dados: o config do CloudRedirect,
# os saves sincronizados, o banco do ASSella e o log do SLSsteam ficam.
# Uso: ./scripts/uninstall.sh [--yes] [--verbose]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTE_CR="$(cd "$SCRIPT_DIR/.." && pwd)"

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONS="$DIR_DADOS/icons/hicolor/256x256/apps"
DIR_SLS="$DIR_DADOS/SLSsteam"
DIR_CR="$DIR_DADOS/CloudRedirect"
DIR_ASSELLA="$DIR_DADOS/ACCELA"

ASSUMIR="${CR_UNINSTALL_ASSUME:-0}"
VERBOSE="${VERBOSE:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
aviso(){ printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

run_cmd() {
    if [ "$VERBOSE" = "1" ]; then "$@"; else "$@" >/dev/null 2>&1; fi
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y)   ASSUMIR=1 ;;
        --verbose)  VERBOSE=1 ;;
        -h|--help)
            cat <<'EOF'
Desinstalador do SLSsteam + CloudRedirect + ASSella

Uso: ./scripts/uninstall.sh [--yes] [--verbose]

  --yes    nao pede confirmacao
EOF
            exit 0 ;;
        *) die "opcao desconhecida: $arg" ;;
    esac
done

# Desfaz o patch do instalador no steam.sh, sem mexer no resto do arquivo.
declare -A VISTOS=()
despatch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 0

    local inode; inode="$(stat -c '%i' "$sh")"
    [ -n "${VISTOS[$inode]:-}" ] && return 0
    VISTOS[$inode]=1

    # Sem referencia ao SLSsteam: nada foi feito aqui.
    grep -q 'LD_AUDIT' "$sh" && grep -q 'SLSsteam\.so' "$sh" || return 0

    if ! grep -q 'SLSsteam injetado pelo instalador do CloudRedirect' "$sh"; then
        aviso "$sh tem um patch do SLSsteam de outra ferramenta; preservado como esta"
        return 0
    fi

    local tmp modo; tmp="$(mktemp)"
    modo="$(stat -c '%a' "$sh")"
    awk '
        /^# --- SLSsteam injetado pelo instalador do CloudRedirect ---$/ { pulando=1; next }
        /^# --- fim da injecao SLSsteam ---$/                     { pulando=0; next }
        !pulando
    ' "$sh" > "$tmp"

    chmod u+w "$sh"
    cat "$tmp" > "$sh"
    chmod "$modo" "$sh"
    rm -f "$tmp"
    ok "patch do SLSsteam removido de $sh"
}

confirmar() {
    [ "$ASSUMIR" = "1" ] && return 0
    [ -t 0 ] || die "execucao nao interativa: rode com --yes"
    local r
    read -r -p "Remover os tres programas? (s/N) " r
    case "$r" in
        s|S|y|Y) return 0 ;;
        *) die "cancelado" ;;
    esac
}

main() {
    printf "${c_bold}Desinstalador SLSsteam + CloudRedirect + ASSella${c_reset}\n"
    confirmar

    titulo "CloudRedirect"
    rm -f "$DIR_APPS/cloudredirect.desktop"
    rm -f "$DIR_ICONS/cloudredirect.png"
    # O build sai junto quando o codigo clonado esta dentro do proprio diretorio.
    if [ -d "$DIR_CR/src/ui-linux/build" ] && [ "$DIR_CR/src" = "$FONTE_CR" ]; then
        rm -rf "$DIR_CR/src/ui-linux/build"
    fi
    rm -rf "$DIR_CR"
    ok "interface e artefatos removidos de $DIR_CR"
    aviso "ficaram intactos: $HOME/.config/CloudRedirect (config, tokens e saves)"

    titulo "SLSsteam"
    despatch_steam "$HOME/.local/share/Steam/steam.sh"
    despatch_steam "$HOME/.steam/steam/steam.sh"
    rm -f "$HOME/.local/share/Steam/steam.sh.slssteam.bak" \
          "$HOME/.steam/steam/steam.sh.slssteam.bak"
    rm -rf "$DIR_SLS"
    ok "SLSsteam removido de $DIR_SLS"
    aviso "o config $HOME/.config/SLSsteam foi preservado"

    titulo "ASSella"
    rm -f "$DIR_APPS/assella.desktop"
    rm -f "$DIR_ICONS/assella.png"
    rm -f "$DIR_ASSELLA/ASSella.AppImage"
    rm -f "$DIR_ASSELLA/version"
    ok "ASSella removido de $DIR_ASSELLA"
    aviso "o banco e os manifestos em $DIR_ASSELLA foram preservados"

    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database -q "$DIR_APPS" || true
    fi

    printf "\n${c_green}Desinstalado.${c_reset} Os dados e saves continuam no lugar.\n"
}

main "$@"
