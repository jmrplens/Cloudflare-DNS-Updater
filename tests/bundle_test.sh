#!/usr/bin/env bash
# Tests for tools/bundle.sh output (monolith build)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."
MONOLITH="$PROJECT_ROOT/dist/cloudflare-dns-updater-monolith.sh"

function set_up_before_script() {
	(cd "$PROJECT_ROOT" && ./tools/bundle.sh >/dev/null)
}

function test_monolith_has_valid_syntax() {
	bash -n "$MONOLITH"
	assert_successful_code
}

function test_monolith_lockfile_stores_real_pid() {
	# A previous bug bundled 'echo $' (a literal dollar sign) instead of
	# the PID, which broke the stale-lock detection in built binaries.
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains 'echo $$ >"$LOCKFILE"' "$(cat "$MONOLITH")"
}

function test_monolith_uses_flock_when_available() {
	assert_contains 'flock -n 200' "$(cat "$MONOLITH")"
}

function test_launcher_help_flag_works() {
	assert_contains "Usage:" "$("$PROJECT_ROOT/cloudflare-dns-updater.sh" --help 2>/dev/null)"
}
