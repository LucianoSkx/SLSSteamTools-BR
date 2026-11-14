#!/usr/bin/env bash
# Trava a atualizacao do cliente Steam (steam.cfg) e compara a versao instalada
# com a compativel com o SLSsteam. Mecanismo portado do h3adcr-b.
#
# Uso:  curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/main/scripts/pin-client.sh | bash
#       ./scripts/pin-client.sh [pin|unpin|status]
set -euo pipefail

STEAM_DIR="$HOME/.steam/steam"
FLATPAK_DIR="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
ARQ_CFG="$STEAM_DIR/steam.cfg"
CLIENTE_COMPATIVEL="${CR_CLIENT_VERSION:-1794424036}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'
info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }

show_help() {
    cat <<'EOF'
Pin do cliente Steam (SLSsteam)

Uso: ./scripts/pin-client.sh [pin|unpin|status]

  pin      (padrao) cria/atualiza ~/.steam/steam/steam.cfg com
           BootStrapperInhibitAll=enable e BootStrapperForceSelfUpdate=disable
  unpin    remove essas chaves e devolve a atualizacao automatica a Steam
  status   mostra a versao do cliente instalado e se ela e compativel

Somente Steam nativa. Reinicie a Steam depois de pin/unpin.
EOF
    exit 0
}

checar_steam() {
    [ -d "$FLATPAK_DIR" ] && die "Steam flatpak detectada; este script so suporta Steam nativa"
    [ -d "$STEAM_DIR" ] || die "Steam nativa nao encontrada em $STEAM_DIR"
}

versao_cliente() {
    local f v
    for f in "$STEAM_DIR/package/steam_client_steamrt64.installed" \
             "$STEAM_DIR/package/steam_client_steamrt64.manifest" \
             "$STEAM_DIR/package/steam_client_ubuntu12.installed" \
             "$STEAM_DIR/package/steam_client_ubuntu12.manifest"; do
        [ -f "$f" ] || continue
        v="$(awk -F'"' '/"version"/ {print $4; exit}' "$f")"
        if [ -n "$v" ]; then
            printf '%s\n' "$v"
            return 0
        fi
    done
    return 1
}

travar() {
    local bkp tmp
    checar_steam
    if [ -f "$ARQ_CFG" ] \
        && grep -qx 'BootStrapperInhibitAll=enable' "$ARQ_CFG" \
        && grep -qx 'BootStrapperForceSelfUpdate=disable' "$ARQ_CFG"; then
        ok "steam.cfg ja esta travado"
        return 0
    fi
    if [ -f "$ARQ_CFG" ]; then
        bkp="$(mktemp "${ARQ_CFG}.instbackup-XXXXXX")" || die "impossivel criar backup de $ARQ_CFG"
        cp -p "$ARQ_CFG" "$bkp" || die "falha ao copiar $ARQ_CFG"
        tmp="$(mktemp "${ARQ_CFG}.tmp.XXXXXX")" || die "impossivel escrever em $STEAM_DIR"
        grep -vxE 'BootStrapperInhibitAll=.*|BootStrapperForceSelfUpdate=.*' "$ARQ_CFG" > "$tmp" || true
        printf 'BootStrapperInhibitAll=enable\nBootStrapperForceSelfUpdate=disable\n' >> "$tmp"
        mv -f "$tmp" "$ARQ_CFG" || die "falha ao gravar $ARQ_CFG"
        ok "steam.cfg atualizado (backup em $bkp)"
        return 0
    fi
    printf 'BootStrapperInhibitAll=enable\nBootStrapperForceSelfUpdate=disable\n' > "$ARQ_CFG"
    ok "steam.cfg criado em $ARQ_CFG"
}

destravar() {
    local tmp
    checar_steam
    if [ ! -f "$ARQ_CFG" ] || ! grep -qE '^(BootStrapperInhibitAll|BootStrapperForceSelfUpdate)=' "$ARQ_CFG"; then
        ok "steam.cfg sem as chaves do pin; nada a destravar"
        return 0
    fi
    tmp="$(mktemp "${ARQ_CFG}.tmp.XXXXXX")" || die "impossivel escrever em $STEAM_DIR"
    grep -vxE 'BootStrapperInhibitAll=.*|BootStrapperForceSelfUpdate=.*' "$ARQ_CFG" > "$tmp" || true
    if [ -s "$tmp" ]; then
        mv -f "$tmp" "$ARQ_CFG" || die "falha ao gravar $ARQ_CFG"
    else
        rm -f "$tmp" "$ARQ_CFG"
    fi
    ok "steam.cfg liberado; a Steam volta a se atualizar"
}

estado() {
    local versao
    checar_steam
    if ! versao="$(versao_cliente)"; then
        warn "manifesto do cliente nao encontrado em $STEAM_DIR/package"
        return 0
    fi
    info "cliente Steam: $versao (compativel com SLSsteam: $CLIENTE_COMPATIVEL)"
    if [ "$versao" = "$CLIENTE_COMPATIVEL" ]; then
        ok "versao do cliente compativel"
    else
        warn "cliente fora da versao compativel; rode o Headcrab Updater para realinhar"
    fi
    if [ -f "$ARQ_CFG" ] && grep -qx 'BootStrapperInhibitAll=enable' "$ARQ_CFG"; then
        ok "atualizacao do cliente travada"
    else
        warn "atualizacao do cliente liberada; rode '$0 pin' para travar"
    fi
}

case "${1:-pin}" in
    pin)    travar; estado ;;
    unpin)  destravar ;;
    status) estado ;;
    -h|--help) show_help ;;
    *) die "uso: $0 [pin|unpin|status]" ;;
esac
