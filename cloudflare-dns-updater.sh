#!/usr/bin/env bash

# Resolve directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_FILE="$DIR/cloudflare-dns.yaml"

# Add MSYS2/MinGW64 to PATH for better tools (jq, curl, etc) if available
# Also add standard Linux/macOS paths to ensure tools are found
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/c/msys64/mingw64/bin:/mnt/c/msys64/mingw64/bin:$PATH"

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

# Parse Arguments
export SILENT="false"
for arg in "$@"; do
    case $arg in
        -s|--silent)
            export SILENT="true"
            ;;
    esac
done

# Check Dependencies
if ! command -v curl &> /dev/null; then
    echo "Error: 'curl' is required but not found in PATH." >&2
    echo "Please install curl (e.g., apt install curl, brew install curl)." >&2
    exit 1
fi

if ! command -v jq &> /dev/null && ! command -v jq.exe &> /dev/null; then
    if [[ "$SILENT" != "true" ]]; then
        echo "Warning: 'jq' not found. Using slower/limited sed-based parser." >&2
    fi
fi

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
