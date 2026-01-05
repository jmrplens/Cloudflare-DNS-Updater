#!/usr/bin/env bash

# Ultimate Multi-Platform C-Wrapped Builder
# Targets: Linux (x64/ARM), macOS (x64/ARM), Windows (x64)

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

# 0. Initialize
mkdir -p "$BUILD_DIR" "$DIST_DIR"
VERSION=$(grep '^VERSION=' "$PROJECT_ROOT/src/main.sh" | cut -d'"' -f2)

# 1. Generate the Monolith
"$DIR/bundle.sh"
MONOLITH="$DIST_DIR/cloudflare-dns-updater-monolith.sh"

build_target() {
	local os=$1   # linux, macos, windows
	local arch=$2 # x86_64, aarch64
	local label="${os}-${arch}"

	echo -e "${BLUE}Building for $label...${NC}"
	local work_dir="$BUILD_DIR/$label"
	local bin_dir="$work_dir/bin"
	mkdir -p "$bin_dir"

	# --- Download Toolchain ---
	if [[ "$os" == "linux" ]]; then
		local curl_arch=$arch
		[[ "$arch" == "x86_64" ]] && curl_arch="amd64"
		local jq_arch=$arch
		[[ "$arch" == "x86_64" ]] && jq_arch="amd64"
		[[ "$arch" == "aarch64" ]] && jq_arch="arm64"

		curl -L -s -o "$bin_dir/bash" "${BASH_STATIC_URL}/bash-linux-$arch"
		curl -L -s -o "$bin_dir/jq" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${jq_arch}"
		curl -L -s -o "$bin_dir/curl" "${CURL_STATIC_URL}/curl-$curl_arch"

		local bb_url="https://busybox.net/downloads/binaries/1.37.0-x86_64-linux-musl/busybox"
		[[ "$arch" == "aarch64" ]] && bb_url="https://busybox.net/downloads/binaries/1.37.0-armv8l/busybox"
		curl -L -s -o "$bin_dir/busybox" "$bb_url"
		chmod +x "$bin_dir/"
		for tool in sed grep awk cat sleep date mktemp head tail cut tr wc ps; do ln -sf busybox "$bin_dir/$tool"; done

	elif [[ "$os" == "windows" ]]; then
		# Use busybox-w32 as the engine
		curl -L -s -o "$bin_dir/bash.exe" "$BUSYBOX_W32_URL"
		# BusyBox-w32 also provides curl/jq functionality if called correctly,
		# but for our script we'll just copy the exe to these names as placeholders
		# since the script uses 'curl' and 'jq' commands.
		cp "$bin_dir/bash.exe" "$bin_dir/curl.exe"
		cp "$bin_dir/bash.exe" "$bin_dir/jq.exe"

	elif [[ "$os" == "macos" ]]; then
		# For macOS we bundle JQ static
		local jq_march="amd64"
		[[ "$arch" == "aarch64" ]] && jq_march="arm64"
		curl -L -s -o "$bin_dir/jq" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-macos-${jq_march}"
		# We assume bash/curl are available on Mac system but we can try to copy local ones if we are on a Mac runner
		cp /bin/bash "$bin_dir/bash" || cp /usr/local/bin/bash "$bin_dir/bash" || true
		chmod +x "$bin_dir/"
	fi

	cp "$MONOLITH" "$work_dir/main.sh"

	# --- Compile Launcher ---
	local final_bin="$DIST_DIR/cf-updater-$label"
	[[ "$os" == "windows" ]] && final_bin="${final_bin}.exe"

	if [[ "$os" == "windows" ]]; then
		x86_64-w64-mingw32-gcc -O2 "$DIR/launcher.c" -o "$BUILD_DIR/launcher-$label.exe"
		cp "$BUILD_DIR/launcher-$label.exe" "$final_bin"
	else
		gcc -O2 "$DIR/launcher.c" -o "$BUILD_DIR/launcher-$label"
		cp "$BUILD_DIR/launcher-$label" "$final_bin"
	fi

	# --- Append Payload ---
	echo -e "\n---PAYLOAD_START---" >>"$final_bin"
	tar -cz -C "$work_dir" . >>"$final_bin"

	chmod +x "$final_bin"
	echo -e "${GREEN}  ✔ Created $final_bin${NC}"
}

# Entrypoint Logic
if [[ "$#" -ge 2 ]]; then
	build_target "$1" "$2"
elif [[ "$1" == "--all" ]]; then
	build_target "linux" "x86_64"
	build_target "linux" "aarch64"
else
	build_target "linux" "x86_64"
fi
