#!/usr/bin/env bash
set -eu

library="${1:?cloud_redirect.so path is required}"
compiler="${CC:-cc}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/interpose.c" <<'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <stdlib.h>
#include <unistd.h>

int pthread_cond_broadcast(pthread_cond_t* condition) {
    static int (*real_broadcast)(pthread_cond_t*);
    if (!real_broadcast)
        real_broadcast = dlsym(RTLD_NEXT, "pthread_cond_broadcast");
    const int result = real_broadcast(condition);
    for (int i = 0; i < 10000; ++i)
        sched_yield();
    return result;
}

int pthread_join(pthread_t thread, void** result) {
    static int (*real_join)(pthread_t, void**);
    if (!real_join)
        real_join = dlsym(RTLD_NEXT, "pthread_join");
    const char* marker = getenv("JOIN_PROBE");
    if (marker) {
        const int fd = open(marker, O_WRONLY | O_CREAT | O_APPEND, 0600);
        if (fd >= 0) {
            (void)write(fd, "join\n", 5);
            close(fd);
        }
    }
    return real_join(thread, result);
}
EOF

cat >"$tmp/steam.c" <<'EOF'
#include <unistd.h>
int main(void) {
    usleep(10000);
    return 0;
}
EOF

"$compiler" -m32 -shared -fPIC "$tmp/interpose.c" -ldl -o "$tmp/interpose.so"
"$compiler" -m32 "$tmp/steam.c" -o "$tmp/steam"
mkdir -p "$tmp/home"

status=0
JOIN_PROBE="$tmp/join.log" \
HOME="$tmp/home" \
XDG_CONFIG_HOME="$tmp/home/config" \
LD_PRELOAD="$tmp/interpose.so:$library" \
    "$tmp/steam" >/dev/null 2>&1 || status=$?

debug_log="$tmp/home/config/CloudRedirect/cr_debug.log"
if [ "$status" -ne 0 ]; then
    tail -n 20 "$debug_log" >&2 2>/dev/null || true
    if grep -q '^join$' "$tmp/join.log" 2>/dev/null; then
        echo "pthread_join was called before the crash" >&2
    else
        echo "pthread_join was not called before the crash" >&2
    fi
    echo "FAIL: short-lived Steam bootstrap exited with status $status" >&2
    exit 1
fi
grep -q 'DeferredInit: stopped early' "$debug_log" || {
    echo "FAIL: deferred-init early-exit path was not exercised" >&2
    exit 1
}
grep -q '^join$' "$tmp/join.log" 2>/dev/null || {
    echo "FAIL: unload skipped pthread_join after the init worker reported done" >&2
    exit 1
}

echo "linux init join test passed"
