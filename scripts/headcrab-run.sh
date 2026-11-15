#!/usr/bin/env bash
# Roda o instalador do h3adcr-b sem a parte de CloudRedirect/flatpak dele.
# Steam e SLSsteam vem do upstream; hook, CLI e UI vem deste repositorio.
#
# Uso:  ./scripts/headcrab-run.sh
#       HEADCRAB_URL=file:///tmp/stub.sh ./scripts/headcrab-run.sh
set -euo pipefail

HEADCRAB_URL="${HEADCRAB_URL:-https://headcrab.pages.dev}"
STEAM_SH="$HOME/.local/share/Steam/steam.sh"
CR_DIR="$HOME/.local/share/CloudRedirect"
CR_APP_DIR="$CR_DIR/app"
HOOK_SO="$CR_DIR/cloud_redirect.so"
CR_REL_URL="${CR_REL_URL:-https://github.com/LucianoSkx/SLSSteamTools-BR/releases/download/latest}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_cyan='\033[1;36m'
info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

info "baixando o instalador do h3adcr-b"
curl -fsSL --retry 3 --connect-timeout 15 -o "$TMP/headcrab.sh" "$HEADCRAB_URL" \
    || die "falha ao baixar $HEADCRAB_URL"

# O upstream instala o app CloudRedirect em flatpak e baixa o hook/CLI dele por
# cima deste repositorio. Aqui as duas chamadas saem do script e o flatpak
# ainda entra bloqueado por um shim no PATH, para nenhum link (install,
# updater, pipe) conseguir instalar ou registrar remoto.
neutralizar() {
    local nome="$1" motivo="$2"
    local padrao="^[[:space:]]*${nome}[[:space:]]*$"

    grep -qE "$padrao" "$TMP/headcrab.sh" \
        || die "headcrab.sh mudou: a chamada $nome nao foi encontrada; abortando ($motivo)"
    sed -i -E "s/$padrao/:/" "$TMP/headcrab.sh"
    if grep -qE "$padrao" "$TMP/headcrab.sh"; then
        die "headcrab.sh ainda chamaria $nome; abortando ($motivo)"
    fi
}

neutralizar crinstall "instalaria o CloudRedirect do upstream"
neutralizar SetupHeadcrab_Updater "sobrescreveria o atalho do Headcrab Updater"
bash -n "$TMP/headcrab.sh" || die "headcrab.sh ficou invalido apos a neutralizacao"
mkdir -p "$TMP/bin"
REAL_FLATPAK="$(command -v flatpak || true)"
cat > "$TMP/bin/flatpak" <<SHIM
#!/usr/bin/env bash
case "\$1" in
    install|remote-add|update|repair|override)
        echo "[headcrab-run] flatpak \$1 bloqueado (CloudRedirect vem deste repositorio)" >&2
        exit 0
        ;;
esac
[ -n "$REAL_FLATPAK" ] || exit 0
exec "$REAL_FLATPAK" "\$@"
SHIM
chmod 755 "$TMP/bin/flatpak"

if : 2>/dev/null </dev/tty; then
    PATH="$TMP/bin:$PATH" bash "$TMP/headcrab.sh" </dev/tty || die "o instalador do h3adcr-b falhou"
else
    PATH="$TMP/bin:$PATH" bash "$TMP/headcrab.sh" </dev/null || die "o instalador do h3adcr-b falhou"
fi
ok "Steam e SLSsteam atualizados pelo h3adcr-b (sem CloudRedirect do upstream)"

# O upstream injeta o CloudRedirect so pelo app flatpak, que este repo nao usa.
# Sem a linha do hook a Steam sobe sem ele, entao ela volta depois de cada update.
garantir_hook_no_launcher() {
    local sh="$STEAM_SH" tmp cr exp_ln
    [ -f "$sh" ] || { warn "steam.sh nao encontrado; hook do CloudRedirect nao religado"; return 0; }
    if grep -q 'cloud_redirect\.so' "$sh"; then
        ok "hook do CloudRedirect ja esta na linha de lancamento"
        return 0
    fi
    [ -f "$HOOK_SO" ] || { warn "$HOOK_SO ausente; rode a instalacao do CloudRedirect e depois este updater"; return 0; }
    if ! grep -qE '^[[:space:]]*INJECT_SLS=' "$sh" || ! grep -q 'export \$INJECT_SLS' "$sh"; then
        die "steam.sh mudou: ancora do INJECT_SLS nao encontrada; hook do CloudRedirect nao religado"
    fi
    cr="INJECT_CR=\"LD_PRELOAD=$HOOK_SO\""
    exp_ln='export $INJECT_CR &> /dev/null'
    tmp="$(mktemp "${sh}.tmp.XXXXXX")" || die "impossivel escrever em $sh"
    awk -v cr="$cr" -v exp_ln="$exp_ln" '
        /^[[:space:]]*INJECT_SLS=/ { print; print "    " cr; next }
        /export \$INJECT_SLS/ { print; print "        " exp_ln; next }
        { print }
    ' "$sh" > "$tmp"
    bash -n "$tmp" || { rm -f "$tmp"; die "steam.sh ficou invalido; patch nao aplicado"; }
    chmod --reference="$sh" "$tmp" || { rm -f "$tmp"; die "falha ao preservar as permissoes de $sh"; }
    mv -f "$tmp" "$sh" || die "falha ao gravar $sh"
    ok "hook do CloudRedirect religado no steam.sh"
}

# Hook e CLI vem da release `latest` deste repo; só troca quando o arquivo muda.
atualizar_cloudredirect() {
    local nome tmp alvo mudou=0
    mkdir -p "$CR_DIR" "$CR_APP_DIR"
    for nome in cloud_redirect.so cloud_redirect_cli; do
        tmp="$TMP/$nome.novo"
        if ! curl -fsSL --retry 3 --connect-timeout 15 -o "$tmp" "$CR_REL_URL/$nome"; then
            warn "falha ao baixar $nome; mantendo o instalado"
            continue
        fi
        if command -v file >/dev/null 2>&1 && ! file -b "$tmp" | grep -q 'ELF 32-bit'; then
            warn "$nome nao e ELF 32-bit; ignorado"
            continue
        fi
        for alvo in "$CR_DIR/$nome" "$CR_APP_DIR/$nome"; do
            cmp -s "$tmp" "$alvo" && continue
            install -m 755 "$tmp" "$alvo" || die "falha ao instalar $alvo"
            mudou=1
        done
    done
    if [ "$mudou" = 1 ]; then
        ok "hook e CLI do CloudRedirect atualizados ($CR_DIR)"
    else
        ok "hook e CLI do CloudRedirect ja estavam na ultima versao"
    fi
}

atualizar_cloudredirect
garantir_hook_no_launcher
