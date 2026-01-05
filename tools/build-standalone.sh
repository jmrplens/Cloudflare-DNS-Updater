#!/usr/bin/env bash

# Standalone Binary Builder
# Bundles the script + static curl + static jq into a single executable

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$DIR/.."
BUILD_DIR="$PROJECT_ROOT/build"
OUT_DIR="$PROJECT_ROOT/dist"

# Config
VERSION="1.0.0"
JQ_VERSION="1.7.1"
CURL_STATIC_URL="https://github.com/moparisthebest/static-curl/releases/latest/download"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Preparing build environment...${NC}"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# 1. Generate the Monolith Script
echo "Generating monolith script..."
"$DIR/bundle.sh"
MONOLITH="$PROJECT_ROOT/cloudflare-dns-updater.sh" # Assumed output of bundle.sh

build_linux() {
    local arch=$1 # x86_64, aarch64
    local target_name="cf-updater-linux-$arch"
    
    echo -e "${BLUE}Building for Linux $arch...${NC}"
    local work_dir="$BUILD_DIR/linux-$arch"
    mkdir -p "$work_dir/bin"
    
    # Download static jq
    echo "  - Downloading static jq..."
    local jq_arch=$arch
    [[ "$arch" == "aarch64" ]] && jq_arch="arm64"
    curl -L -s -o "$work_dir/bin/jq" "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${jq_arch}"
    
    # Download static curl
    echo "  - Downloading static curl..."
    curl -L -s -o "$work_dir/bin/curl" "${CURL_STATIC_URL}/curl-$arch"
    
    chmod +x "$work_dir/bin/"*
    
    # Copy script
    cp "$MONOLITH" "$work_dir/main.sh"
    chmod +x "$work_dir/main.sh"
    
    # Package with makeself (if installed) or simple tar-based SFX
    if command -v makeself >/dev/null 2>&1; then
        makeself "$work_dir" "$OUT_DIR/$target_name" "Cloudflare DNS Updater" "./main.sh"
    else
        echo "Warning: makeself not found. Creating a simple tarball instead."
        tar -czf "$OUT_DIR/${target_name}.tar.gz" -C "$work_dir" .
    fi
}

# Execute builds
build_linux "x86_64"
build_linux "aarch64"

echo -e "${GREEN}Builds complete! Check the /dist directory.${NC}"
