#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="$root/build.sh"

grep -q -- '--target cloud_redirect cloud_redirect_cli' "$build"
grep -q 'build/cloud_redirect_cli' "$build"
grep -q 'cp -f.*cloud_redirect_cli' "$build"

echo "cli packaging test passed"
