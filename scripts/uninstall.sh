#!/usr/bin/env bash
# Removedor do CloudRedirect pt-BR (hook, CLI, UI e entrada de menu).
# Steam e SLSsteam nao sao tocados: eles pertencem ao h3adcr-b.
set -euo pipefail

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONES="$DIR_DADOS/icons/hicolor"
DIR_CR="$DIR_DADOS/CloudRedirect"

ASSUMIR="${CR_UNINSTALL_ASSUME:-0}"
VERBOSE="${VERBOSE:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

run_cmd() {
    if [ "$VERBOSE" = "1" ]; then "$@"; else "$@" >/dev/null 2>&1; fi
}

show_help() {
    cat <<'EOF'
Removedor do CloudRedirect pt-BR

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/uninstall.sh [opcoes]

Apaga o hook, a CLI e a UI do CloudRedirect, os icones e a entrada de menu.
Steam, SLSsteam e o launcher ficam como estao (responsabilidade do h3adcr-b).

Nao apaga dados: config, tokens OAuth, saves, backups e logs do CloudRedirect
continuam em ~/.config/CloudRedirect.

Opcoes:
  --yes, -y     nao pede confirmacao
  --verbose     mostra a saida dos comandos
  -h, --help    mostra esta ajuda
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
    read -r -p "Remover o CloudRedirect deste repositorio? (s/N) " r
    case "$r" in s|S|y|Y) return 0 ;; *) die "cancelado" ;; esac
}

main() {
    printf "${c_bold}Removedor do CloudRedirect pt-BR${c_reset}\n"
    confirmar

    titulo "Removendo CloudRedirect"
    run_cmd rm -f "$DIR_APPS/cloudredirect.desktop"
    local tam
    for tam in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
        run_cmd rm -f "$DIR_ICONES/$tam/apps/cloudredirect.png"
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        run_cmd gtk-update-icon-cache -f -t "$DIR_ICONES"
    fi
    run_cmd rm -rf "$DIR_CR"
    ok "hook, CLI, UI, icones e entrada de menu removidos"

    warn "intactos: ~/.config/CloudRedirect (config, tokens, saves, backups e logs)"
    warn "intactos: Steam, SLSsteam e o launcher (o h3adcr-b cuida deles)"
    if [ -f "$HOME/.steam/steam/steam.sh" ] \
        && grep -q 'CloudRedirect/cloud_redirect.so' "$HOME/.steam/steam/steam.sh"; then
        warn "o launcher ainda aponta para o .so removido; e inofensivo (o loader so avisa),"
        warn "e ele volta ao normal na proxima execucao do h3adcr-b"
    fi
}

main "$@"
