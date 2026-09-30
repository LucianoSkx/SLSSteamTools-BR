#!/usr/bin/env bash
set -euo pipefail

# Remove o ASSella pelo desinstalador oficial do upstream.
# Nao apaga o banco, os manifestos nem as chaves de depot.
# Uso: ./scripts/remove-assella.sh [--yes] [--verbose] [--help]
#
# O ASSella nao tem link de instalacao aqui: o proprio upstream mantem o dele,
#   curl -fsSL https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh | bash
# Este script so devolve o app para o estado anterior, usando o mesmo caminho.

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONS="$DIR_DADOS/icons/hicolor/256x256/apps"
DIR_ASSELLA="$DIR_DADOS/ACCELA"
ASSELLA_INSTALL_URL="https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh"

ASSUMIR="${ASSELLA_REMOVE_ASSUME:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_bold='\033[1m'

ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
aviso(){ printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

show_help() {
    cat <<'EOF'
Removedor do ASSella

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/remove-assella.sh [opcoes]

Usa o desinstalador do proprio upstream. O banco, os manifestos e as chaves de
depot sao preservados; so o app, a entrada de menu e o icone saem.

Opcoes:
  --yes, -y     nao pede confirmacao
  -h, --help    Mostra esta ajuda
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y)  ASSUMIR=1 ;;
        -h|--help) show_help ;;
        *) die "opcao desconhecida: $arg" ;;
    esac
done

confirmar() {
    [ "$ASSUMIR" = "1" ] && return 0
    [ -t 0 ] || die "execucao nao interativa: rode com --yes"
    local r
    read -r -p "Remover o ASSella? (s/N) " r
    case "$r" in s|S|y|Y) return 0 ;; *) die "cancelado" ;; esac
}

main() {
    printf "${c_bold}Removedor do ASSella${c_reset}\n"
    confirmar

    titulo "Rodando o desinstalador oficial"
    if curl -fsSL -o "$TMP/assella-install.sh" "$ASSELLA_INSTALL_URL" 2>/dev/null; then
        bash "$TMP/assella-install.sh" --uninstall || aviso "o desinstalador oficial falhou"
    else
        # Sem o script em maos, o que ele faria:
        aviso "nao foi possivel baixar o desinstalador; removendo os arquivos"
        rm -f "$DIR_APPS/accela.desktop" "$DIR_ICONS/accela.png" \
              "$DIR_ASSELLA/ACCELA.AppImage" "$DIR_ASSELLA/ASSella.AppImage" \
              "$DIR_ASSELLA/version"
    fi
    ok "ASSella removido de $DIR_ASSELLA"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$DIR_APPS" 2>/dev/null || true
    fi

    aviso "o banco e os manifestos em $DIR_ASSELLA foram preservados"
    printf "\n${c_green}ASSella removido.${c_reset} Para instalar de novo:\n"
    printf "  curl -fsSL %s | bash\n" "$ASSELLA_INSTALL_URL"
}

main "$@"
