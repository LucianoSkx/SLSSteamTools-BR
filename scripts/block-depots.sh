#!/usr/bin/env bash
set -euo pipefail

[ $# -ge 1 ] || { echo "uso: $0 list | block <jogo|depot> | unblock <jogo|depot>" >&2; exit 1; }
[ "$1" = "list" ] || [ $# -ge 2 ] || { echo "uso: $0 list | block <jogo|depot> | unblock <jogo|depot>" >&2; exit 1; }

MODO="$1"
ALVO="${2:-}"
CFG="$HOME/.config/SLSsteam/config.yaml"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'
ok()   { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()  { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }

[ -f "$CFG" ] || die "sem config em $CFG"

if [ "$MODO" = "list" ]; then
    awk '
        /^AdditionalDepots:/ { sec=1; next }
        /^[A-Za-z_][A-Za-z0-9_]*:/ { sec=0; next }
        sec==1 {
            s=$0
            b=(s ~ /^[[:space:]]*#/)
            sub(/^[[:space:]]*#?[[:space:]]*/, "", s)
            if (s !~ /^-[[:space:]]*[0-9]+/) next
            c=s; n=index(s, "#"); c=(n>0) ? substr(s, n+1) : ""
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
            if (c=="") c="(sem nome)"
            if (b) blk[c]++; else atv[c]++
        }
        END { for (k in atv) printf "%dx %s\n", atv[k], k; for (k in blk) if (!(k in atv)) printf "0x %s [bloqueado]\n", k; for (k in blk) if ((k in atv)) printf "%dx %s + %dx bloqueados\n", atv[k], k, blk[k] }
    ' "$CFG" | sort
    exit 0
fi

[ "$MODO" = "block" ] || [ "$MODO" = "unblock" ] || die "modo invalido: $MODO (use list, block ou unblock)"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
awk -v modo="$MODO" -v alvo="$ALVO" '
    /^AdditionalDepots:/ { sec=1; print; next }
    /^DecryptionKeys:/ { sec=2; print; next }
    /^[A-Za-z_][A-Za-z0-9_]*:/ { sec=0; print; next }
    sec==0 { print; next }
    {
        orig=$0; s=$0
        com=(s ~ /^[[:space:]]*#/)
        if (com) { match(s, /^[[:space:]]*/); rest=substr(s, RLENGTH+1); sub(/^#[[:space:]]?/, "", rest); s=substr(s, 1, RLENGTH) rest }
        if (s !~ /^[[:space:]]*-[[:space:]]*[0-9]+/ && s !~ /^[[:space:]]*[0-9]+[[:space:]]*:/) { print orig; next }
        t=s; sub(/^[[:space:]]*-?[[:space:]]*/, "", t)
        id=t; sub(/[^0-9].*$/, "", id)
        c=""; n=index(s, "#"); if (n>0) c=substr(s, n+1)
        hit=(index(tolower(c), tolower(alvo))>0 || id==alvo)
        if (!hit) { print orig; next }
        if (modo=="block" && !com) {
            match(orig, /^[[:space:]]*/)
            print substr(orig, 1, RLENGTH) "# " substr(orig, RLENGTH+1)
            next
        }
        if (modo=="unblock" && com) { print s; next }
        print orig
    }
' "$CFG" > "$TMP"

if cmp -s "$CFG" "$TMP"; then
    warn "nada para $MODO com '$ALVO'"
    exit 0
fi
BKP="$CFG.blockbackup-$(date +%Y%m%d-%H%M%S)"
cp -a "$CFG" "$BKP"
mv -f "$TMP" "$CFG"
trap - EXIT
ok "$MODO '$ALVO' (backup em $BKP)"
echo "Reinicie a Steam para aplicar."
