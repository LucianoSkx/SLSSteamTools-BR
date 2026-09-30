#!/usr/bin/env bash
set -euo pipefail

# Remove o CloudRedirect. Nao apaga dados: config, tokens, saves e backups ficam.
# Uso: ./scripts/remove-cloudredirect.sh [--yes] [--verbose] [--help]

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONS="$DIR_DADOS/icons/hicolor/256x256/apps"
DIR_CR="$DIR_DADOS/CloudRedirect"

ASSUMIR="${CR_REMOVE_ASSUME:-0}"
VERBOSE="${VERBOSE:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
aviso(){ printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

show_help() {
    cat <<'EOF'
Removedor do CloudRedirect

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/remove-cloudredirect.sh [opcoes]

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
    read -r -p "Remover o CloudRedirect? (s/N) " r
    case "$r" in s|S|y|Y) return 0 ;; *) die "cancelado" ;; esac
}

main() {
    printf "${c_bold}Removedor do CloudRedirect${c_reset}\n"
    confirmar

    titulo "Removendo"
    rm -f "$DIR_APPS/cloudredirect.desktop"
    rm -f "$DIR_ICONS/cloudredirect.png"
    rm -rf "$DIR_CR"
    ok "interface, hook e CLI removidos de $DIR_CR"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$DIR_APPS" 2>/dev/null || true
    fi

    aviso "ficaram intactos: $HOME/.config/CloudRedirect (config, tokens, saves e backups)"
    printf "\n${c_green}CloudRedirect removido.${c_reset} Os saves continuam.\n"
}

main "$@"
