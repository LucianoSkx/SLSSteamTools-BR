#!/usr/bin/env bash
set -euo pipefail

# Instalador do SLSsteam, pelo setup.sh oficial do upstream.
# Uso: ./scripts/install-slssteam.sh [--skip-deps] [--verbose] [--help]

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_SLS="$DIR_DADOS/SLSsteam"
DIR_CFG_SLS="$HOME/.config/SLSsteam"
DIR_CFG_SLS_FLATPAK="$HOME/.var/app/com.valvesoftware.Steam/.config/SLSsteam"

MARCADOR_SLS="# --- SLSsteam injetado pelo instalador do CloudRedirect ---"
FIM_MARCADOR_SLS="# --- fim da injecao SLSsteam ---"

SKIP_DEPS="${SLS_INSTALL_SKIP_DEPS:-0}"
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
Instalador do SLSsteam (AceSLS/SLSsteam)

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/install-slssteam.sh [opcoes]

Baixa a release oficial e roda o setup.sh de dentro do pacote. Ele copia os
binarios 32 bits, cria o wrapper path/steam e o steam.desktop com o LD_AUDIT.
Alem disso deixamos DisableCloud: no, que e o padrao que trava o CloudRedirect.

Opcoes:
  --skip-deps     Nao instala as dependencias de sistema
  --verbose       Mostra a saida de todos os comandos
  -h, --help      Mostra esta ajuda

Variaveis de ambiente:
  SLS_INSTALL_SKIP_DEPS=1   mesmo que --skip-deps
  VERBOSE=1                 mesmo que --verbose
  GITHUB_TOKEN              token para a API do GitHub (evita o limite de requisicoes)
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
    info "baixando $(basename "$2")"
    run_cmd curl -fL --retry 3 --retry-delay 2 -o "$2" "$1" || die "falha no download: $1"
}

install_deps() {
    info "instalando dependencias..."
    if   command -v pacman  >/dev/null 2>&1; then
        $SUDO pacman -S --noconfirm --needed p7zip desktop-file-utils
    elif command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get install -y p7zip-full desktop-file-utils
    elif command -v dnf     >/dev/null 2>&1; then
        $SUDO dnf install -y p7zip desktop-file-utils
    else
        die "distro nao suportada (use Arch, Debian/Ubuntu ou Fedora)"
    fi
    ok "dependencias instaladas"
}

# Injeta o LD_AUDIT no steam.sh. O arquivo da Valve vem com modo 555, entao
# precisa de chmod antes de escrita.
#
# Idempotencia e pelo nosso marcador, nao por "existe LD_AUDIT": o h3adcr-b
# tambem patcheia o mesmo arquivo com o mesmo valor, e depender do patch de
# outro faz o SLSsteam parar de funcionar junto com aquele desinstalador.
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
    cp -n "$bak" "$sh.slssteam.bak" 2>/dev/null || true
    ok "LD_AUDIT injetado em $sh (backup em $sh.slssteam.bak)"
}

patch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 1

    if grep -q "$MARCADOR_SLS" "$sh"; then
        ok "patch do instalador ja presente em $sh"
    else
        grep -q 'LD_AUDIT' "$sh" && \
            warn "$sh ja tem um patch de LD_AUDIT de outra ferramenta; o nosso sera escrito por cima"
        injetar_steam "$sh"
    fi
    return 0
}

# O padrao do SLSsteam e DisableCloud: yes, que trava o CloudRedirect.
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

main() {
    need_cmd curl
    printf "${c_bold}Instalador do SLSsteam (AceSLS/SLSsteam)${c_reset}\n"
    printf "Destino: %s\n" "$DIR_SLS"

    if [ "$SKIP_DEPS" != "1" ]; then
        install_deps
    else
        local SEVENZ
        SEVENZ="$(command -v 7z || command -v 7zz || command -v 7za || true)"
        [ -n "$SEVENZ" ] || die "7zip ausente (no Arch: p7zip; no Debian: p7zip-full)"
    fi

    if [ -f "$DIR_SLS/SLSsteam.so" ]; then
        ok "SLSsteam ja presente em $DIR_SLS"
    else
        titulo "Baixando a release oficial"
        local SEVENZ
        SEVENZ="$(command -v 7z || command -v 7zz || command -v 7za || true)"
        [ -n "$SEVENZ" ] || die "7zip ausente (no Arch: p7zip; no Debian: p7zip-full)"

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

        titulo "Rodando o instalador oficial (setup.sh install)"
        # O setup.sh oficial usa caminhos relativos (./bin/SLSsteam.so), entao
        # precisa rodar com o diretorio de trabalho no pacote extraido. Ele ainda
        # sai com codigo 0 mesmo falhando, por isso conferimos o .so depois.
        mkdir -p "$HOME/.config/fish/conf.d" 2>/dev/null || true
        ( cd "$TMP/sls" && bash ./setup.sh install ) || warn "o setup.sh oficial retornou erro"
        [ -f "$DIR_SLS/SLSsteam.so" ] || die "o instalador oficial nao instalou SLSsteam.so"
        ok "SLSsteam $tag instalado"
    fi

    # O setup.sh oficial nao mexe no steam.sh: ele injeta o LD_AUDIT no wrapper
    # path/steam e no .desktop. Quem chama a Steam direto (digitando "steam", ou
    # por outro .desktop) nao passa por nenhum dos dois, entao garantimos o
    # LD_AUDIT no steam.sh tambem. Patch de outra ferramenta e respeitado.
    titulo "Garantindo o LD_AUDIT no steam.sh"
    local sh found=0
    for sh in "$HOME/.local/share/Steam/steam.sh" "$HOME/.steam/steam/steam.sh"; do
        if patch_steam "$sh"; then found=1; fi
    done
    [ "$found" = 1 ] || warn "steam.sh nao encontrado; o SLSsteam so carrega pelo wrapper e pelo .desktop do instalador oficial"

    titulo "Configurando"
    liberar_cloud_no_sls "$DIR_CFG_SLS/config.yaml"
    ok "DisableCloud: no em $DIR_CFG_SLS/config.yaml"
    if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
        liberar_cloud_no_sls "$DIR_CFG_SLS_FLATPAK/config.yaml"
        ok "DisableCloud: no tambem no flatpak do Steam"
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database -q "$DIR_APPS" || true
    fi

    titulo "Pronto"
    warn "Feche a Steam completamente e abra de novo para o SLSsteam passar a valer"
}

main "$@"
