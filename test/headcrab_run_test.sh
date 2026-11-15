#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/scripts/headcrab-run.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
steam_sh="$home/.local/share/Steam/steam.sh"
mkdir -p "$home/.local/share/Steam" "$home/.local/share/CloudRedirect"
: >"$home/.local/share/CloudRedirect/cloud_redirect.so"
cat >"$steam_sh" <<'EOF'
#!/usr/bin/env bash
    INJECT_SLS="LD_AUDIT=$HOME/.local/share/SLSsteam/SLSsteam.so"

GameLauncher(){
    echo "Loaded SLSsteam" & export $INJECT_SLS &> /dev/null
}
EOF
chmod 755 "$steam_sh"

rel="$tmp/rel"
mkdir -p "$rel"
printf 'lixo\n' >"$rel/cloud_redirect.so"
printf 'lixo\n' >"$rel/cloud_redirect_cli"

run() {
    HOME="$home" HEADCRAB_URL="$1" CR_REL_URL="file://$rel" bash "$script" >"$tmp/out" 2>&1
}

cat >"$tmp/ok.sh" <<'EOF'
#!/usr/bin/env bash
crinstall(){ echo "CRINSTALL RODOU"; }
SetupHeadcrab_Updater(){ echo "DESKTOP SOBRESCRITO"; }
conditioncheck(){
    crinstall
    flatpak install --user flathub org.kde.Platform//6.10 --assumeyes
    echo "resto ok"
}
main(){
    SetupHeadcrab_Updater
    conditioncheck
}
main
EOF

cat >"$tmp/sem_updater.sh" <<'EOF'
#!/usr/bin/env bash
crinstall(){ echo "CRINSTALL RODOU"; }
crinstall
echo "resto ok"
EOF

run "file://$tmp/ok.sh"
grep -qx 'resto ok' "$tmp/out" || { cat "$tmp/out"; echo "runner nao executou o resto do upstream"; exit 1; }
grep -q 'CRINSTALL RODOU' "$tmp/out" && { cat "$tmp/out"; echo "crinstall rodou"; exit 1; }
grep -q 'DESKTOP SOBRESCRITO' "$tmp/out" && { cat "$tmp/out"; echo "SetupHeadcrab_Updater rodou"; exit 1; }
grep -q 'flatpak install bloqueado' "$tmp/out" || { cat "$tmp/out"; echo "flatpak nao foi bloqueado"; exit 1; }

grep -q 'nao e ELF 32-bit' "$tmp/out" || { cat "$tmp/out"; echo "hook invalido deveria ser ignorado"; exit 1; }
[ ! -s "$home/.local/share/CloudRedirect/cloud_redirect.so" ] || { cat "$tmp/out"; echo "hook invalido foi instalado"; exit 1; }

grep -q 'INJECT_CR="LD_PRELOAD=.*cloud_redirect\.so"' "$steam_sh" \
    || { cat "$steam_sh"; echo "hook nao foi adicionado ao steam.sh"; exit 1; }
grep -q 'export \$INJECT_CR' "$steam_sh" || { cat "$steam_sh"; echo "export do hook nao foi adicionado"; exit 1; }

[ -x "$steam_sh" ] || { echo "patch perdeu o bit de execucao"; exit 1; }
[ "$(stat -c %a "$steam_sh")" = "755" ] || { echo "permissoes mudaram"; stat -c %a "$steam_sh"; exit 1; }
bash -n "$steam_sh" || { cat "$steam_sh"; echo "steam.sh invalido apos o patch"; exit 1; }

run "file://$tmp/ok.sh"
[ "$(grep -c 'INJECT_CR=' "$steam_sh")" = "1" ] || { cat "$steam_sh"; echo "patch duplicou o hook"; exit 1; }

if [ -f /lib/ld-linux.so.2 ]; then
    cp /lib/ld-linux.so.2 "$rel/cloud_redirect.so"
    cp /lib/ld-linux.so.2 "$rel/cloud_redirect_cli"
    run "file://$tmp/ok.sh"
    grep -q 'hook e CLI do CloudRedirect atualizados' "$tmp/out" || { cat "$tmp/out"; echo "hook valido nao foi instalado"; exit 1; }
    cmp -s "$rel/cloud_redirect.so" "$home/.local/share/CloudRedirect/cloud_redirect.so" \
        || { echo "hook nao foi copiado"; exit 1; }
    cmp -s "$rel/cloud_redirect.so" "$home/.local/share/CloudRedirect/app/cloud_redirect.so" \
        || { echo "hook nao foi copiado para app/"; exit 1; }

    run "file://$tmp/ok.sh"
    grep -q 'ja estavam na ultima versao' "$tmp/out" || { cat "$tmp/out"; echo "update nao e idempotente"; exit 1; }
fi

printf '#!/usr/bin/env bash\nsem ancoras\n' >"$steam_sh"
if run "file://$tmp/ok.sh"; then
    cat "$tmp/out"; echo "runner deveria abortar sem a ancora do INJECT_SLS"; exit 1
fi
grep -q 'ancora do INJECT_SLS nao encontrada' "$tmp/out" || { cat "$tmp/out"; exit 1; }

if run "file://$tmp/sem_updater.sh"; then
    cat "$tmp/out"; echo "runner deveria abortar sem SetupHeadcrab_Updater"; exit 1
fi
grep -q 'SetupHeadcrab_Updater nao foi encontrada' "$tmp/out" || { cat "$tmp/out"; exit 1; }

echo "headcrab run test passed"
