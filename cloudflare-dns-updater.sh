#!/usr/bin/env bash

# Resolve directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/src/logger.sh"
CONFIG_FILE="$DIR/cloudflare-dns.yaml"

# Ensure tools are found by adding standard paths (including Windows/MSYS2)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/c/msys64/mingw64/bin:/mnt/c/msys64/mingw64/bin:$PATH"

# --- LOCK MECHANISM ---
LOCKFILE="/tmp/cloudflare-dns-updater.lock"
# Fallback if /tmp is not available
if [[ ! -d "/tmp" ]]; then
	LOCKFILE="$DIR/cloudflare-dns-updater.lock"
fi

if [[ -f "$LOCKFILE" ]]; then
	PID=$(cat "$LOCKFILE")
	if ps -p "$PID" >/dev/null 2>&1; then
		echo "Script is already running (PID: $PID). Exiting."
		exit 1
	else
		echo "Found stale lock file (PID: $PID). Overwriting."
	fi
fi

# Write PID
echo $$ >"$LOCKFILE"

# Cleanup on exit
trap 'rm -f "$LOCKFILE"' EXIT
# ----------------------

# Parse Arguments
export SILENT="false"
export DEBUG="false"
export FORCE="false"
for arg in "$@"; do
	case $arg in
	-s | --silent)
		export SILENT="true"
		;;
	-d | --debug)
		export DEBUG="true"
		;;
	-f | --force)
		export FORCE="true"
		;;
	*)
		# Ignore unknown arguments
		;;
	esac
done

# Check Dependencies
if ! command -v curl &>/dev/null; then
	echo "Error: 'curl' is required but not found in PATH." >&2
	echo "Please install curl (e.g., apt install curl, brew install curl)." >&2
	exit 1
fi

if ! command -v jq &>/dev/null && ! command -v jq.exe &>/dev/null; then
	if ! is_silent; then
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
