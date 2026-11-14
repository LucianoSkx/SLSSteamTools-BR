#!/usr/bin/env bash
# Registra o "Headcrab Updater" no menu de aplicativos: atualiza Steam e
# SLSsteam rodando o instalador do h3adcr-b num terminal.
#
# Uso:  curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/install-updater.sh | bash
#       ./scripts/install-updater.sh [--remove]
set -euo pipefail

APPS_DIR="$HOME/.local/share/applications"
ICONE_DIR="$HOME/.local/share/icons/hicolor/48x48/apps"
DESKTOP="$APPS_DIR/headcrab.desktop"
ICONE="$ICONE_DIR/headcrab.png"
UPDATER_URL="https://raw.githubusercontent.com/Deadboy666/h3adcr-b/main/headcrab.sh"
ICONE_URL="https://raw.githubusercontent.com/Deadboy666/h3adcr-b-modul3s/main/headcrab.png"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'
info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }

show_help() {
    cat <<'EOF'
Headcrab Updater

Uso: ./scripts/install-updater.sh [--remove]

  (sem opcao)  instala icone e entrada "Headcrab Updater" no menu
  --remove     apaga a entrada e o icone

A entrada abre um terminal e roda o instalador do h3adcr-b, que atualiza
Steam e SLSsteam. O CloudRedirect nao e tocado.
EOF
    exit 0
}

atualizar_menu() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$APPS_DIR" >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    fi
}

instalar() {
    local tmp
    mkdir -p "$APPS_DIR" "$ICONE_DIR"
    tmp="$(mktemp "$ICONE.XXXXXX")" || die "impossivel escrever em $ICONE_DIR"
    curl -fsSL --retry 3 --connect-timeout 15 -o "$tmp" "$ICONE_URL" || die "falha ao baixar $ICONE_URL"
    mv -f "$tmp" "$ICONE"
    chmod 644 "$ICONE"
    cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Headcrab Updater
Comment=Atualiza Steam e SLSsteam (h3adcr-b)
Exec=bash -c 'curl -fsSL $UPDATER_URL | bash'
Icon=headcrab
Terminal=true
Categories=Utility;Application;
EOF
    chmod 755 "$DESKTOP"
    atualizar_menu
    ok "Headcrab Updater instalado em $DESKTOP"
}

remover() {
    rm -f "$DESKTOP" "$ICONE"
    atualizar_menu
    ok "Headcrab Updater removido"
}

for arg in "$@"; do
    case "$arg" in
        --remove)  remover; exit 0 ;;
        -h|--help) show_help ;;
        *) die "opcao desconhecida: $arg" ;;
    esac
done

instalar
