#!/usr/bin/env bash
# Roda o instalador do h3adcr-b sem a parte de CloudRedirect/flatpak dele.
# Steam e SLSsteam vem do upstream; hook, CLI e UI vem deste repositorio.
#
# Uso:  ./scripts/headcrab-run.sh
#       HEADCRAB_URL=file:///tmp/stub.sh ./scripts/headcrab-run.sh
set -euo pipefail

HEADCRAB_URL="${HEADCRAB_URL:-https://headcrab.pages.dev}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_red='\033[1;31m'; c_cyan='\033[1;36m'
info() { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
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
