#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cli="${1:-$root/cloud_redirect_cli}"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

mkdir -p "$home/.config/CloudRedirect" "$home/saves/77/42" "$home/saves/77/99"
printf x > "$home/saves/77/42/a.sav"
printf y > "$home/saves/77/99/b.sav"
printf '{"provider":"folder","sync_folder_path":"%s"}\n' "$home/saves" \
  > "$home/.config/CloudRedirect/config.json"

output="$(HOME="$home" "$cli" list-remote-app-ids folder 77)"
json="$(printf '%s\n' "$output" | awk '/^\{.*\}$/ { value=$0 } END { print value }')"

printf '%s' "$json" | grep -q '"success":true'
printf '%s' "$json" | grep -q '"42"'
printf '%s' "$json" | grep -q '"99"'

echo "CLI folder provider test passed"
