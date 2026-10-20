#!/usr/bin/env bash
# ============================================================================
#  SLSSteamTools-BR — diagnostics collector
# ============================================================================
#  Coleta logs da stack (Steam + SLSsteam + CloudRedirect), remove dados
#  pessoais, empacota num .tar.gz e sobe pra um paste publico (uguu, fallback
#  catbox), imprimindo APENAS o link.
#
#    curl -fsSL https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/master/scripts/diagnose.sh | bash
#
#  Para gerar o tarball local sem subir nada:
#
#    DIAG_OUT=~/diag.tar.gz bash scripts/diagnose.sh
#
#  Privacidade: todo log e filtrado por scrub() antes de sair da maquina
#  (home, usuario, SteamID64, email, IPv4, email FakeEmail). Minidumps em
#  /tmp/dumps vao como estao (binario) — podem conter memoria do processo.
#  Segredos NUNCA sao coletados: tokens OAuth em ~/.config/CloudRedirect,
#  ~/.steam/steam/registry.vdf etc. so entram se forem texto de log puro,
#  e mesmo assim passam pelo scrub.
# ============================================================================

set -uo pipefail

_re_escape() { printf '%s' "$1" | sed -e 's/[^a-zA-Z0-9]/\\&/g'; }

scrub() {
	local u h
	u="${SCRUB_USER-$(id -un 2>/dev/null || true)}"
	h="${SCRUB_HOME-$HOME}"
	local -a args=(-E)
	if [ -n "$h" ]; then
		args+=(-e "s#$(_re_escape "$h")#/home/USER#g")
	fi
	args+=(-e 's#/home/[A-Za-z0-9._-]+#/home/USER#g')
	args+=(-e 's#(userdata|storage|backups)/[0-9]+#\1/ACCOUNTID#g')
	args+=(-e 's/(account[_ ]?id)([^0-9A-Za-z]{1,6})[0-9]+/\1\2ACCOUNTID/gI')
	args+=(-e 's/\b7656[0-9]{13}\b/STEAMID/g')
	args+=(-e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/EMAIL/g')
	args+=(-e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/IP/g')
	args+=(-e 's/-[a-z]{2,5}[0-9]+\.steamserver\.net/-REGION.steamserver.net/g')
	args+=(-e 's/((force_)?account_?name|persona_?name)([[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1\3NAME/gI')
	if [ -n "$u" ]; then
		args+=(-e "s/\b$(_re_escape "$u")\b/USER/g")
	fi
	sed "${args[@]}"
}

validate_paste_url() {
	local u="${1-}"
	case "$u" in
		*[[:space:]]*) return 1 ;;
	esac
	[[ "$u" =~ ^https://(files\.catbox\.moe|[a-z]\.uguu\.se)/[A-Za-z0-9._-]+$ ]]
}

DIAG_CEF_CAP="${DIAG_CEF_CAP:-262144}"
DIAG_LOG_CAP="${DIAG_LOG_CAP:-524288}"
DIAG_DUMP_MAX="${DIAG_DUMP_MAX:-4}"
DIAG_DUMP_MAX_BYTES="${DIAG_DUMP_MAX_BYTES:-12582912}"
DIAG_DUMP_DIRS="${DIAG_DUMP_DIRS:-/tmp/dumps:/var/tmp/dumps}"
DIAG_CRASH_LINES="${DIAG_CRASH_LINES:-60}"

steam_root() {
	local link="$HOME/.steam/steam" r c
	r="$(readlink -e -q "$link" 2>/dev/null || true)"
	if [ -n "$r" ] && [ -d "$r/logs" ]; then printf '%s' "$r"; return 0; fi
	for c in "$HOME/.local/share/Steam" "$HOME/.steam/debian-installation" "$HOME/.steam/steam"; do
		if [ -d "$c/logs" ]; then printf '%s' "$c"; return 0; fi
	done
	printf ''
}

_stage_file() { # $1 stage-dir  $2 dest-relpath  $3 src  $4 cap(bytes,0=full)
	local stage="$1" dest="$2" src="$3" cap="${4:-0}"
	[ -f "$src" ] && [ -r "$src" ] || return 0
	mkdir -p "$stage/$(dirname "$dest")"
	if [ "$cap" -gt 0 ]; then
		tail -c "$cap" "$src" 2>/dev/null | scrub > "$stage/$dest"
	else
		scrub < "$src" > "$stage/$dest"
	fi
}

_collect_steam_logs() { # $1 stage-dir $2 steam-root
	local stage="$1" sr="$2" f base
	[ -n "$sr" ] && [ -d "$sr/logs" ] || return 0
	for f in "$sr"/logs/*; do
		base="$(basename "$f")"
		case "$base" in
			cef_log.txt|webhelper_gpu.txt|webhelper_js.txt)
				_stage_file "$stage" "steam/$base" "$f" "$DIAG_CEF_CAP" ;;
			htmlcache|*.dmp) ;;
			*)
				_stage_file "$stage" "steam/$base" "$f" "$DIAG_LOG_CAP" ;;
		esac
	done
}

_collect_desktops() { # $1 stage-dir
	local stage="$1" dest="$stage/steam-desktops.txt"
	local raw; raw="$(mktemp "${TMPDIR:-/tmp}/slstools-diag-desk.XXXXXX")" || return 0
	local found=0 f
	while IFS= read -r -d '' f; do
		found=1
		{
			printf '===== BEGIN %s =====\n' "$f"
			head -60 "$f" 2>/dev/null || true
			printf '\n===== END %s =====\n\n' "$f"
		} >> "$raw"
	done < <(timeout 90 find / \
		-path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -path /run -prune -o \
		-iname '*steam*.desktop' -type f -print0 2>/dev/null)
	[ "$found" -eq 1 ] && scrub < "$raw" > "$dest"
	rm -f "$raw"
}

_collect_client_crashes() { # $1 stage-dir $2 steam-root
	local stage="$1" sr="$2" raw filtered f total=0 n
	[ -n "$sr" ] && [ -d "$sr/logs" ] || { printf 0; return 0; }
	raw="$(mktemp "${TMPDIR:-/tmp}/slstools-diag-crash.XXXXXX" 2>/dev/null || true)"
	[ -n "$raw" ] || { printf 0; return 0; }
	filtered="${raw}.matches"
	for f in "$sr/logs/console-linux.txt" "$sr/logs/console_log.txt" "$sr/logs/bootstrap_log.txt"; do
		[ -f "$f" ] && [ -r "$f" ] || continue
		grep -F -e '"$STEAMROOT/$STEAMEXEPATH"' -- "$f" 2>/dev/null \
			| grep -F 'steam.sh' 2>/dev/null > "$filtered" || true
		n="$(wc -l < "$filtered" 2>/dev/null | tr -d '[:space:]')"
		case "$n" in ''|*[!0-9]*) n=0 ;; esac
		[ "$n" -eq 0 ] && continue
		{
			printf '===== %s =====\n' "$f"
			tail -n "$DIAG_CRASH_LINES" "$filtered" 2>/dev/null || true
			printf '\n'
		} >> "$raw"
		total=$(( total + n ))
	done
	[ -s "$raw" ] && scrub < "$raw" > "$stage/steam-client-crashes.txt"
	rm -f "$raw" "$filtered"
	printf '%s' "$total"
}

_collect_coredumps() { # $1 stage-dir
	local stage="$1"
	if command -v coredumpctl >/dev/null 2>&1; then
		COLUMNS=200 coredumpctl list --no-pager 2>/dev/null \
			| grep -iE 'steam|cef|webhelper' | tail -20 \
			| scrub > "$stage/steam-coredumps.txt" || true
	fi
	# Minidumps do breakpad (binarios, sem scrub — offsets internos).
	local d count=0
	IFS=':' read -r -a dirs <<< "$DIAG_DUMP_DIRS"
	for d in "${dirs[@]}"; do
		[ -d "$d" ] || continue
		mkdir -p "$stage/steam-dumps"
		while IFS= read -r f; do
			b="$(basename "$f")"
			dd if="$f" of="$stage/steam-dumps/$b" bs=1 count="$DIAG_DUMP_MAX_BYTES" 2>/dev/null || true
			count=$(( count + 1 ))
			[ "$count" -ge "$DIAG_DUMP_MAX" ] && break 2
		done < <(find "$d" -maxdepth 1 -type f -name '*.dmp' -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
	done
}

_collect_install_state() { # $1 stage-dir
	local stage="$1" raw
	raw="$(mktemp "${TMPDIR:-/tmp}/slstools-diag-state.XXXXXX" 2>/dev/null || true)"
	[ -n "$raw" ] || return 0
	{
		printf 'STEAM_SH copies:\n'
		for c in "$HOME/.local/share/Steam/steam.sh" "$HOME/.steam/steam/steam.sh" "$HOME/.steam/debian-installation/steam.sh"; do
			if [ -f "$c" ]; then
				printf '  %s mtime=%s size=%s\n' "$c" \
					"$(date -r "$c" '+%Y-%m-%d %H:%M' 2>/dev/null)" \
					"$(stat -c %s "$c" 2>/dev/null)"
				grep -l 'LD_AUDIT\|LD_PRELOAD' "$c" >/dev/null 2>&1 \
					&& printf '    patched: LD_AUDIT/LD_PRELOAD presente\n' \
					|| printf '    patched: NAO (vanilla)\n'
			else
				printf '  %s: ausente\n' "$c"
			fi
		done
		for bak in "$HOME/.local/share/Steam/steam.sh.slssteam.bak" "$HOME/.steam/steam/steam.sh.slssteam.bak"; do
			[ -f "$bak" ] && printf '  backup: %s\n' "$bak"
		done
		printf '\nSLSsteam dir:\n'
		ls -la "$HOME/.local/share/SLSsteam" 2>/dev/null | scrub || printf '  ausente\n'
		printf '  version: %s\n' "$(cat "$HOME/.local/share/SLSsteam/version" 2>/dev/null || echo ausente)"
		printf '\nCloudRedirect dir:\n'
		ls -la "$HOME/.local/share/CloudRedirect" 2>/dev/null | scrub || printf '  ausente\n'
		printf '\nPlugins SLSsteam:\n'
		ls "$HOME/.config/SLSsteam/plugins" 2>/dev/null || printf '  ausente\n'
		printf '\nsteam.cfg:\n'
		cat "$HOME/.local/share/Steam/steam.cfg" 2>/dev/null | scrub || printf '  ausente\n'
		printf '\nconfig.yaml (header):\n'
		head -5 "$HOME/.config/SLSsteam/config.yaml" 2>/dev/null | scrub
		printf '\nSO: %s\n' "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2-)"
		printf 'kernel: %s\n' "$(uname -r)"
		printf 'sessao: %s / %s\n' "${XDG_SESSION_TYPE:-?}" "${XDG_CURRENT_DESKTOP:-?}"
	} > "$raw"
	scrub < "$raw" > "$stage/install-state.txt"
	rm -f "$raw"
}

_catbox_upload() {
	command -v curl >/dev/null 2>&1 || return 1
	local url
	url="$(curl -sS --max-time 120 -F 'reqtype=fileupload' -F "fileToUpload=@$1" \
		https://catbox.moe/user/api.php 2>/dev/null | tr -d '\r\n')"
	validate_paste_url "$url" && printf '%s\n' "$url" || return 1
}

_uguu_upload() {
	command -v curl >/dev/null 2>&1 || return 1
	local raw link
	raw="$(curl -sS --max-time 120 -F "files[]=@$1;filename=slsstools-logs.tar.gz" https://uguu.se/upload.php 2>/dev/null)"
	link="$(printf '%s' "$raw" | grep -oE 'https://[a-z]\.uguu\.se/[A-Za-z0-9._-]+' | head -1)"
	validate_paste_url "$link" && printf '%s\n' "$link" || return 1
}

upload() {
	local file="$1" url
	if url="$(_uguu_upload "$file")"; then printf '%s\n' "$url"; return 0; fi
	if url="$(_catbox_upload "$file")"; then printf '%s\n' "$url"; return 0; fi
	return 1
}

main() {
	local sr stage tmp
	sr="$(steam_root)"
	stage="$(mktemp -d "${TMPDIR:-/tmp}/slsstools-diag.XXXXXX")" || exit 1
	tmp="${TMPDIR:-/tmp}/slsstools-logs.tar.gz"

	_collect_steam_logs "$stage" "$sr"
	_stage_file "$stage" "slssteam/SLSsteam.log" "$HOME/.SLSsteam.log" "$DIAG_LOG_CAP"
	_stage_file "$stage" "cloudredirect/cloud_redirect.log" "$HOME/.config/CloudRedirect/cloud_redirect.log" "$DIAG_LOG_CAP"
	_stage_file "$stage" "cloudredirect/cr_debug.log" "$HOME/.config/CloudRedirect/cr_debug.log" "$DIAG_LOG_CAP"
	_stage_file "$stage" "slssteam/config.yaml" "$HOME/.config/SLSsteam/config.yaml" 0
	for c in "$HOME/.local/share/Steam/steam.sh" "$HOME/.steam/steam/steam.sh"; do
		[ -f "$c" ] && _stage_file "$stage" "launcher/$(basename "$(dirname "$c")")-steam.sh" "$c" 0
	done
	[ -f "$HOME/.local/share/Steam/steam.cfg" ] && _stage_file "$stage" "steam/steam.cfg" "$HOME/.local/share/Steam/steam.cfg" 0
	_collect_desktops "$stage"
	_collect_client_crashes "$stage" "$sr" >/dev/null
	_collect_coredumps "$stage"
	_collect_install_state "$stage"

	tar -czf "$tmp" -C "$stage" . 2>/dev/null
	rm -rf "$stage"

	if [ -n "${DIAG_OUT:-}" ]; then
		cp "$tmp" "$DIAG_OUT" && rm -f "$tmp"
		printf 'salvo em: %s\n' "$DIAG_OUT"
		return 0
	fi

	if url="$(upload "$tmp")"; then
		rm -f "$tmp"
		printf '%s\n' "$url"
	else
		printf 'falha no upload; tarball em %s\n' "$tmp" >&2
		return 1
	fi
}

main "$@"
