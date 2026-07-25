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

# --- bundled toolchain on PATH ---

function test_monolith_adds_bundled_bin_to_path() {
	# Without this the bundled jq is never reachable and the binary silently
	# falls back to the sed parser, which is what shipped until now.
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains 'export PATH="$PATH:$DIR/bin"' "$(cat "$MONOLITH")"
}

function test_bundled_bin_is_a_fallback_not_an_override() {
	# Appended, never prepended: a host with its own jq keeps using it.
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_not_contains 'export PATH="$DIR/bin:$PATH"' "$(cat "$MONOLITH")"
}

# --- toolchain download guard ---

BUILDER="$PROJECT_ROOT/tools/build-all.sh"

function test_downloads_use_failing_curl() {
	# "curl -L -s -o" without --fail writes the 404 body to the destination
	# and exits 0, which is how a 258-byte HTML page shipped as busybox.
	assert_not_contains 'curl -L -s -o' "$(cat "$BUILDER")"
	assert_contains 'curl -fsSL' "$(cat "$BUILDER")"
}

# fetch() lives in a build script, so the tests source just the helpers they
# need. expected_sha256 can be overridden per case: the digests in the builder
# belong to real upstream assets, which a fixture cannot reproduce.
function run_fetch() {
	local dest="$1" src="$2" digest="${3:-}"
	(
		cd "$PROJECT_ROOT" || exit 1
		bash -c '
			source <(sed -n "/^expected_sha256()/,/^}/p;/^sha256_of()/,/^}/p;/^fetch()/,/^}/p" tools/build-all.sh)
			if [[ -n "'"$digest"'" ]]; then
				expected_sha256() { echo "'"$digest"'"; }
			fi
			fetch "'"$dest"'" "file://'"$src"'"
		' 2>&1
	)
}

function test_fetch_rejects_html_error_pages() {
	local tmp out
	tmp=$(mktemp -d)
	printf '<!DOCTYPE HTML><html><body>404 Not Found</body></html>' >"$tmp/fake"
	out=$(run_fetch "$tmp/dest" "$tmp/fake")
	rm -rf "$tmp"
	assert_contains "Suspiciously small download" "$out"
}

function test_fetch_rejects_non_executable_payload() {
	local tmp out
	tmp=$(mktemp -d)
	# Large enough to clear the size floor, still not an executable
	head -c 200000 /dev/zero | tr '\0' 'x' >"$tmp/fake"
	out=$(run_fetch "$tmp/dest" "$tmp/fake")
	rm -rf "$tmp"
	assert_contains "not an executable" "$out"
}

function test_fetch_accepts_a_matching_executable() {
	local tmp out digest
	tmp=$(mktemp -d)
	cp "$(command -v bash)" "$tmp/fake"
	digest=$(sha256sum "$tmp/fake" | cut -d' ' -f1)
	out=$(run_fetch "$tmp/dest" "$tmp/fake" "$digest")
	local mode=""
	[[ -x "$tmp/dest" ]] && mode="executable"
	rm -rf "$tmp"
	assert_empty "$out"
	assert_same "executable" "$mode"
}

function test_fetch_rejects_a_checksum_mismatch() {
	local tmp out
	tmp=$(mktemp -d)
	cp "$(command -v bash)" "$tmp/fake"
	# A real executable, correct size, wrong content for that digest
	out=$(run_fetch "$tmp/dest" "$tmp/fake" \
		"0000000000000000000000000000000000000000000000000000000000000000")
	rm -rf "$tmp"
	assert_contains "Checksum mismatch" "$out"
}

function test_unknown_asset_without_a_recorded_digest_is_refused() {
	local tmp out
	tmp=$(mktemp -d)
	cp "$(command -v bash)" "$tmp/brand-new-tool"
	out=$(run_fetch "$tmp/dest" "$tmp/brand-new-tool")
	rm -rf "$tmp"
	assert_contains "No SHA-256 recorded" "$out"
}

function test_windows_jq_is_not_a_busybox_copy() {
	# jq.exe used to be a copy of busybox, so "command -v jq" succeeded and
	# the first actual call failed.
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_not_contains 'cp "$bin_dir/bash.exe" "$bin_dir/jq.exe"' "$(cat "$BUILDER")"
	assert_contains 'jq-windows-amd64.exe' "$(cat "$BUILDER")"
}

function test_windows_shell_url_points_at_upstream() {
	# The old URL was a repository that does not exist.
	assert_not_contains 'rmayo/busybox-w32' "$(cat "$BUILDER")"
	assert_contains 'frippery.org/files/busybox/busybox-w32-' "$(cat "$BUILDER")"
}

# --- supply chain ---

function test_every_download_url_is_version_pinned() {
	# "latest/download" changes the payload under us and makes a recorded
	# checksum impossible to keep valid.
	assert_not_contains 'releases/latest/download' "$(cat "$BUILDER")"
}

function test_recorded_digests_cover_every_fetched_asset() {
	# Each asset the builder fetches must have an entry, or the build stops.
	local missing=""
	local asset
	for asset in bash-linux-x86_64 bash-linux-aarch64 bash-macos-x86_64 \
		bash-macos-aarch64 jq-linux-amd64 jq-linux-arm64 jq-macos-amd64 \
		jq-macos-arm64 jq-windows-amd64.exe; do
		grep -q "$asset)" "$BUILDER" || missing+=" $asset"
	done
	assert_empty "$missing"
}
