#!/usr/bin/env bash

# Installs a pinned release of bashunit (https://bashunit.com) into lib/.
# Usage: ./tools/install-bashunit.sh

set -euo pipefail

BASHUNIT_VERSION="0.40.0"
BASHUNIT_SHA256="0ee0474803b6e88e7dfa4f4c2486ea8f8e53fd8324134a9fe604ec3df8b5e72c"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$DIR/.."
TARGET="$PROJECT_ROOT/lib/bashunit"

if [[ -x "$TARGET" ]] && sha256sum "$TARGET" | grep -q "^$BASHUNIT_SHA256 "; then
	echo "bashunit $BASHUNIT_VERSION already installed at lib/bashunit"
	exit 0
fi

echo "Downloading bashunit $BASHUNIT_VERSION..."
mkdir -p "$PROJECT_ROOT/lib"
# Download to a temp file and move into place only after the checksum
# verifies, so an interrupted download never leaves a broken lib/bashunit.
TMP_FILE="$TARGET.tmp"
curl -fsSL -o "$TMP_FILE" \
	"https://github.com/TypedDevs/bashunit/releases/download/$BASHUNIT_VERSION/bashunit"

echo "$BASHUNIT_SHA256  $TMP_FILE" | sha256sum -c - >/dev/null || {
	echo "Error: checksum verification failed for bashunit download." >&2
	rm -f "$TMP_FILE"
	exit 1
}

chmod +x "$TMP_FILE"
mv "$TMP_FILE" "$TARGET"
echo "Installed bashunit $BASHUNIT_VERSION at lib/bashunit"
