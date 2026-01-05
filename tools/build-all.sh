#!/usr/bin/env bash

# Ultimate Standalone Binary Builder
# Bundles: bash + busybox (sed/grep/awk) + curl + jq + script
# Targets: Linux (x64/ARM), Windows (x64)

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$DIR/.."
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"

# Tool Versions & URLs
JQ_VERSION="1.7.1"
BASH_STATIC_URL="https://github.com/robxu9/bash-static/releases/latest/download"
CURL_STATIC_URL="https://github.com/moparisthebest/static-curl/releases/latest/download"
BUSYBOX_W32_URL="https://github.com/rmayo/busybox-w32/releases/latest/download/busybox64.exe"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Initializing Full-Bundle Build System...${NC}"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# 1. Generate the Monolith
echo "Generating monolith script..."
"$DIR/bundle.sh"
# bundle.sh outputs to dist/cloudflare-dns-updater-monolith.sh
MONOLITH="$DIST_DIR/cloudflare-dns-updater-monolith.sh"

create_entrypoint() {
	local target_dir=$1
	cat <<'EOF' >"$target_dir/entrypoint.sh"
#!/bin/sh
SELF_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# Force usage of bundled binaries
export PATH="$SELF_DIR/bin:$PATH"
# Execute the main script using the bundled bash
exec "$SELF_DIR/bin/bash" "$SELF_DIR/main.sh" "$@"
EOF
	chmod +x "$target_dir/entrypoint.sh"
}

build_linux() {
	local arch=$1 # x86_64, aarch64
	echo -e "${BLUE}Building FULL bundle for Linux $arch...${NC}"
	local work_dir="$BUILD_DIR/linux-$arch"
	local bin_dir="$work_dir/bin"
	mkdir -p "$bin_dir"

	echo "  - Downloading static tools..."
	# Bash
	curl -L -s -o "$bin_dir/bash" "${BASH_STATIC_URL}/bash-linux-$arch"
	# JQ
	local jq_arch=$arch
	[[ "$arch" == "x86_64" ]] && jq_arch="amd64"
	[[ "$arch" == "aarch64" ]] && jq_arch="arm64"
	curl -L -s -o "$bin_dir/jq" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${jq_arch}"
	# Curl
	local curl_arch=$arch
	[[ "$arch" == "x86_64" ]] && curl_arch="amd64"
	curl -L -s -o "$bin_dir/curl" "${CURL_STATIC_URL}/curl-$curl_arch"
	# BusyBox (for sed, grep, etc.)
	curl -L -s -o "$bin_dir/busybox" "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"
	# If aarch64, change busybox URL
	[[ "$arch" == "aarch64" ]] && curl -L -s -o "$bin_dir/busybox" "https://busybox.net/downloads/binaries/1.35.0-armv8l/busybox"

	chmod +x "$bin_dir/"*

	# Setup symlinks for busybox tools
	for tool in sed grep awk cat sleep date mktemp head tail cut tr wc ps; do
		ln -sf busybox "$bin_dir/$tool"
	done

	cp "$MONOLITH" "$work_dir/main.sh"
	create_entrypoint "$work_dir"

	echo "  - Packaging..."
	if command -v makeself >/dev/null 2>&1; then
		makeself --quiet --noprogress "$work_dir" "$DIST_DIR/cf-updater-linux-$arch.run" "Cloudflare DNS Updater" "./entrypoint.sh"
	else
		tar -czf "$DIST_DIR/cf-updater-linux-$arch.tar.gz" -C "$work_dir" .
	fi
}

build_windows() {
	echo -e "${BLUE}Building FULL bundle for Windows x64...${NC}"
	local work_dir="$BUILD_DIR/windows-x64"
	mkdir -p "$work_dir"

	echo "  - Downloading BusyBox-w32..."
	curl -L -s -o "$work_dir/busybox.exe" "$BUSYBOX_W32_URL"

	cp "$MONOLITH" "$work_dir/main.sh"

	cat <<'EOF' >"$work_dir/cf-updater.bat"
@echo off
set "DIR=%~dp0"
"%DIR%busybox.exe" bash "%DIR%main.sh" %*
EOF

	echo "  - Packaging Windows zip..."
	(cd "$work_dir" && tar -acf "$DIST_DIR/cf-updater-windows-x64.zip" *)
}

# Local execution
if [[ "$1" == "--linux-amd64" ]]; then
	build_linux "x86_64"
elif [[ "$1" == "--windows" ]]; then
	build_windows
else
	# Default all
	build_linux "x86_64"
	build_linux "aarch64"
	build_windows
fi

echo -e "${GREEN}All builds complete! Check /dist directory.${NC}"
