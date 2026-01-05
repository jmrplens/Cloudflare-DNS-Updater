#!/usr/bin/env bash

# Ultimate C-Powered Standalone Binary Builder
# Bundles: launcher(C) + bash + busybox + curl + jq + script
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

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Building Professional C-Wrapped Bundles...${NC}"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# 1. Generate the Monolith
"$DIR/bundle.sh"
MONOLITH="$DIST_DIR/cloudflare-dns-updater-monolith.sh"

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

	local bb_url="https://busybox.net/downloads/binaries/1.37.0-x86_64-linux-musl/busybox"
	[[ "$arch" == "aarch64" ]] && bb_url="https://busybox.net/downloads/binaries/1.37.0-armv8l/busybox"
	curl -L -s -o "$bin_dir/busybox" "$bb_url"

	chmod +x "$bin_dir/"*
	for tool in sed grep awk cat sleep date mktemp head tail cut tr wc ps; do
		ln -sf busybox "$bin_dir/$tool"
	done

	cp "$MONOLITH" "$work_dir/main.sh"

	echo "  - Compiling C Launcher..."
	gcc -O2 "$DIR/launcher.c" -o "$BUILD_DIR/launcher-$arch"

	echo "  - Assembling final binary..."
	local final_bin="$DIST_DIR/cf-updater-linux-$arch"
	cp "$BUILD_DIR/launcher-$arch" "$final_bin"
	echo -e "\n---PAYLOAD_START---" >>"$final_bin"
	tar -cz -C "$work_dir" . >>"$final_bin"

	chmod +x "$final_bin"
	echo -e "${GREEN}  ✔ Created $final_bin${NC}"
}

# Run local build
build_linux "x86_64"

echo -e "${GREEN}Build complete.${NC}"
