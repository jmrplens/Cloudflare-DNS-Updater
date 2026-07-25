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

# --- positional config path (documented in --help and in the docs site) ---

# The launcher hands off to main.sh, which would hit the network. Reading the
# first lines is enough to see which config it resolved: the pipe closes and
# the run dies on SIGPIPE before any API call.
function launcher_head() {
	"$PROJECT_ROOT/cloudflare-dns-updater.sh" "$@" 2>&1 | head -n 6
}

function test_launcher_uses_config_path_argument() {
	assert_contains "Loading configuration from $TESTS_DIR/fixtures/main_config.yaml" \
		"$(launcher_head "$TESTS_DIR/fixtures/main_config.yaml")"
}

function test_launcher_defaults_to_bundled_config_without_argument() {
	# Asserted on the source: running the launcher with no argument would
	# start a real update against whatever config sits next to it.
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains '[[ -z "$CONFIG_FILE" ]] && CONFIG_FILE="$DIR/cloudflare-dns.yaml"' \
		"$(cat "$PROJECT_ROOT/cloudflare-dns-updater.sh")"
}

function test_launcher_reports_missing_config_path() {
	local out
	out=$("$PROJECT_ROOT/cloudflare-dns-updater.sh" /nonexistent/path/to/config.yaml 2>&1)
	assert_general_error
	assert_contains "not found" "$out"
}

function test_launcher_accepts_any_config_extension() {
	local cfg="/tmp/launcher_config_$$.yml"
	cp "$TESTS_DIR/fixtures/main_config.yaml" "$cfg"
	local out
	out=$(launcher_head "$cfg")
	rm -f "$cfg"
	assert_contains "Loading configuration from $cfg" "$out"
}

function test_launcher_lock_is_per_config_file() {
	# Two configs must not lock each other out. Same config, same lock.
	local a b
	a=$(printf '%s' "/etc/a.yaml" | cksum | cut -d' ' -f1)
	b=$(printf '%s' "/etc/b.yaml" | cksum | cut -d' ' -f1)
	assert_not_same "$a" "$b"
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains 'LOCKFILE="/tmp/cloudflare-dns-updater-$LOCK_KEY.lock"' \
		"$(cat "$PROJECT_ROOT/cloudflare-dns-updater.sh")"
}

function test_monolith_accepts_any_config_extension() {
	# The bundle used to only recognise arguments ending in .yaml, silently
	# ignoring any other path and falling back to the default config.
	assert_not_contains '== *.yaml' "$(cat "$MONOLITH")"
}

function test_monolith_lock_is_per_config_file() {
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains 'LOCKFILE="/tmp/cloudflare-dns-updater-$LOCK_KEY.lock"' "$(cat "$MONOLITH")"
}
