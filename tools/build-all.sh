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
JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}"
BASH_STATIC_URL="https://github.com/robxu9/bash-static/releases/latest/download"
# busybox-w32 upstream (Ron Yorston). The previous URL pointed at a
# misspelled GitHub account whose repository does not exist, so every
# Windows build downloaded an error page instead of a shell.
BUSYBOX_W32_URL="https://frippery.org/files/busybox/busybox64.exe"

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

# Download a binary into the payload, or abort the build.
#
# Every toolchain download used to be a silent, non-failing curl. Without
# --fail, curl happily writes a 404 page to the destination and exits 0.
# Three releases shipped that way, with a 258-byte HTML error document
# standing in for busybox and a 9-byte error string standing in for the
# whole Windows shell. Failing loudly here is what keeps a dead upstream
# from reaching a release.
fetch() {
	local dest="$1"
	local url="$2"

	if ! curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url"; then
		echo "::error::Download failed: $url" >&2
		exit 1
	fi

	# A 200 response can still be the wrong thing: an error page, an HTML
	# redirect stub, or a truncated file. Executables are never any of those.
	local size
	size=$(wc -c <"$dest" | tr -d '[:space:]')
	if [[ "$size" -lt 100000 ]]; then
		echo "::error::Suspiciously small download ($size bytes), expected an executable: $url" >&2
		exit 1
	fi

	# ELF (Linux), Mach-O (macOS) and PE (Windows) all start with a magic
	# number; HTML starts with '<'.
	local magic
	magic=$(head -c 2 "$dest" | od -An -tx1 | tr -d ' \n')
	case "$magic" in
	7f45 | cffa | cefa | feed | 4d5a) ;; # ELF, Mach-O (LE/BE/fat), PE
	*)
		echo "::error::Download is not an executable (magic: $magic): $url" >&2
		head -c 200 "$dest" >&2
		exit 1
		;;
	esac

	chmod +x "$dest"
}

build_target() {
	local os=$1   # linux, macos, windows
	local arch=$2 # x86_64, aarch64
	local label="${os}-${arch}"

	echo -e "${BLUE}Building for $label...${NC}"
	local work_dir="$BUILD_DIR/$label"
	local bin_dir="$work_dir/bin"
	mkdir -p "$bin_dir"

	# --- Download Toolchain ---
	# Only what the payload actually needs. The launcher execs the bundled
	# bash directly; jq rides along because it is the one tool a host is
	# genuinely likely to be missing (there is a sed fallback, but it is
	# slower and more limited). Everything else the program calls (curl,
	# sed, grep, ...) is resolved from the host, as it always was: nothing
	# ever put this directory on PATH, so the curl and busybox that used to
	# be bundled here were dead weight.
	if [[ "$os" == "linux" ]]; then
		local jq_arch=$arch
		[[ "$arch" == "x86_64" ]] && jq_arch="amd64"
		[[ "$arch" == "aarch64" ]] && jq_arch="arm64"

		fetch "$bin_dir/bash" "${BASH_STATIC_URL}/bash-linux-$arch"
		fetch "$bin_dir/jq" "${JQ_URL}/jq-linux-${jq_arch}"

	elif [[ "$os" == "windows" ]]; then
		# busybox-w32 is the shell on Windows: the launcher execs it as
		# bash.exe. It provides no jq, so jq is fetched separately instead
		# of being a copy of busybox under a name that would satisfy
		# "command -v jq" and then fail on the first call.
		fetch "$bin_dir/bash.exe" "$BUSYBOX_W32_URL"
		fetch "$bin_dir/jq.exe" "${JQ_URL}/jq-windows-amd64.exe"

	elif [[ "$os" == "macos" ]]; then
		local jq_march="amd64"
		[[ "$arch" == "aarch64" ]] && jq_march="arm64"
		fetch "$bin_dir/jq" "${JQ_URL}/jq-macos-${jq_march}"
		# A static build rather than a copy of the runner's /bin/bash,
		# which is bash 3.2 and dynamically linked against that runner.
		fetch "$bin_dir/bash" "${BASH_STATIC_URL}/bash-macos-$arch"
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
