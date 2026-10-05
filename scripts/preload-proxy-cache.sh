#!/usr/bin/env bash

set -euo pipefail

# Set this to the depot file or directory revision to preload.
DEPOT_PATH="//depot/path/to/preload/..."

# Override these when the proxy is not exposed at localhost:1777.
P4PORT="${P4PORT:-ssl:localhost:1777}"
P4USER="${P4USER:-}"
P4CLIENT="${P4CLIENT:-p4proxy-preload}"
P4CLIENT_ROOT="${P4CLIENT_ROOT:-/tmp/p4proxy-preload}"

if [[ "$DEPOT_PATH" == "//depot/path/to/preload/..." ]]; then
    echo "Set DEPOT_PATH in this script before running it." >&2
    exit 1
fi

if ! command -v p4 >/dev/null 2>&1; then
    echo "The p4 CLI must be installed on the host." >&2
    exit 1
fi

command=(p4 -p "$P4PORT")
if [[ -n "$P4USER" ]]; then
    command+=(-u "$P4USER")
fi

if ! "${command[@]}" clients -e "$P4CLIENT" | awk -v client_name="$P4CLIENT" '$2 == client_name { found = 1 } END { exit !found }'; then
    mkdir -p "$P4CLIENT_ROOT"
    "${command[@]}" client -i <<EOF
Client: $P4CLIENT

Root: $P4CLIENT_ROOT

Options: noallwrite noclobber nocompress unlocked nomodtime normdir

SubmitOptions: submitunchanged

LineEnd: local

View:
	${DEPOT_PATH%@*} //$P4CLIENT/...
EOF
fi

"${command[@]}" -c "$P4CLIENT" -Z proxyload sync "$DEPOT_PATH"
