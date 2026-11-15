#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/scripts/pin-client.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
steam="$home/.steam/steam"
mkdir -p "$steam/package"
printf '\t"version"\t\t"1794424036"\n' >"$steam/package/steam_client_ubuntu12.manifest"

run() {
    HOME="$home" CR_CLIENT_VERSION=1794424036 bash "$script" "$@" >"$tmp/out" 2>&1
}

run pin
[ "$(cat "$steam/steam.cfg")" = "$(printf 'BootStrapperInhibitAll=enable\nBootStrapperForceSelfUpdate=disable')" ] \
    || { cat "$tmp/out"; echo "pin nao criou steam.cfg correto"; exit 1; }
grep -q 'versao do cliente compativel' "$tmp/out" || { cat "$tmp/out"; exit 1; }

run pin
[ "$(grep -c . "$steam/steam.cfg")" = "2" ] || { cat "$tmp/out"; echo "pin duplicou chaves"; exit 1; }

printf 'BootStrapperInhibitAll=disable\nOutraChave=1\n' >"$steam/steam.cfg"
run pin
grep -qx 'BootStrapperInhibitAll=enable' "$steam/steam.cfg" || { cat "$tmp/out"; exit 1; }
grep -qx 'BootStrapperForceSelfUpdate=disable' "$steam/steam.cfg" || { cat "$tmp/out"; exit 1; }
grep -qx 'OutraChave=1' "$steam/steam.cfg" || { cat "$tmp/out"; echo "pin apagou chave alheia"; exit 1; }
ls "$steam"/steam.cfg.instbackup-* >/dev/null || { cat "$tmp/out"; echo "pin nao fez backup"; exit 1; }

HOME="$home" CR_CLIENT_VERSION=1 bash "$script" status >"$tmp/out" 2>&1
grep -q 'fora da versao compativel' "$tmp/out" || { cat "$tmp/out"; exit 1; }

printf '\tHeadcrabCompatibleClientVer=1111111111\n' >"$tmp/headcrab.sh"
HOME="$home" HEADCRAB_URL="file://$tmp/headcrab.sh" bash "$script" status >"$tmp/out" 2>&1
grep -q 'compativel com SLSsteam: 1111111111' "$tmp/out" || { cat "$tmp/out"; echo "nao leu a build do h3adcr-b"; exit 1; }

HOME="$home" HEADCRAB_URL="file://$tmp/nao-existe" bash "$script" status >"$tmp/out" 2>&1
grep -q 'compativel com SLSsteam: 1794424036' "$tmp/out" || { cat "$tmp/out"; echo "fallback da build falhou"; exit 1; }

run unpin
[ "$(cat "$steam/steam.cfg")" = "OutraChave=1" ] || { cat "$tmp/out"; echo "unpin nao preservou o resto"; exit 1; }

printf 'BootStrapperInhibitAll=enable\n' >"$steam/steam.cfg"
run unpin
[ ! -e "$steam/steam.cfg" ] || { cat "$tmp/out"; echo "unpin nao apagou steam.cfg vazio"; exit 1; }

run unpin
grep -q 'nada a destravar' "$tmp/out" || { cat "$tmp/out"; exit 1; }

mkdir -p "$home/.var/app/com.valvesoftware.Steam/.steam/steam"
if HOME="$home" bash "$script" pin >"$tmp/out" 2>&1; then
    echo "pin deveria recusar Steam flatpak"; exit 1
fi
grep -q 'flatpak' "$tmp/out" || { cat "$tmp/out"; exit 1; }

echo "pin client test passed"
