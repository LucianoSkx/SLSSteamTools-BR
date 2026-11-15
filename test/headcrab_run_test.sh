#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/scripts/headcrab-run.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

HEADCRAB_URL="file://$tmp/ok.sh" bash "$script" >"$tmp/out" 2>&1
grep -qx 'resto ok' "$tmp/out" || { cat "$tmp/out"; echo "runner nao executou o resto do upstream"; exit 1; }
grep -q 'CRINSTALL RODOU' "$tmp/out" && { cat "$tmp/out"; echo "crinstall rodou"; exit 1; }
grep -q 'DESKTOP SOBRESCRITO' "$tmp/out" && { cat "$tmp/out"; echo "SetupHeadcrab_Updater rodou"; exit 1; }
grep -q 'flatpak install bloqueado' "$tmp/out" || { cat "$tmp/out"; echo "flatpak nao foi bloqueado"; exit 1; }

if HEADCRAB_URL="file://$tmp/sem_updater.sh" bash "$script" >"$tmp/out" 2>&1; then
    cat "$tmp/out"; echo "runner deveria abortar sem SetupHeadcrab_Updater"; exit 1
fi
grep -q 'SetupHeadcrab_Updater nao foi encontrada' "$tmp/out" || { cat "$tmp/out"; exit 1; }

echo "headcrab run test passed"
