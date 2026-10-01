#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$PWD")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONS="$DIR_DADOS/icons/hicolor/256x256/apps"
DIR_SLS="$DIR_DADOS/SLSsteam"
DIR_CFG_SLS="$HOME/.config/SLSsteam"
DIR_CFG_SLS_FLATPAK="$HOME/.var/app/com.valvesoftware.Steam/.config/SLSsteam"
DIR_CR="$DIR_DADOS/CloudRedirect"
DIR_CR_APP="$DIR_CR/app"
DIR_CR_SRC="$DIR_CR/src"

MARCADOR_SLS="# --- SLSsteam injetado pelo instalador do CloudRedirect ---"
FIM_MARCADOR_SLS="# --- fim da injecao SLSsteam ---"

REPO_CR="https://github.com/LucianoSkx/cloudredirect-BR.git"
CR_BRANCH="${CR_BRANCH:-master}"

SKIP_DEPS="${CR_INSTALL_SKIP_DEPS:-0}"
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

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "comando ausente: $1"; }

show_help() {
    cat <<'EOF'
Instalador do SLSsteam + CloudRedirect (GUI nativa em pt-BR)

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/install.sh [opcoes]

Os dois andam juntos: o CloudRedirect implanta o hook de 32 bits na Steam pelo
LD_AUDIT que o SLSsteam instala, e precisa do DisableCloud: no no config do
SLSsteam para nao ser bloqueado.

Opcoes:
  --skip-deps     Nao instala as dependencias de sistema
  --verbose       Mostra a saida de todos os comandos
  -h, --help      Mostra esta ajuda

Variaveis de ambiente:
  CR_INSTALL_SKIP_DEPS=1   mesmo que --skip-deps
  VERBOSE=1                mesmo que --verbose
  CR_BRANCH=master         branch do repo a compilar
  GITHUB_TOKEN             token para a API do GitHub (evita o limite)
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        --verbose)   VERBOSE=1 ;;
        -h|--help)   show_help ;;
        *) die "opcao desconhecida: $arg (use --help)" ;;
    esac
done

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

api_github() {
    local path="$1" saida="$2"
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
             -H 'Accept: application/vnd.github+json' \
             -o "$saida" "https://api.github.com$path"
    else
        curl -fsSL -H 'Accept: application/vnd.github+json' \
             -o "$saida" "https://api.github.com$path"
    fi
}

baixar() {
    info "baixando $(basename "$2")"
    run_cmd curl -fL --retry 3 --retry-delay 2 -o "$2" "$1" || die "falha no download: $1"
}

install_deps() {
    info "instalando dependencias..."
    if   command -v pacman  >/dev/null 2>&1; then
        $SUDO pacman -S --noconfirm --needed \
            cmake git p7zip qt6-base desktop-file-utils
    elif command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update
        $SUDO apt-get install -y \
            cmake git p7zip-full qt6-base-dev build-essential desktop-file-utils
    elif command -v dnf     >/dev/null 2>&1; then
        $SUDO dnf install -y \
            cmake git p7zip qt6-qtbase-devel gcc-c++ desktop-file-utils
    else
        die "distro nao suportada (use Arch, Debian/Ubuntu ou Fedora)"
    fi
    ok "dependencias instaladas"
}

injetar_steam() {
    local sh="$1"
    local modo bak tmp
    modo="$(stat -c '%a' "$sh")"
    bak="$TMP/$(basename "$sh").orig"
    cp -a "$sh" "$bak"

    tmp="$TMP/steam.sh.novo"
    {
        IFS= read -r primeira
        printf '%s\n' "$primeira"
        printf '%s\n' "$MARCADOR_SLS"
        cat <<'INJ'
_SLS_DIR="$HOME/.local/share/SLSsteam"
_CR_SO="$HOME/.local/share/CloudRedirect/cloud_redirect.so"
if [ -f "$_SLS_DIR/library-inject.so" ] && [ -f "$_SLS_DIR/SLSsteam.so" ]; then
	export LD_AUDIT="$_SLS_DIR/library-inject.so:$_SLS_DIR/SLSsteam.so"
fi
[ -f "$_CR_SO" ] && export LD_PRELOAD="${LD_PRELOAD:+$LD_PRELOAD:}$_CR_SO"
INJ
        printf '%s\n' "$FIM_MARCADOR_SLS"
        cat
    } < "$sh" > "$tmp"

    chmod u+w "$sh"
    cat "$tmp" > "$sh"
    chmod "$modo" "$sh"
    cp -n "$bak" "$sh.slssteam.bak" 2>/dev/null || true
    ok "LD_AUDIT (SLSsteam) e LD_PRELOAD (CloudRedirect) injetados em $sh (backup em $sh.slssteam.bak)"
}

patch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 1

    if grep -q "$MARCADOR_SLS" "$sh"; then
        # Reescreve patches antigos: o cloud_redirect.so entra por LD_PRELOAD,
        # nunca por LD_AUDIT (quebra o ldd do client.sh).
        if grep -q 'LD_PRELOAD' "$sh" && grep -q 'cloud_redirect.so' "$sh"; then
            ok "patch do instalador ja presente em $sh"
        else
            warn "patch antigo em $sh; reescrevendo"
            despatch_steam "$sh"
            injetar_steam "$sh"
        fi
    else
        grep -q 'LD_AUDIT' "$sh" && \
            warn "$sh ja tem um patch de LD_AUDIT de outra ferramenta; o nosso sera escrito por cima"
        injetar_steam "$sh"
    fi
    return 0
}

despatch_steam() {
    local sh="$1"
    local tmp modo
    tmp="$(mktemp)"
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
}

liberar_cloud_no_sls() {
    local cfg="$1"
    mkdir -p "$(dirname "$cfg")"
    if [ ! -f "$cfg" ]; then
        if [ -f "$TMP/sls/res/config.yaml" ]; then
            cp "$TMP/sls/res/config.yaml" "$cfg"
        else
            printf 'DisableCloud: no\n' > "$cfg"
        fi
    fi
    if grep -q '^[[:space:]]*DisableCloud:' "$cfg"; then
        sed -i -E 's/^([[:space:]]*DisableCloud:).*/\1 no/' "$cfg"
    else
        printf '\nDisableCloud: no\n' >> "$cfg"
    fi
}

instalar_slssteam() {
    if [ -f "$DIR_SLS/SLSsteam.so" ]; then
        ok "SLSsteam ja presente em $DIR_SLS"
    else
        local SEVENZ
        SEVENZ="$(command -v 7z || command -v 7zz || command -v 7za || true)"
        [ -n "$SEVENZ" ] || die "7zip ausente (no Arch: p7zip; no Debian: p7zip-full)"

        info "consultando a ultima release..."
        api_github "/repos/AceSLS/SLSsteam/releases/latest" "$TMP/rel.json" \
            || die "nao foi possivel consultar a API do GitHub"
        local tag
        tag="$(grep -m1 '"tag_name"' "$TMP/rel.json" | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
        [ -n "$tag" ] || die "nao foi possivel ler a tag da release do SLSsteam"
        info "release: $tag"

        baixar "https://github.com/AceSLS/SLSsteam/releases/download/$tag/SLSsteam-Any-release.7z" \
               "$TMP/slssteam.7z"
        run_cmd "$SEVENZ" x -y "-o$TMP/sls" "$TMP/slssteam.7z"
        [ -f "$TMP/sls/setup.sh" ] || die "o pacote do SLSsteam nao veio com setup.sh"

        info "rodando o instalador oficial (setup.sh install)..."
        mkdir -p "$HOME/.config/fish/conf.d" 2>/dev/null || true
        ( cd "$TMP/sls" && bash ./setup.sh install ) || warn "o setup.sh oficial retornou erro"
        [ -f "$DIR_SLS/SLSsteam.so" ] || die "o instalador oficial nao instalou SLSsteam.so"
        ok "SLSsteam $tag instalado"
    fi

    # O setup.sh oficial nao grava o arquivo "version", que e de onde o ASSella
    # le a versao local. Sem ele o ASSella mostra "Unknown" na aba Health.
    if [ ! -f "$DIR_SLS/version" ]; then
        v="${tag:-}"
        if [ -z "$v" ]; then
            v="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
                https://api.github.com/repos/AceSLS/SLSsteam/releases/latest 2>/dev/null \
                | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
        fi
        if [ -n "$v" ]; then
            printf '%s\n' "$v" > "$DIR_SLS/version"
            ok "versao $v registrada em $DIR_SLS/version (para o ASSella)"
        else
            warn "nao foi possivel descobrir a versao do SLSsteam para o ASSella"
        fi
    fi

    liberar_cloud_no_sls "$DIR_CFG_SLS/config.yaml"
    ok "DisableCloud: no em $DIR_CFG_SLS/config.yaml"
    if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
        liberar_cloud_no_sls "$DIR_CFG_SLS_FLATPAK/config.yaml"
        ok "DisableCloud: no tambem no flatpak do Steam"
    fi
}

obter_fonte() {
    if [ -d "$SCRIPT_DIR/../ui-linux" ] && [ -d "$SCRIPT_DIR/../.git" ]; then
        FONTE="$(cd "$SCRIPT_DIR/.." && pwd)"
        info "usando o checkout local: $FONTE"
    elif [ -d "$DIR_CR_SRC/.git" ]; then
        info "atualizando o codigo em $DIR_CR_SRC"
        run_cmd git -C "$DIR_CR_SRC" fetch --depth 1 origin "$CR_BRANCH" \
            || die "falha ao buscar atualizacoes"
        run_cmd git -C "$DIR_CR_SRC" reset --hard "origin/$CR_BRANCH" \
            || die "falha ao atualizar o codigo"
        FONTE="$DIR_CR_SRC"
    else
        info "clonando o CloudRedirect pt-BR ($CR_BRANCH)..."
        mkdir -p "$DIR_CR"
        run_cmd git clone --depth 1 --branch "$CR_BRANCH" "$REPO_CR" "$DIR_CR_SRC" \
            || die "falha ao clonar $REPO_CR"
        FONTE="$DIR_CR_SRC"
    fi
}

instalar_cloudredirect() {
    obter_fonte

    info "compilando a interface (Qt6, pode demorar alguns minutos)..."
    run_cmd cmake -S "$FONTE/ui-linux" -B "$FONTE/ui-linux/build" \
        -DCMAKE_BUILD_TYPE=Release || die "falha no cmake configure"
    run_cmd cmake --build "$FONTE/ui-linux/build" --target cloud-redirect-ui \
        -j"$(nproc 2>/dev/null || echo 2)" || die "falha ao compilar a GUI"

    local gui="$FONTE/ui-linux/build/cloud-redirect-ui"
    [ -x "$gui" ] || die "binario da GUI nao encontrado em $gui"

    mkdir -p "$DIR_CR_APP"
    install -m 755 "$gui" "$DIR_CR_APP/cloud-redirect-ui"
    ok "GUI instalada em $DIR_CR_APP/cloud-redirect-ui"

    local arq
    for arq in cloud_redirect.so cloud_redirect_cli; do
        [ -f "$FONTE/$arq" ] || die "$arq nao encontrado no repositorio"
        install -m 755 "$FONTE/$arq" "$DIR_CR_APP/$arq"
    done
    if command -v file >/dev/null 2>&1; then
        file -b "$DIR_CR_APP/cloud_redirect.so" | grep -q 'ELF 32-bit' \
            || die "cloud_redirect.so nao e 32-bit; o runtime da Steam nao vai carregar"
    fi
    ok "cloud_redirect.so e cloud_redirect_cli (32 bits) ao lado da GUI"

    mkdir -p "$DIR_CR"
    for arq in cloud_redirect.so cloud_redirect_cli; do
        install -m 755 "$DIR_CR_APP/$arq" "$DIR_CR/$arq"
    done
    ok "CloudRedirect implantado em $DIR_CR"

    mkdir -p "$DIR_ICONS"
    for tam in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
        mkdir -p "$DIR_DADOS/icons/hicolor/$tam/apps"
        install -m 644 "$FONTE/ui-linux/src/cloudredirect.png" \
            "$DIR_DADOS/icons/hicolor/$tam/apps/cloudredirect.png"
    done
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        run_cmd gtk-update-icon-cache -f -t "$DIR_DADOS/icons/hicolor" || true
    fi

    mkdir -p "$DIR_APPS"
    cat > "$DIR_APPS/cloudredirect.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=CloudRedirect
GenericName=Gerenciador de saves na nuvem
Comment=Redireciona o Steam Cloud para provedores externos
Exec="$DIR_CR_APP/cloud-redirect-ui"
Icon=cloudredirect
Terminal=false
Categories=Game;
Keywords=steam;cloud;save;backup;sync;slssteam;
StartupNotify=true
EOF
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$DIR_APPS/cloudredirect.desktop" 2>&1 | grep -v '^$' | while read -r l; do
            warn "cloudredirect.desktop: $l"
        done || true
    fi
    ok "entrada de menu criada em $DIR_APPS/cloudredirect.desktop"
}

main() {
    need_cmd curl
    need_cmd git
    printf "${c_bold}Instalador do SLSsteam + CloudRedirect (pt-BR)${c_reset}\n"
    printf "Destino: %s\n" "$HOME"

    [ "$SKIP_DEPS" != "1" ] && install_deps

    titulo "1/2  SLSsteam"
    instalar_slssteam

    titulo "2/2  CloudRedirect"
    instalar_cloudredirect

    # O patch do steam.sh precisa rodar depois do cloud_redirect.so existir em
    # disco, senao o LD_AUDIT fica sem ele.
    local sh found=0
    for sh in "$HOME/.local/share/Steam/steam.sh" "$HOME/.steam/steam/steam.sh"; do
        if patch_steam "$sh"; then found=1; fi
    done
    [ "$found" = 1 ] || warn "steam.sh nao encontrado; so o wrapper e o .desktop do instalador oficial injetam o LD_AUDIT"

    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database -q "$DIR_APPS" || true
    fi

    titulo "Pronto"
    cat <<EOF
  SLSsteam      $DIR_SLS
  CloudRedirect $DIR_CR_APP/cloud-redirect-ui

Reinicie a Steam para o LD_AUDIT valer, e abra o CloudRedirect pelo menu. O
provedor de nuvem se configura na aba Provedor; Google Drive e OneDrive pedem
autorizacao pelo navegador na primeira vez.
EOF
}

main "$@"
