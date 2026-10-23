#!/usr/bin/env bash
# ============================================================================
#  Instalador do CloudRedirect pt-BR (hook 32-bit + CLI + UI Qt6).
#
#  Steam e SLSsteam NAO sao instalados aqui: quem cuida disso e o instalador
#  do h3adcr-b, chamado por este script. Aqui entram apenas o cloud_redirect.so
#  e o cloud_redirect_cli deste repositorio, a UI Qt6 nativa, os icones e a
#  entrada de menu.
#
#  Uso:  curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/install.sh | bash
# ============================================================================
set -euo pipefail

# ── Caminhos ───────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
ApplicationDirectory=$HOME/.local/share/applications
IconRoot=$HOME/.local/share/icons/hicolor
CloudRedirectDir=$HOME/.local/share/CloudRedirect
CloudRedirectAppDir=$CloudRedirectDir/app
SteamInstallDir=$HOME/.steam/steam
FlatpakSteamInstallDir=$HOME/.var/app/com.valvesoftware.Steam/.steam/steam

# ── URLs ───────────────────────────────────────────────────────────────────
Headcrab_URL="${HEADCRAB_URL:-https://headcrab.pages.dev}"
CR_BRANCH="${CR_BRANCH:-main}"
REPO_CR="https://github.com/LucianoSkx/SLSSteamTools-BR.git"
CR_REL="https://github.com/LucianoSkx/SLSSteamTools-BR/releases/download/latest"
CloudRedirectLib="$CR_REL/cloud_redirect.so"
CloudRedirectCLI="$CR_REL/cloud_redirect_cli"

# ── Cores e mensagens ──────────────────────────────────────────────────────
c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'
info()  { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()   { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo(){ printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Download atomico (temp + mv): nunca deixa arquivo parcial no destino.
baixar() {
    local url="$1" alvo="$2"
    curl -fsSL --retry 3 --connect-timeout 15 -o "$TMP/dl.$$" "$url" \
        || die "falha ao baixar $url"
    mv -f "$TMP/dl.$$" "$alvo"
}

checar_requisitos() {
    local falta=0 cmd
    for cmd in curl git cmake; do
        command -v "$cmd" >/dev/null 2>&1 || { warn "falta o comando: $cmd"; falta=1; }
    done
    [ "$falta" -eq 0 ] || die "instale as dependencias acima e rode de novo"

    if [ -d "$FlatpakSteamInstallDir" ]; then
        die "Steam flatpak detectada; este instalador so suporta Steam nativa"
    fi
    [ -d "$SteamInstallDir" ] || die "Steam nativa nao encontrada em $SteamInstallDir"

    pkg-config --exists Qt6Core Qt6Quick 2>/dev/null \
        || die "Qt6 (Core/Quick/QuickControls2/DBus/Network) nao encontrado; instale o pacote de desenvolvimento"
}

rodar_headcrab() {
    titulo "1/2  Steam + SLSsteam (h3adcr-b)"
    baixar "$Headcrab_URL" "$TMP/headcrab.sh"
    if : 2>/dev/null </dev/tty; then
        bash "$TMP/headcrab.sh" </dev/tty || die "o instalador do h3adcr-b falhou"
    else
        bash "$TMP/headcrab.sh" </dev/null || die "o instalador do h3adcr-b falhou"
    fi
    ok "Steam e SLSsteam entregues ao h3adcr-b"
}

obter_fonte_cr() {
    if [ -d "$SCRIPT_DIR/../ui-linux" ] && [ -d "$SCRIPT_DIR/../.git" ]; then
        FONTE_CR="$(cd "$SCRIPT_DIR/.." && pwd)"
        return 0
    fi

    FONTE_CR="$CloudRedirectDir/src"
    if [ -d "$FONTE_CR/.git" ]; then
        info "atualizando o checkout em $FONTE_CR"
        git -C "$FONTE_CR" fetch --depth 1 origin "$CR_BRANCH" || die "falha ao buscar $CR_BRANCH"
        git -C "$FONTE_CR" reset --hard "origin/$CR_BRANCH" || die "falha ao atualizar"
    else
        info "clonando $REPO_CR ($CR_BRANCH) em $FONTE_CR"
        mkdir -p "$CloudRedirectDir"
        git clone --depth 1 --branch "$CR_BRANCH" "$REPO_CR" "$FONTE_CR" || die "falha ao clonar $REPO_CR"
    fi
}

instalar_cr() {
    titulo "2/2  CloudRedirect"
    obter_fonte_cr
    mkdir -p "$CloudRedirectDir" "$CloudRedirectAppDir" "$ApplicationDirectory"

    info "baixando hook e CLI ($CR_BRANCH)"
    baixar "$CloudRedirectLib" "$CloudRedirectDir/cloud_redirect.so"
    baixar "$CloudRedirectCLI" "$CloudRedirectDir/cloud_redirect_cli"
    chmod 755 "$CloudRedirectDir/cloud_redirect.so"
    chmod 755 "$CloudRedirectDir/cloud_redirect_cli"
    if command -v file >/dev/null 2>&1; then
        file -b "$CloudRedirectDir/cloud_redirect.so" | grep -q 'ELF 32-bit' \
            || die "cloud_redirect.so nao e 32-bit; o runtime da Steam nao vai carregar"
    fi
    install -m 755 "$CloudRedirectDir/cloud_redirect.so" "$CloudRedirectAppDir/cloud_redirect.so"
    install -m 755 "$CloudRedirectDir/cloud_redirect_cli" "$CloudRedirectAppDir/cloud_redirect_cli"

    info "compilando a UI Qt6 (pode demorar)"
    cmake -S "$FONTE_CR/ui-linux" -B "$FONTE_CR/ui-linux/build" -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1
    cmake --build "$FONTE_CR/ui-linux/build" --target cloud-redirect-ui \
        -j"$(nproc 2>/dev/null || echo 2)" >/dev/null
    [ -x "$FONTE_CR/ui-linux/build/cloud-redirect-ui" ] || die "binario da UI nao encontrado"
    install -m 755 "$FONTE_CR/ui-linux/build/cloud-redirect-ui" "$CloudRedirectAppDir/cloud-redirect-ui"

    local tam
    for tam in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
        mkdir -p "$IconRoot/$tam/apps"
        install -m 644 "$FONTE_CR/ui-linux/src/cloudredirect.png" "$IconRoot/$tam/apps/cloudredirect.png"
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$IconRoot" >/dev/null 2>&1 || true
    fi

    cat > "$ApplicationDirectory/cloudredirect.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=CloudRedirect
GenericName=Gerenciador de saves na nuvem
Comment=Redireciona o Steam Cloud para provedores externos
Exec="$CloudRedirectAppDir/cloud-redirect-ui"
Icon=cloudredirect
Terminal=false
Categories=Game;
EOF
    chmod 755 "$ApplicationDirectory/cloudredirect.desktop"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$ApplicationDirectory" >/dev/null 2>&1 || true
    fi
    ok "hook, CLI e UI instalados em $CloudRedirectDir"
}

conferir_launcher() {
    local launcher="$SteamInstallDir/steam.sh"
    if [ -f "$launcher" ] && grep -q 'CloudRedirect/cloud_redirect.so' "$launcher"; then
        ok "o launcher da Steam carrega o CloudRedirect"
        return 0
    fi
    warn "o launcher em $launcher nao carrega o CloudRedirect."
    warn "isso e definido pelo h3adcr-b, que so liga o hook com 'DisableCloud: no' no"
    warn "~/.config/SLSsteam/config.yaml. Habilite e rode o h3adcr-b de novo."
}

main() {
    printf "${c_bold}CloudRedirect pt-BR${c_reset}\n"
    checar_requisitos
    rodar_headcrab
    instalar_cr
    conferir_launcher

    printf "\n"
    ok "pronto. Reinicie a Steam; a UI abre pelo menu ou por $CloudRedirectAppDir/cloud-redirect-ui"
    if command -v flatpak >/dev/null 2>&1 \
        && flatpak list --user --app --columns=application 2>/dev/null | grep -qx 'org.cloudredirect.CloudRedirect'; then
        warn "o h3adcr-b instalou o app flatpak do CloudRedirect; a UI deste repo e a nativa."
        warn "para remover o duplicado: flatpak uninstall --user org.cloudredirect.CloudRedirect"
    fi
}

main "$@"
