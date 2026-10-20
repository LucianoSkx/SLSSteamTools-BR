#!/usr/bin/env bash
set -euo pipefail

script="${1:?diagnose.sh path is required}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
dumps="$tmp/dumps"
mkdir -p "$home/.local/share/Steam/logs" "$home/.config/CloudRedirect" "$dumps"
cat >"$home/.local/share/Steam/logs/console-linux.txt" <<'EOF'
steam.sh[123]: launch
token=TOPSECRET
EOF
cat >"$home/.config/CloudRedirect/cloud_redirect.log" <<'EOF'
GET https://graph.microsoft.com/v1.0/me/drive?tempauth=SUPERSECRET&foo=bar
Authorization: Bearer BEARERTOKEN
{"client_secret": "CLIENTSECRET", "account": "76561198000000000"}
user@example.com from 192.0.2.10
EOF
printf 'minidump-memory-SECRET\n' >"$dumps/assert_1.dmp"

HOME="$home" DIAG_SKIP_DESKTOPS=1 DIAG_OUT="$tmp/default.tar.gz" \
    DIAG_DUMP_DIRS="$dumps" bash "$script" >/dev/null
[ "$(stat -c %a "$tmp/default.tar.gz")" = "600" ] || {
    echo "FAIL: tarball is not 0600" >&2
    exit 1
}
if tar -tzf "$tmp/default.tar.gz" | grep -q 'steam-dumps'; then
    echo "FAIL: minidumps included without DIAG_INCLUDE_DUMPS=1" >&2
    exit 1
fi
mkdir "$tmp/extract"
tar -xzf "$tmp/default.tar.gz" -C "$tmp/extract"
if grep -R -E 'SUPERSECRET|TOPSECRET|BEARERTOKEN|CLIENTSECRET|76561198000000000|user@example\.com' \
        "$tmp/extract" >/dev/null; then
    echo "FAIL: sensitive data survived scrub" >&2
    exit 1
fi
grep -q 'REDACTED' "$tmp/extract/cloudredirect/cloud_redirect.log" || {
    echo "FAIL: URL query was not redacted" >&2
    exit 1
}

HOME="$home" DIAG_SKIP_DESKTOPS=1 DIAG_INCLUDE_DUMPS=1 DIAG_OUT="$tmp/dumps.tar.gz" \
    DIAG_DUMP_DIRS="$dumps" bash "$script" >/dev/null
tar -tzf "$tmp/dumps.tar.gz" | grep -q 'steam-dumps/assert_1.dmp' || {
    echo "FAIL: DIAG_INCLUDE_DUMPS=1 did not include the minidump" >&2
    exit 1
}

echo "diagnose_privacy_test: OK"
