#!/usr/bin/env bash

# Resolve directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_FILE="$DIR/cloudflare-dns.yaml"

# Add MSYS2/MinGW64 to PATH for better tools (jq, curl, etc) if available
export PATH="/c/msys64/mingw64/bin:$PATH"

# --- LOCK MECHANISM ---
LOCKFILE="/tmp/cloudflare-dns-updater.lock"
# Fallback for Windows/MSYS2 if /tmp is tricky (though MSYS2 usually maps /tmp)
if [[ ! -d "/tmp" ]]; then
    LOCKFILE="$DIR/cloudflare-dns-updater.lock"
fi

if [[ -f "$LOCKFILE" ]]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Script is already running (PID: $PID). Exiting."
        exit 1
    else
        echo "Found stale lock file (PID: $PID). Overwriting."
    fi
fi

# Write PID
echo $$ > "$LOCKFILE"

# Cleanup on exit
trap 'rm -f "$LOCKFILE"' EXIT
# ----------------------

if [[ ! -f "$CONFIG_FILE" ]]; then
    # Try alternate or example
    if [[ -f "$DIR/config.example.yaml" ]]; then
        echo "Configuration file cloudflare-dns.yaml not found."
        echo "Please copy config.example.yaml to cloudflare-dns.yaml and configure it."
        exit 1
    fi
     echo "Configuration file not found!"
     exit 1
fi

"$DIR/src/main.sh" "$CONFIG_FILE"
