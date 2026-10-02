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
DIR_SLS_FLATPAK="$HOME/.var/app/com.valvesoftware.Steam/.local/share/SLSsteam"
DIR_CR="$DIR_DADOS/CloudRedirect"
DIR_CR_APP="$DIR_CR/app"
DIR_CR_SRC="$DIR_CR/src"
DIR_HEADCRAB="$HOME/.headcrab"

# Pilares herdados do h3adcr-b (Deadboy666/h3adcr-b): o cliente Steam fica
# travado na versao compativel com o SLSsteam, e o steam.cfg impede que ele
# se autoatualize e quebre o hook.
PIN_CLIENT="${CR_PIN_CLIENT:-1}"
CLIENT_VER="${CR_CLIENT_VER:-1788652215}"

URL_MANIFEST_LINUX="https://cdn.jsdelivr.net/gh/Deadboy666/SteamTracking@refs/heads/headcrab/ClientManifest/steam_client_ubuntu12"
URL_SOURCES="https://cdn.jsdelivr.net/gh/Deadboy666/h3adcr-b-modul3s@refs/heads/main/stable-sources.txt"
URL_DGSC="https://github.com/Deadboy666/h3adcr-b-modul3s/raw/refs/heads/main/dgsc"
URL_CLIENT_SH="https://cdn.jsdelivr.net/gh/Deadboy666/SteamTracking@refs/heads/master/ClientExtracted/steam.sh"
URL_NETSOCK="https://cdn.jsdelivr.net/gh/yesyes0649/steamnetsock-patch@builds/fix.so"
URL_DOWNGRADE="http://localhost:1666/"

MARCADOR_SLS="# --- SLSsteam injetado pelo instalador do CloudRedirect ---"
FIM_MARCADOR_SLS="# --- fim da injecao SLSsteam ---"

REPO_CR="https://github.com/LucianoSkx/cloudredirect-BR.git"
CR_BRANCH="${CR_BRANCH:-master}"

SKIP_DEPS="${CR_INSTALL_SKIP_DEPS:-0}"
VERBOSE="${VERBOSE:-0}"
UPDATE_SLS="${CR_UPDATE_SLS:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'

info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo() { printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

run_cmd() {
    if [ "$VERBOSE" = "1" ]; then "$@"; else "$@" >/dev/null 2>&1; fi
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "comando ausente: $1"; }

show_help() {
    cat <<'EOF'
Instalador do SLSsteam + CloudRedirect (GUI nativa em pt-BR, modo h3adcr-b)

Uso: curl -fsSL <url> | bash -s -- [opcoes]
     ./scripts/install.sh [opcoes]

Trava o cliente Steam na versao compativel com o SLSsteam (rebaixa via
servidor de depot local quando preciso) e grava o steam.cfg para a Steam
nao se autoatualizar e quebrar o hook. O SLSsteam entra por extracao
direta da release oficial com merge do config; o steam.sh e substituido
pelo lancador com LD_AUDIT. O CloudRedirect e o build pt-BR deste repo.

Opcoes:
  --skip-deps       Nao instala as dependencias de sistema
  --update-sls      Reinstala o SLSsteam na ultima release mesmo se ja existir
  --no-pin-client   Nao trava nem rebaixa o cliente Steam (nao recomendado)
  --verbose         Mostra a saida de todos os comandos
  -h, --help        Mostra esta ajuda

Variaveis de ambiente:
  CR_INSTALL_SKIP_DEPS=1   mesmo que --skip-deps
  CR_UPDATE_SLS=1          mesmo que --update-sls
  CR_PIN_CLIENT=0          mesmo que --no-pin-client
  CR_CLIENT_VER=...        versao do cliente Steam a travar (padrao: a do h3adcr-b)
  VERBOSE=1                mesmo que --verbose
  CR_BRANCH=master         branch do repo a compilar
  GITHUB_TOKEN             token para a API do GitHub (evita o limite)
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        --update-sls) UPDATE_SLS=1 ;;
        --no-pin-client) PIN_CLIENT=0 ;;
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

# Ultima tag do SLSsteam sem depender so da API (que tem cota de 60 req/h
# sem token e faz o ASSella mostrar "Version Unknown" na aba Health).
# Tenta a API primeiro (com GITHUB_TOKEN se houver) e cai para a URL de
# redirect do latest, que nao consome cota da API.
ultima_tag_sls() {
    local rel_tmp tag redir
    rel_tmp="$(mktemp)" || return 1
    if api_github "/repos/AceSLS/SLSsteam/releases/latest" "$rel_tmp" 2>/dev/null; then
        tag="$(grep -m1 '"tag_name"' "$rel_tmp" 2>/dev/null | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
        rm -f "$rel_tmp"
        [ -n "$tag" ] && { printf '%s\n' "$tag"; return 0; }
    fi
    rm -f "$rel_tmp"
    redir="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        https://github.com/AceSLS/SLSsteam/releases/latest 2>/dev/null)" || return 1
    tag="${redir##*/}"
    [ -n "$tag" ] && [ "$tag" != "latest" ] && { printf '%s\n' "$tag"; return 0; }
    return 1
}

baixar() {
    info "baixando $(basename "$2")"
    run_cmd curl -fL --retry 3 --retry-delay 2 -o "$2" "$1" || die "falha no download: $1"
}

matar_steam() {
    info "encerrando a Steam..."
    killall -q steam steamwebhelper 2>/dev/null || true
    sleep 2
}

# Raizes do cliente Steam, sem duplicar (nativo costuma ser o mesmo inode
# em ~/.steam/steam e ~/.local/share/Steam).
raizes_steam() {
    local cand raiz
    for cand in "$HOME/.steam/steam" "$HOME/.local/share/Steam" \
               "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"; do
        [ -d "$cand" ] || continue
        raiz="$(realpath "$cand" 2>/dev/null || echo "$cand")"
        printf '%s\n' "$raiz"
    done | awk '!visto[$0]++'
}

versao_cliente() {
    local raiz="$1" man ver
    for man in steam_client_ubuntu12.manifest steam_client_publicbeta_ubuntu12.manifest \
               steam_client_steamdeck_stable_ubuntu12.manifest; do
        [ -f "$raiz/package/$man" ] || continue
        ver="$(grep -m1 '"version"' "$raiz/package/$man" 2>/dev/null \
               | sed -E 's/.*"version"[[:space:]]*"([0-9]+)".*/\1/')"
        [ -n "$ver" ] && { printf '%s\n' "$ver"; return 0; }
    done
    return 1
}

garantir_steam_cfg() {
    local raiz="$1" cfg="$raiz/steam.cfg"
    if [ -f "$cfg" ]; then
        ok "steam.cfg ja existe em $raiz (updates travados)"
        return 0
    fi
    cat > "$cfg" <<'EOF'
BootStrapperInhibitAll=enable
BootStrapperForceSelfUpdate=disable
EOF
    ok "steam.cfg criado em $raiz (autoupdate da Steam desativado)"
}

remover_pacote_slssteam() {
    local pkgs
    command -v pacman >/dev/null 2>&1 || return 0
    pkgs="$(pacman -Qq 2>/dev/null | grep -E '^slssteam(-git)?$' || true)"
    [ -n "$pkgs" ] || return 0
    warn "removendo pacote de sistema do SLSsteam: $pkgs"
    $SUDO pacman -Rns --noconfirm $pkgs \
        || die "falha ao remover $pkgs"
}

desativar_wrapper_sls() {
    local alvo
    for alvo in "$DIR_SLS/path/steam" "$DIR_SLS_FLATPAK/path/steam"; do
        if [ -e "$alvo" ] && [ ! -L "$alvo" ]; then
            mv -f "$alvo" "$alvo.bak"
            ok "wrapper do instalador oficial desativado ($alvo.bak)"
        fi
    done
}

# Trava o cliente na versao compativel: se divergir, rebaixa pelo servidor
# de depot local (dgsc), como o h3adcr-b faz.
travar_cliente_steam() {
    if [ "$PIN_CLIENT" != "1" ]; then
        info "travamento do cliente desativado (--no-pin-client)"
        return 0
    fi

    local raiz ver man_tmp src_tmp dgsc
    while IFS= read -r raiz; do
        [ -n "$raiz" ] || continue
        [ -d "$raiz/package" ] || { warn "sem pasta package em $raiz; pulando"; continue; }

        ver="$(versao_cliente "$raiz" || true)"
        if [ "$ver" = "$CLIENT_VER" ]; then
            ok "cliente Steam compativel em $raiz ($ver)"
            garantir_steam_cfg "$raiz"
            continue
        fi

        warn "cliente em $raiz na versao ${ver:-desconhecida}; compativel: $CLIENT_VER"
        warn "rebaixando o cliente (a Steam sera encerrada)..."

        man_tmp="$TMP/steam_client_ubuntu12.manifest"
        src_tmp="$TMP/sources.txt"
        baixar "$URL_MANIFEST_LINUX" "$man_tmp"
        baixar "$URL_SOURCES" "$src_tmp"
        ver="$(grep -m1 '"version"' "$man_tmp" | sed -E 's/.*"version"[[:space:]]*"([0-9]+)".*/\1/')"
        [ "$ver" = "$CLIENT_VER" ] \
            || die "manifesto remoto na versao $ver, esperado $CLIENT_VER; abortando antes de mexer no package/"
        [ -s "$src_tmp" ] || die "sources.txt vazio; abortando"

        mkdir -p "$DIR_HEADCRAB"
        dgsc="$DIR_HEADCRAB/dgsc"
        if [ ! -x "$dgsc" ]; then
            baixar "$URL_DGSC" "$dgsc"
            chmod +x "$dgsc"
        fi

        matar_steam
        rm -f "$raiz/package"/*
        cp "$man_tmp" "$src_tmp" "$raiz/package/"
        ( cd "$raiz/package" && "$dgsc" --port 1666 --silent &> /dev/null & )
        sleep 1

        local lancador
        case "$raiz" in
            *com.valvesoftware.Steam*)
                lancador="flatpak run com.valvesoftware.Steam" ;;
            *)
                lancador="$(command -v steam || true)"
                [ -n "$lancador" ] || die "comando steam nao encontrado no PATH" ;;
        esac
        # shellcheck disable=SC2086
        run_cmd timeout 900 env -u LD_AUDIT -u LD_PRELOAD $lancador \
            -forcesteamupdate -forcepackagedownload \
            -overridepackageurl "$URL_DOWNGRADE" -exitsteam \
            || warn "atualizacao forcada retornou erro; confira a versao abaixo"
        pkill -f "$dgsc" 2>/dev/null || true

        ver="$(versao_cliente "$raiz" || true)"
        [ "$ver" = "$CLIENT_VER" ] \
            || die "cliente ainda em ${ver:-desconhecida}; rebaixamento falhou"
        ok "cliente travado em $CLIENT_VER"
        garantir_steam_cfg "$raiz"
    done < <(raizes_steam)
}

# Merge do config novo preservando as chaves do usuario (modo h3adcr-b).
mesclar_config_sls() {
    local cfg="$1" modelo="$2" tmp_cfg bkp
    [ -f "$modelo" ] || return 0
    grep -q '^DisableFamilyShareLock:' "$modelo" \
        || { warn "modelo de config invalido; mantido o atual"; return 0; }
    [ -f "$cfg" ] || { cp "$modelo" "$cfg"; return 0; }

    tmp_cfg="$(mktemp "${cfg}.tmp.XXXXXX")" || return 0
    if ! awk '
        NR == FNR {
            if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*:/) {
                key = $0
                sub(/:.*/, "", key)
                current = key
                if (!(key in present)) { order[++n] = key }
                present[key] = 1
                saved[key] = $0 ORS
                next
            }
            if (current != "" && $0 ~ /^[[:space:]]+/) {
                saved[current] = saved[current] $0 ORS
            }
            next
        }
        /^[A-Za-z_][A-Za-z0-9_]*:/ {
            key = $0
            sub(/:.*/, "", key)
            printf "%s", prefix
            prefix = ""
            if (key in present) {
                printf "%s", saved[key]
                emitted[key] = 1
                use_template = 0
            } else {
                print
                use_template = 1
            }
            have_key = 1
            next
        }
        have_key && /^[[:space:]]+/ {
            if (use_template) { print }
            next
        }
        { prefix = prefix $0 ORS }
        END {
            for (i = 1; i <= n; i++) {
                k = order[i]
                if (!(k in emitted)) { printf "%s", saved[k] }
            }
            printf "%s", prefix
        }
    ' "$cfg" "$modelo" > "$tmp_cfg"; then
        warn "merge do config falhou; mantido o atual"
        rm -f "$tmp_cfg"
        return 0
    fi
    grep -q '^DisableFamilyShareLock:' "$tmp_cfg" \
        || { warn "merge do config invalido; mantido o atual"; rm -f "$tmp_cfg"; return 0; }
    if cmp -s "$cfg" "$tmp_cfg"; then
        rm -f "$tmp_cfg"
        return 0
    fi
    bkp="${cfg}.instbackup-$(date +%Y%m%d-%H%M%S)"
    cp -a "$cfg" "$bkp"
    mv -f "$tmp_cfg" "$cfg"
    ok "config mesclado com o novo modelo (backup em $bkp)"
}

baixar_netsock() {
    local dir="$DIR_CFG_SLS/tools/netsock"
    mkdir -p "$dir"
    if [ -s "$dir/netsock.so" ]; then
        ok "netsock ja presente"
        return 0
    fi
    baixar "$URL_NETSOCK" "$dir/netsock.so"
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

    garantir_notificacao_sls "$cfg"
}

garantir_notificacao_sls() {
    local cfg="$1" val atual novo
    [ -f "$cfg" ] || return 0

    if grep -q '^[[:space:]]*NotifyInit:' "$cfg"; then
        sed -i -E 's/^([[:space:]]*NotifyInit:).*/\1 yes/' "$cfg"
    else
        printf '\nNotifyInit: yes\n' >> "$cfg"
    fi

    val="$(awk '/^[[:space:]]*LogLevels:/ {print $2; exit}' "$cfg")"
    if [ -z "$val" ]; then
        printf '\nLogLevels: 0xff\n' >> "$cfg"
        return 0
    fi
    case "$val" in
        0[xX][0-9a-fA-F]*|[0-9]*) ;;
        *)
            warn "LogLevels '$val' fora do esperado em $cfg; nao alterado"
            return 0
            ;;
    esac
    atual=$((val))
    novo=$((atual | 0xc0))
    if [ "$novo" -ne "$atual" ]; then
        sed -i -E "s/^([[:space:]]*LogLevels:[[:space:]]*)[^#[:space:]]*/\1$(printf '0x%x' "$novo")/" "$cfg"
        ok "LogLevels $(printf '0x%x' "$atual") -> $(printf '0x%x' "$novo") em $cfg (notificacoes ligadas)"
    fi
}

instalar_slssteam() {
    if [ "$UPDATE_SLS" != "1" ] && [ -f "$DIR_SLS/SLSsteam.so" ]; then
        ok "SLSsteam ja presente em $DIR_SLS"
    else
        local SEVENZ
        SEVENZ="$(command -v 7z || command -v 7zz || command -v 7za || true)"
        [ -n "$SEVENZ" ] || die "7zip ausente (no Arch: p7zip; no Debian: p7zip-full)"

        matar_steam

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
        [ -s "$TMP/sls/bin/SLSsteam.so" ] \
            || die "o pacote do SLSsteam veio sem bin/SLSsteam.so"

        mesclar_config_sls "$DIR_CFG_SLS/config.yaml" "$TMP/sls/res/config.yaml"
        if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
            mesclar_config_sls "$DIR_CFG_SLS_FLATPAK/config.yaml" "$TMP/sls/res/config.yaml"
        fi

        mkdir -p "$DIR_SLS"
        cp -f "$TMP/sls/bin/"* "$DIR_SLS/"
        [ -s "$DIR_SLS/SLSsteam.so" ] || die "falha ao copiar o SLSsteam.so"
        if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
            mkdir -p "$DIR_SLS_FLATPAK"
            cp -f "$TMP/sls/bin/"* "$DIR_SLS_FLATPAK/"
        fi
        ok "SLSsteam $tag instalado por extracao direta"
        # O binario recem-instalado e exatamente o da tag: registra na hora,
        # sem depender de uma segunda consulta a API.
        printf '%s\n' "$tag" > "$DIR_SLS/version"
        ok "versao $tag registrada em $DIR_SLS/version (para o ASSella)"
    fi

    baixar_netsock

    # O setup.sh oficial nao grava o arquivo "version", que e de onde o ASSella
    # le a versao local. Sem ele a aba SLS mostra "Installed (Version Unknown)"
    # e a aba Health nao tem com o que comparar (vira "Unknown" quando a API
    # do GitHub tambem falha por rate limit: 60 req/h sem token).
    if [ ! -s "$DIR_SLS/version" ]; then
        v="$(ultima_tag_sls 2>/dev/null || true)"
        if [ -n "$v" ]; then
            printf '%s\n' "$v" > "$DIR_SLS/version"
            ok "versao $v registrada em $DIR_SLS/version (para o ASSella)"
        else
            warn "nao foi possivel descobrir a versao do SLSsteam para o ASSella (API com rate limit e redirect falhou; exporte GITHUB_TOKEN e rode de novo)"
        fi
    fi

    liberar_cloud_no_sls "$DIR_CFG_SLS/config.yaml"
    ok "DisableCloud: no em $DIR_CFG_SLS/config.yaml"
    if [ -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
        liberar_cloud_no_sls "$DIR_CFG_SLS_FLATPAK/config.yaml"
        ok "DisableCloud: no tambem no flatpak do Steam"
    fi
}

garantir_plugins_yes() {
    local cfg="$1"
    mkdir -p "$(dirname "$cfg")"
    [ -f "$cfg" ] || { printf 'Plugins: yes\n' > "$cfg"; return 0; }
    if grep -qE '^[[:space:]]*Plugins:' "$cfg"; then
        sed -i -E 's/^([[:space:]]*Plugins:).*/\1 yes/' "$cfg"
    else
        printf '\nPlugins: yes\n' >> "$cfg"
    fi
}

# Copia os .lua de sls-plugins/ para cada config dir do SLSsteam e liga
# Plugins: yes. Roda depois de obter_fonte, pois a origem e o proprio repo.
instalar_plugins_sls() {
    local origem="${FONTE:-}/sls-plugins"
    if [ ! -d "$origem" ]; then
        warn "pasta sls-plugins ausente em ${FONTE:-?}; pulando plugins Lua"
        return 0
    fi
    local dir
    for dir in "$DIR_CFG_SLS" "$DIR_CFG_SLS_FLATPAK"; do
        if [ "$dir" = "$DIR_CFG_SLS_FLATPAK" ] && [ ! -d "$HOME/.var/app/com.valvesoftware.Steam" ]; then
            continue
        fi
        mkdir -p "$dir/plugins"
        cp -f "$origem"/*.lua "$dir/plugins/"
        garantir_plugins_yes "$dir/config.yaml"
        ok "plugins Lua em $dir/plugins (Plugins: yes)"
    done
}

# Lancador estilo h3adcr-b com o hook do nosso CloudRedirect BR junto.
escrever_steam_cr() {
    local sh="$1" raiz
    raiz="$(cd "$(dirname "$sh")" && pwd)"
    cat > "$sh" <<EOF
#!/bin/sh
# Gerado pelo instalador SLSsteam + CloudRedirect pt-BR (modo h3adcr-b).
# O steam.sh original esta em steam.sh.slssteam.bak; o scripts/uninstall.sh
# do repositorio restaura tudo.
_SLS_DIR="\$HOME/.local/share/SLSsteam"
_CR_SO="\$HOME/.local/share/CloudRedirect/cloud_redirect.so"
if [ -s "\$_SLS_DIR/SLSsteam.so" ]; then
    export LD_AUDIT="\$_SLS_DIR/library-inject.so:\$_SLS_DIR/SLSsteam.so"
fi
[ -s "\$_CR_SO" ] && export LD_PRELOAD="\${LD_PRELOAD:+\$LD_PRELOAD:}\$_CR_SO"
_CLIENT_SH="$raiz/client.sh"
if [ -f "\$_CLIENT_SH" ]; then
    . "\$_CLIENT_SH" "\$@"
else
    echo "client.sh nao encontrado em \$_CLIENT_SH; restaure steam.sh.slssteam.bak" >&2
    exit 1
fi
EOF
}

# Migracao pontual do formato antigo (bloco com marcadores) para o novo.
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

patch_steam() {
    local sh="$1"
    [ -f "$sh" ] || return 1

    if grep -q "$MARCADOR_SLS" "$sh"; then
        warn "removendo patch antigo com marcadores de $sh"
        despatch_steam "$sh"
    elif grep -q 'LD_AUDIT' "$sh" && grep -q 'SLSsteam\.so' "$sh"; then
        warn "$sh ja tem um patch de LD_AUDIT de outra ferramenta; sera substituido"
    fi

    cp -n "$sh" "$sh.slssteam.bak" 2>/dev/null || true

    local raiz client="$TMP/client.sh"
    raiz="$(cd "$(dirname "$sh")" && pwd)"
    if baixar "$URL_CLIENT_SH" "$client"; then
        install -m 644 "$client" "$raiz/client.sh"
    elif [ ! -f "$raiz/client.sh" ]; then
        die "falha ao baixar o client.sh e nenhum anterior em $raiz"
    else
        warn "mantido o client.sh anterior em $raiz"
    fi

    chmod u+w "$sh"
    escrever_steam_cr "$sh"
    chmod 555 "$sh"
    ok "steam.sh substituido em $sh (original em $sh.slssteam.bak)"
    return 0
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

main() {
    need_cmd curl
    need_cmd git
    printf "${c_bold}Instalador do SLSsteam + CloudRedirect (pt-BR, modo h3adcr-b)${c_reset}\n"
    printf "Destino: %s\n" "$HOME"

    [ "$SKIP_DEPS" != "1" ] && install_deps

    titulo "1/4  Cliente Steam"
    remover_pacote_slssteam
    desativar_wrapper_sls
    travar_cliente_steam

    titulo "2/4  SLSsteam"
    instalar_slssteam

    titulo "3/4  CloudRedirect BR"
    instalar_cloudredirect

    titulo "4/4  Plugins Lua do SLSsteam"
    instalar_plugins_sls

    # O steam.sh precisa ser escrito depois do cloud_redirect.so existir em
    # disco, senao o lancador referencia um hook ausente.
    local sh found=0
    for sh in "$HOME/.local/share/Steam/steam.sh" "$HOME/.steam/steam/steam.sh" \
              "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steam.sh"; do
        if patch_steam "$sh"; then found=1; fi
    done
    [ "$found" = 1 ] || warn "steam.sh nao encontrado; a Steam nao sera hookada"

    if command -v update-desktop-database >/dev/null 2>&1; then
        run_cmd update-desktop-database -q "$DIR_APPS" || true
    fi

    titulo "Pronto"
    cat <<EOF
  Cliente Steam   travado em $CLIENT_VER (steam.cfg bloqueia updates)
  SLSsteam        $DIR_SLS
  Plugins Lua     $DIR_CFG_SLS/plugins (download, spliced-tickets)
  CloudRedirect   $DIR_CR_APP/cloud-redirect-ui

Reinicie a Steam para o LD_AUDIT valer, e abra o CloudRedirect pelo menu. O
provedor de nuvem se configura na aba Provedor; Google Drive e OneDrive pedem
autorizacao pelo navegador na primeira vez.
EOF
}

main "$@"
