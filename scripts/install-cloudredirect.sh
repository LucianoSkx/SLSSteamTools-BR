#!/usr/bin/env bash
set -euo pipefail

# Instalador do CloudRedirect (GUI nativa em pt-BR) desta fork.
# Uso: ./scripts/install-cloudredirect.sh [--skip-deps] [--verbose] [--help]

# Via "curl ... | bash" o bash le o script do stdin e nao existe BASH_SOURCE,
# entao caimos no diretorio de onde o comando foi chamado.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$PWD")"

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONS="$DIR_DADOS/icons/hicolor/256x256/apps"
DIR_CR="$DIR_DADOS/CloudRedirect"
DIR_CR_APP="$DIR_CR/app"
DIR_CR_SRC="$DIR_CR/src"

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
Instalador do CloudRedirect (GUI nativa em pt-BR)

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/install-cloudredirect.sh [opcoes]

Compila a interface Qt6 desta fork, instala o hook e a CLI, e cria a entrada
de menu. Precisa do SLSsteam instalado para conseguir implanta-lo.

Opcoes:
  --skip-deps     Nao instala as dependencias de sistema
  --verbose       Mostra a saida de todos os comandos
  -h, --help      Mostra esta ajuda

Variaveis de ambiente:
  CR_INSTALL_SKIP_DEPS=1   mesmo que --skip-deps
  VERBOSE=1                mesmo que --verbose
  CR_BRANCH=master         branch do repo a compilar
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

install_deps() {
    info "instalando dependencias..."
    if   command -v pacman  >/dev/null 2>&1; then
        $SUDO pacman -S --noconfirm --needed cmake git qt6-base desktop-file-utils
    elif command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update
        $SUDO apt-get install -y cmake git qt6-base-dev build-essential desktop-file-utils
    elif command -v dnf     >/dev/null 2>&1; then
        $SUDO dnf install -y cmake git qt6-qtbase-devel gcc-c++ desktop-file-utils
    else
        die "distro nao suportada (use Arch, Debian/Ubuntu ou Fedora)"
    fi
    ok "dependencias instaladas"
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

validar_desktop() {
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$1" 2>&1 | grep -v '^$' | while read -r linha; do
            warn "$(basename "$1"): $linha"
        done || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database -q "$DIR_APPS" || true
    fi
}

main() {
    need_cmd curl
    need_cmd git
    printf "${c_bold}Instalador do CloudRedirect (GUI nativa em pt-BR)${c_reset}\n"
    printf "Destino: %s\n" "$DIR_CR"

    [ "$SKIP_DEPS" != "1" ] && install_deps

    titulo "Baixando o codigo"
    obter_fonte

    titulo "Compilando a interface (Qt6, pode demorar alguns minutos)"
    need_cmd cmake
    run_cmd cmake -S "$FONTE/ui-linux" -B "$FONTE/ui-linux/build" \
        -DCMAKE_BUILD_TYPE=Release || die "falha no cmake configure"
    run_cmd cmake --build "$FONTE/ui-linux/build" --target cloud-redirect-ui \
        -j"$(nproc 2>/dev/null || echo 2)" || die "falha ao compilar a GUI"

    local gui="$FONTE/ui-linux/build/cloud-redirect-ui"
    [ -x "$gui" ] || die "binario da GUI nao encontrado em $gui"

    titulo "Instalando"
    mkdir -p "$DIR_CR_APP"
    install -m 755 "$gui" "$DIR_CR_APP/cloud-redirect-ui"
    ok "GUI instalada em $DIR_CR_APP/cloud-redirect-ui"

    # O .so e a CLI de 32 bits ja vem commitados no repositorio.
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

    # Isto e o mesmo que o botao Instalar da aba Montagem faz.
    mkdir -p "$DIR_CR"
    for arq in cloud_redirect.so cloud_redirect_cli; do
        install -m 755 "$DIR_CR_APP/$arq" "$DIR_CR/$arq"
    done
    ok "CloudRedirect implantado em $DIR_CR"

    mkdir -p "$DIR_ICONS"
    install -m 644 "$FONTE/ui-linux/src/cloudredirect.png" "$DIR_ICONS/cloudredirect.png"

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
    validar_desktop "$DIR_APPS/cloudredirect.desktop"
    ok "entrada de menu criada em $DIR_APPS/cloudredirect.desktop"

    titulo "Pronto"
    if [ ! -f "$DIR_DADOS/SLSsteam/SLSsteam.so" ]; then
        warn "o SLSsteam nao esta instalado; o CloudRedirect so implanta com ele"
        warn "  curl -fsSL https://raw.githubusercontent.com/LucianoSkx/cloudredirect-BR/master/scripts/install-slssteam.sh | bash"
    fi
    cat <<EOF
Abra o CloudRedirect pelo menu. O provedor de nuvem se configura na aba
Provedor; Google Drive e OneDrive pedem autorizacao pelo navegador na
primeira vez.
EOF
}

main "$@"
