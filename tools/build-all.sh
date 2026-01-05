#!/usr/bin/env bash

# Professional Standalone Bash Builder (SFX)
# Bundles: bash + busybox (all-in-one utils) + curl + jq + script
# Targets: Linux (x64/ARM), Windows (x64)

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$DIR/.."
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"

# Tool Versions
JQ_VERSION="1.7.1"
BASH_STATIC_URL="https://github.com/robxu9/bash-static/releases/latest/download"
CURL_STATIC_URL="https://github.com/moparisthebest/static-curl/releases/latest/download"
BUSYBOX_W32_URL="https://github.com/rmayo/busybox-w32/releases/latest/download/busybox64.exe"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Building Standalone Bash Bundles...${NC}"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# 1. Generate the Monolith
echo "Generating monolith script..."
"$DIR/bundle.sh"
MONOLITH="$DIST_DIR/cloudflare-dns-updater-monolith.sh"

create_entrypoint() {
	local target_dir=$1
	cat <<'EOF' >"$target_dir/entrypoint.sh"
#!/bin/sh
# Professional SFX Entrypoint
SELF_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# Identify the host original PWD (provided by makeself)
ORIGINAL_PWD="${MAKESELF_PWD:-$PWD}"
export MAKESELF_PWD="$ORIGINAL_PWD"

# Internal PATH setup
export PATH="$SELF_DIR/bin:$PATH"

# Execute using bundled bash
exec "$SELF_DIR/bin/bash" "$SELF_DIR/main.sh" "$@"
EOF
	chmod +x "$target_dir/entrypoint.sh"
}

build_linux() {
	local arch=$1 # x86_64, aarch64
	local curl_arch=$arch
	[[ "$arch" == "x86_64" ]] && curl_arch="amd64"
	local jq_arch=$arch
	[[ "$arch" == "x86_64" ]] && jq_arch="amd64"
	[[ "$arch" == "aarch64" ]] && jq_arch="arm64"

	echo -e "${BLUE}Building bundle for Linux $arch...${NC}"
	local work_dir="$BUILD_DIR/linux-$arch"
	local bin_dir="$work_dir/bin"
	mkdir -p "$bin_dir"

	echo "  - Downloading static toolchain..."
	curl -L -s -o "$bin_dir/bash" "${BASH_STATIC_URL}/bash-linux-$arch"
	curl -L -s -o "$bin_dir/jq" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${jq_arch}"
	curl -L -s -o "$bin_dir/curl" "${CURL_STATIC_URL}/curl-$curl_arch"

	# BusyBox for coreutils (sed, grep, etc)
	local bb_url="https://busybox.net/downloads/binaries/1.37.0-x86_64-linux-musl/busybox"
	[[ "$arch" == "aarch64" ]] && bb_url="https://busybox.net/downloads/binaries/1.37.0-armv8l/busybox"
	curl -L -s -o "$bin_dir/busybox" "$bb_url"

	chmod +x "$bin_dir/"*

	# Setup symlinks
	for tool in sed grep awk cat sleep date mktemp head tail cut tr wc ps; do
		ln -sf busybox "$bin_dir/$tool"
	done

	cp "$MONOLITH" "$work_dir/main.sh"
	create_entrypoint "$work_dir"

	echo "  - Creating SFX binary..."
	if command -v makeself >/dev/null 2>&1; then
		# --quiet: hide extraction msgs
		# --noprogress: hide progress bar
		# --nox11: no xterm
		makeself --quiet --noprogress --nox11 "$work_dir" "$DIST_DIR/cf-updater-linux-$arch.run" "Cloudflare DNS Updater" "./entrypoint.sh"
		echo -e "${GREEN}  ✔ Created $DIST_DIR/cf-updater-linux-$arch.run${NC}"
	else
		tar -czf "$DIST_DIR/cf-updater-linux-$arch.tar.gz" -C "$work_dir" .
	fi
}

build_windows() {
	echo -e "${BLUE}Building bundle for Windows x64...${NC}"
	local work_dir="$BUILD_DIR/windows-x64"
	mkdir -p "$work_dir"

	echo "  - Downloading BusyBox-w32 engine..."
	curl -L -s -o "$work_dir/busybox.exe" "$BUSYBOX_W32_URL"
	cp "$MONOLITH" "$work_dir/main.sh"

	cat <<'EOF' >"$work_dir/cf-updater.bat"
@echo off
set "DIR=%~dp0"
"%DIR%busybox.exe" bash "%DIR%main.sh" %*
EOF

	echo "  - Packaging ZIP..."
	(cd "$work_dir" && tar -acf "$DIST_DIR/cf-updater-windows-x64.zip" *)
	echo -e "${GREEN}  ✔ Created $DIST_DIR/cf-updater-windows-x64.zip${NC}"
}

# Run
if [[ "$1" == "--linux-amd64" ]]; then
	build_linux "x86_64"
elif [[ "$1" == "--windows" ]]; then
	build_windows
else
	build_linux "x86_64"
	build_linux "aarch64"
	build_windows
fi

echo -e "${GREEN}Build process finished.${NC}"
