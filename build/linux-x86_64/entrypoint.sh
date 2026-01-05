#!/bin/sh
SELF_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
# Force usage of bundled binaries
export PATH="$SELF_DIR/bin:$PATH"
# Execute the main script using the bundled bash
exec "$SELF_DIR/bin/bash" "$SELF_DIR/main.sh" "$@"
