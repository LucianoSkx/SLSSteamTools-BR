#!/usr/bin/env bash
set -euo pipefail

# Remove o SLSsteam, incluindo o que o instalador oficial criou.
# Nao apaga o config.yaml, para o app voltar com as mesmas preferencias.
# Uso: ./scripts/remove-slssteam.sh [--yes] [--verbose] [--help]

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DIR_DADOS="$HOME/.local/share"
DIR_APPS="$DIR_DADOS/applications"
DIR_SLS="$DIR_DADOS/SLSsteam"

MARCADOR_SLS="# --- SLSsteam injetado pelo instalador do CloudRedirect ---"
FIM_MARCADOR_SLS="# --- fim da injecao SLSsteam ---"

ASSUMIR="${SLS_REMOVE_ASSUME:-0}"
VERBOSE="${VERBOSE:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
aviso(){ printf "${c_yellow}[aviso]${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

show_help() {
    cat <<'EOF'
Removedor do SLSsteam

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/remove-slssteam.sh [opcoes]

Desfaz o patch do steam.sh, apaga os binarios 32 bits, o wrapper, o
steam.desktop patcheado e o PATH do fish. O config.yaml e preservado.

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
    read -r -p "Remover o SLSsteam? (s/N) " r
    case "$r" in s|S|y|Y) return 0 ;; *) die "cancelado" ;; esac
}

# Desfaz o patch do instalador, sem mexer no resto do arquivo e sem tocar em
# patch de outra ferramenta. Deduplica por inode: os dois caminhos do steam.sh
# costumam ser o mesmo arquivo.
declare -A VISTOS=()
despatch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 0

    local inode; inode="$(stat -c '%i' "$sh")"
    [ -n "${VISTOS[$inode]:-}" ] && return 0
    VISTOS[$inode]=1

    grep -q 'LD_AUDIT' "$sh" && grep -q 'SLSsteam\.so' "$sh" || return 0

    if ! grep -q "$MARCADOR_SLS" "$sh"; then
        aviso "$sh tem um patch do SLSsteam de outra ferramenta; preservado como esta"
        return 0
    fi

    local tmp modo; tmp="$(mktemp)"
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
    ok "patch do instalador removido de $sh"
}

main() {
    printf "${c_bold}Removedor do SLSsteam${c_reset}\n"
    confirmar

    titulo "Desfazendo o patch do steam.sh"
    despatch_steam "$HOME/.local/share/Steam/steam.sh"
    despatch_steam "$HOME/.steam/steam/steam.sh"
    rm -f "$HOME/.local/share/Steam/steam.sh.slssteam.bak" \
          "$HOME/.steam/steam/steam.sh.slssteam.bak"

    titulo "Removendo"
    # Artefatos do instalador oficial: .desktop patcheado e PATH do fish.
    rm -f "$DIR_APPS/steam.desktop" "$DIR_APPS/steam-native.desktop" \
          "$HOME/.config/fish/conf.d/SLSsteam.fish"
    rm -rf "$DIR_SLS"
    ok "binarios e wrapper removidos de $DIR_SLS"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$DIR_APPS" 2>/dev/null || true
    fi

    aviso "o config $HOME/.config/SLSsteam foi preservado"
    printf "\n${c_green}SLSsteam removido.${c_reset} Reinicie a Steam.\n"
}

main "$@"
