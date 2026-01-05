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
