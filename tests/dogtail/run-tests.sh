#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 PATH_TO_VALAPAD_BINARY" >&2
    exit 2
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
binary=$(realpath "$1")

command -v dbus-run-session >/dev/null 2>&1 || {
    echo "dbus-run-session is required to run Dogtail tests" >&2
    exit 1
}
command -v weston >/dev/null 2>&1 || {
    echo "Weston is required to run Dogtail tests on Wayland" >&2
    exit 1
}
python3 -c 'import dogtail' >/dev/null 2>&1 || {
    echo "The Python 3 dogtail package is required to run Dogtail tests" >&2
    exit 1
}

if [ "${VALAPAD_DOGTAIL_SESSION:-}" != 1 ]; then
    runtime_dir=$(mktemp -d "${TMPDIR:-/tmp}/valapad-wayland-XXXXXX")
    chmod 700 "$runtime_dir"
    trap 'rm -rf "$runtime_dir" 2>/dev/null || true' EXIT HUP INT TERM
    XDG_RUNTIME_DIR="$runtime_dir" \
        dbus-run-session -- env \
        VALAPAD_DOGTAIL_SESSION=1 \
        "$0" "$binary"
    exit $?
fi

runtime_dir=$XDG_RUNTIME_DIR
weston_log="$runtime_dir/weston.log"
weston_pid=
cleanup() {
    if [ -n "$weston_pid" ]; then
        kill "$weston_pid" 2>/dev/null || true
        wait "$weston_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT TERM

export WAYLAND_DISPLAY=valapad-test
unset DISPLAY
weston \
    --backend=headless-backend.so \
    --idle-time=0 \
    --renderer=pixman \
    --socket="$WAYLAND_DISPLAY" \
    --log="$weston_log" &
weston_pid=$!

attempt=0
while [ ! -S "$runtime_dir/$WAYLAND_DISPLAY" ]; do
    if ! kill -0 "$weston_pid" 2>/dev/null; then
        cat "$weston_log" >&2
        echo "Weston exited before creating its Wayland socket" >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 100 ]; then
        cat "$weston_log" >&2
        echo "Timed out waiting for Weston's Wayland socket" >&2
        exit 1
    fi
    sleep 0.1
done

unset GTK_MODULES
env \
    GDK_BACKEND=wayland \
    GDK_DEBUG=no-portals \
    GIO_USE_VFS=local \
    GTK_A11Y=atspi \
    GTK_USE_PORTAL=0 \
    VALAPAD_BINARY="$binary" \
    python3 "$script_dir/test_recovery.py"
