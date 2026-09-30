#!/usr/bin/env bash
set -euo pipefail

# Instalador do conjunto SLSsteam + CloudRedirect (GUI nativa em pt-BR) + ASSella.
# Uso: ./scripts/install.sh [--skip-deps] [--verbose] [--help]

# Via "curl ... | bash" o bash le o script do stdin e nao existe BASH_SOURCE,
# entao caimos no diretorio de onde o comando foi chamado.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "$PWD")"

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_ICONS="$DIR_DADOS/icons/hicolor/256x256/apps"

DIR_SLS="$DIR_DADOS/SLSsteam"
DIR_CFG_SLS="$HOME/.config/SLSsteam"
DIR_CFG_SLS_FLATPAK="$HOME/.var/app/com.valvesoftware.Steam/.config/SLSsteam"

DIR_CR="$DIR_DADOS/CloudRedirect"
DIR_CR_APP="$DIR_CR/app"
DIR_CR_SRC="$DIR_CR/src"

# O app upstream grava em ACCELA (1 L): src/utils/settings.py, APP_NAME.
DIR_ASSELLA="$DIR_DADOS/ACCELA"

MARCADOR_SLS="# --- SLSsteam injetado pelo instalador do CloudRedirect ---"
FIM_MARCADOR_SLS="# --- fim da injecao SLSsteam ---"

REPO_CR="https://github.com/LucianoSkx/cloudredirect-BR.git"
ASSELLA_INSTALL_URL="https://raw.githubusercontent.com/niwia/ASSella/beta/install.sh"
CR_BRANCH="${CR_BRANCH:-master}"

SKIP_DEPS="${CR_INSTALL_SKIP_DEPS:-0}"
VERBOSE="${VERBOSE:-0}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

# Silencioso por padrao, verboso com VERBOSE=1
run_cmd() {
    if [ "$VERBOSE" = "1" ]; then "$@"; else "$@" >/dev/null 2>&1; fi
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "comando ausente: $1"; }

show_help() {
    cat <<'EOF'
Instalador do SLSsteam + CloudRedirect (pt-BR) + ASSella

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/install.sh [opcoes]

Opcoes:
  --skip-deps     Nao instala as dependencias de sistema
  --verbose       Mostra a saida de todos os comandos
  -h, --help      Mostra esta ajuda

Variaveis de ambiente:
  CR_INSTALL_SKIP_DEPS=1   mesmo que --skip-deps
  VERBOSE=1                mesmo que --verbose
  GITHUB_TOKEN             token para a API do GitHub (evita o limite de requisicoes)
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

# Grava a resposta num arquivo em vez de canear para um pipe: com pipefail, um
# grep -m1 fechando o pipe antes do fim faz o curl sair com erro 23 (EPIPE).
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
    local url="$1" dest="$2"
    info "baixando $(basename "$dest")"
    run_cmd curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url" \
        || die "falha no download: $url"
}

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

detect_pkg_manager() {
    if   command -v pacman   >/dev/null 2>&1; then echo pacman
    elif command -v apt-get  >/dev/null 2>&1; then echo apt
    elif command -v dnf      >/dev/null 2>&1; then echo dnf
    else die "distro nao suportada (use Arch, Debian/Ubuntu ou Fedora)"
    fi
}

install_deps() {
    local pm; pm="$(detect_pkg_manager)"
    info "instalando dependencias via $pm..."
    case "$pm" in
        pacman)
            $SUDO pacman -S --noconfirm --needed \
                cmake git p7zip qt6-base desktop-file-utils fuse2
            ;;
        apt)
            $SUDO apt-get update
            $SUDO apt-get install -y \
                cmake git p7zip-full qt6-base-dev build-essential \
                desktop-file-utils libfuse2
            ;;
        dnf)
            $SUDO dnf install -y \
                cmake git p7zip qt6-qtbase-devel gcc-c++ desktop-file-utils \
                fuse-libs
            ;;
    esac
    ok "dependencias instaladas"
}

# ─────────────────────────────────────────────────────────────────────────────
#  SLSsteam
# ─────────────────────────────────────────────────────────────────────────────

# Injeta o LD_AUDIT no steam.sh. O arquivo da Valve vem com modo 555, entao
# precisa de chmod antes de escrita.
#
# Idempotencia e pelo nosso marcador, nao por "existe LD_AUDIT": o h3adcr-b
# tambem patcheia o mesmo arquivo com o mesmo valor, e depender do patch de
# outro faz o SLSsteam parar de funcionar junto com aquele desinstalador.
# Os dois convivem: reexportar o mesmo valor nao muda nada.
patch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 1

    if grep -q "$MARCADOR_SLS" "$sh"; then
        ok "patch do instalador ja presente em $sh"
    else
        if grep -q 'LD_AUDIT' "$sh"; then
            warn "$sh ja tem um patch de LD_AUDIT de outra ferramenta (provavelmente h3adcr-b)"
            warn "  o patch do instalador sera escrito por cima; os dois usam o mesmo valor"
        fi
        injetar_steam "$sh"
    fi

    # O h3adcr-b exporta de novo dentro de GameLauncher(), mais tarde. Mesmo
    # valor, entao nao ha conflito; mas ele nao e nosso e pode sumir.
    grep -q 'INJECT_SLS' "$sh" && \
        warn "esse patch ainda depende do h3adcr-b em $sh; se remove-lo, rode o instalador de novo"
    return 0
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
if [ -f "$_SLS_DIR/library-inject.so" ] && [ -f "$_SLS_DIR/SLSsteam.so" ]; then
	export LD_AUDIT="$_SLS_DIR/library-inject.so:$_SLS_DIR/SLSsteam.so"
fi
INJ
        printf '%s\n' "$FIM_MARCADOR_SLS"
        cat
    } < "$sh" > "$tmp"

    chmod u+w "$sh"
    cat "$tmp" > "$sh"
    chmod "$modo" "$sh"

    # Backup do lado do usuário, do lado do steam.sh de verdade.
    cp -n "$bak" "$sh.slssteam.bak" 2>/dev/null || true
    ok "LD_AUDIT injetado em $sh (backup em $sh.slssteam.bak)"
}

# O padrao do SLSsteam e DisableCloud: yes, o que trava o CloudRedirect.
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
    titulo "SLSsteam (AceSLS/SLSsteam)"

    # Delegamos a instalacao ao setup.sh oficial do pacote, como fazemos com o
    # ASSella. Ele copia os .so, cria o wrapper path/steam e o steam.desktop
    # com o LD_AUDIT ja embutido.
    if [ -f "$DIR_SLS/SLSsteam.so" ]; then
        ok "SLSsteam ja presente em $DIR_SLS"
    else
        local SEVENZ
        SEVENZ="$(command -v 7z || command -v 7zz || command -v 7za || true)"
        [ -n "$SEVENZ" ] || die "7zip ausente (no Arch: p7zip; no Debian: p7zip-full)"

        info "consultando a ultima release..."
        api_github "/repos/AceSLS/SLSsteam/releases/latest" "$TMP/sls-rel.json" \
            || die "nao foi possivel consultar a API do GitHub"
        tag="$(grep -m1 '"tag_name"' "$TMP/sls-rel.json" | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
        [ -n "$tag" ] || die "nao foi possivel ler a tag da release do SLSsteam"
        info "release: $tag"

        baixar "https://github.com/AceSLS/SLSsteam/releases/download/$tag/SLSsteam-Any-release.7z" \
               "$TMP/slssteam.7z"

        run_cmd "$SEVENZ" x -y "-o$TMP/sls" "$TMP/slssteam.7z"
        [ -f "$TMP/sls/setup.sh" ] || die "o pacote do SLSsteam nao veio com setup.sh"

        info "rodando o instalador oficial (setup.sh install)..."
        # O setup.sh oficial usa caminhos relativos (./bin/SLSsteam.so), entao
        # precisa rodar com o diretorio de trabalho dentro do pacote extraido.
        # Ele ainda sai com codigo 0 mesmo falhando, por isso conferimos o .so.
        mkdir -p "$HOME/.config/fish/conf.d" 2>/dev/null || true
        ( cd "$TMP/sls" && bash ./setup.sh install ) || warn "o setup.sh oficial retornou erro"
        [ -f "$DIR_SLS/SLSsteam.so" ] || die "o instalador oficial do SLSsteam nao instalou SLSsteam.so"
        ok "SLSsteam $tag instalado pelo instalador oficial"
    fi

    # O setup.sh oficial nao mexe no steam.sh: ele injeta o LD_AUDIT no wrapper
    # path/steam e no .desktop. Quem chama a Steam direto (digitando "steam", ou
    # via outro .desktop) nao passa por nenhum dos dois, entao garantimos o
    # LD_AUDIT no steam.sh tambem. Respeitamos patch de outra ferramenta e
    # mantemos o nosso proprio como rede de seguranca.
    local sh found=0
    for sh in "$HOME/.local/share/Steam/steam.sh" "$HOME/.steam/steam/steam.sh"; do
        if patch_steam "$sh"; then found=1; fi
    done
    [ "$found" = 1 ] || warn "steam.sh nao encontrado; o SLSsteam so sera carregado pelo wrapper e pelo .desktop do instalador oficial"

    liberar_cloud_no_sls "$DIR_CFG_SLS/config.yaml"
    ok "DisableCloud: no em $DIR_CFG_SLS/config.yaml"

    if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
        liberar_cloud_no_sls "$DIR_CFG_SLS_FLATPAK/config.yaml"
        ok "DisableCloud: no tambem no flatpak do Steam"
    fi

    warn "Feche a Steam completely e abra de novo para o SLSsteam passar a valer"
}

# ─────────────────────────────────────────────────────────────────────────────
#  CloudRedirect (GUI nativa, pt-BR)
# ─────────────────────────────────────────────────────────────────────────────

obter_fonte_cr() {
    if [ -d "$SCRIPT_DIR/../ui-linux" ] && [ -d "$SCRIPT_DIR/../.git" ]; then
        FONTE_CR="$(cd "$SCRIPT_DIR/.." && pwd)"
        info "usando o checkout local: $FONTE_CR"
    elif [ -d "$DIR_CR_SRC/.git" ]; then
        info "atualizando o codigo em $DIR_CR_SRC"
        run_cmd git -C "$DIR_CR_SRC" fetch --depth 1 origin "$CR_BRANCH" \
            || die "falha ao buscar atualizacoes"
        run_cmd git -C "$DIR_CR_SRC" reset --hard "origin/$CR_BRANCH" \
            || die "falha ao atualizar o codigo"
        FONTE_CR="$DIR_CR_SRC"
    else
        info "clonando o CloudRedirect pt-BR ($CR_BRANCH)..."
        mkdir -p "$DIR_CR"
        run_cmd git clone --depth 1 --branch "$CR_BRANCH" "$REPO_CR" "$DIR_CR_SRC" \
            || die "falha ao clonar $REPO_CR"
        FONTE_CR="$DIR_CR_SRC"
    fi
}

instalar_cloudredirect() {
    titulo "CloudRedirect (GUI nativa em pt-BR)"

    need_cmd cmake
    need_cmd git
    obter_fonte_cr

    info "compilando a interface (Qt6, pode demorar alguns minutos)..."
    run_cmd cmake -S "$FONTE_CR/ui-linux" -B "$FONTE_CR/ui-linux/build" \
        -DCMAKE_BUILD_TYPE=Release || die "falha no cmake configure"
    run_cmd cmake --build "$FONTE_CR/ui-linux/build" --target cloud-redirect-ui \
        -j"$(nproc 2>/dev/null || echo 2)" || die "falha ao compilar a GUI"

    local gui="$FONTE_CR/ui-linux/build/cloud-redirect-ui"
    [ -x "$gui" ] || die "binario da GUI nao encontrado em $gui"

    mkdir -p "$DIR_CR_APP"
    install -m 755 "$gui" "$DIR_CR_APP/cloud-redirect-ui"
    ok "GUI instalada em $DIR_CR_APP/cloud-redirect-ui"

    # O .so e a CLI de 32 bits ja vem commitados no repositorio.
    local arq
    for arq in cloud_redirect.so cloud_redirect_cli; do
        [ -f "$FONTE_CR/$arq" ] || die "$arq nao encontrado no repositorio"
        install -m 755 "$FONTE_CR/$arq" "$DIR_CR_APP/$arq"
    done
    if command -v file >/dev/null 2>&1; then
        file -b "$DIR_CR_APP/cloud_redirect.so" | grep -q 'ELF 32-bit' \
            || die "cloud_redirect.so nao e 32-bit; o runtime da Steam nao vai carregar"
    fi
    ok "cloud_redirect.so e cloud_redirect_cli (32 bits) ao lado da GUI"

    # Isto e o mesmo que o botao "Instalar" da aba Montagem faz.
    mkdir -p "$DIR_CR"
    for arq in cloud_redirect.so cloud_redirect_cli; do
        install -m 755 "$DIR_CR_APP/$arq" "$DIR_CR/$arq"
    done
    ok "CloudRedirect implantado em $DIR_CR"

    mkdir -p "$DIR_ICONS"
    install -m 644 "$FONTE_CR/ui-linux/src/cloudredirect.png" "$DIR_ICONS/cloudredirect.png"

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
}

# ─────────────────────────────────────────────────────────────────────────────
#  ASSella
# ─────────────────────────────────────────────────────────────────────────────

# Delegamos ao instalador oficial em vez de reimplementar: e ele que escolhe a
# release, baixa o AppImage e cria o .desktop e o icone. Assim o caminho, a
# versao e o ACCELA.AppImage.bak se mantem em dia junto com o upstream.
instalar_assella() {
    titulo "ASSella (niwia/ASSella)"

    info "rodando o instalador oficial..."
    curl -fsSL -o "$TMP/assella-install.sh" "$ASSELLA_INSTALL_URL" \
        || die "nao foi possivel baixar o instalador do ASSella"
    bash "$TMP/assella-install.sh" --install \
        || die "o instalador do ASSella falhou"

    ok "ASSella instalado pelo instalador oficial"
}

# ─────────────────────────────────────────────────────────────────────────────
#  comum
# ─────────────────────────────────────────────────────────────────────────────

validar_desktop() {
    local f="$1"
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$f" 2>&1 | grep -v '^$' | while read -r linha; do
            warn "$(basename "$f"): $linha"
        done || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database -q "$DIR_APPS" || true
    fi
}

main() {
    need_cmd curl
    need_cmd git

    printf "${c_bold}Instalador SLSsteam + CloudRedirect (pt-BR) + ASSella${c_reset}\n"
    printf "Destino: %s\n" "$HOME"

    if [ "$SKIP_DEPS" != "1" ]; then
        install_deps
    fi

    instalar_slssteam
    instalar_cloudredirect
    instalar_assella

    titulo "Pronto"
    cat <<EOF
  SLSsteam      $DIR_SLS
  CloudRedirect $DIR_CR_APP/cloud-redirect-ui
  ASSella       $DIR_ASSELLA/ASSella.AppImage

Abra a Steam pelo menu (ela precisa reiniciar para pegar o SLSsteam) e depois
abra o CloudRedirect pelo menu. O provedor de nuvem se configura na aba
Provedor; a sincronizacao com o Google Drive ou OneDrive pede autorizacao
pelo navegador na primeira vez.
EOF
}

main "$@"
