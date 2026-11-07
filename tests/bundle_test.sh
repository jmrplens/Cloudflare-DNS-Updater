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

# --- no Windows target ---

function test_no_windows_build_target() {
	# The program needs a real bash: BusyBox ash cannot even parse the
	# monolith (arrays, BASH_SOURCE, here-strings), and there is no static
	# single-file bash for Windows to bundle instead. Reintroducing a Windows
	# artifact needs a windows-latest job that actually runs it.
	assert_not_contains 'mingw' "$(cat "$BUILDER")"
	# Indented comments count as comments too, hence the leading-space class
	assert_not_contains 'busybox' "$(grep -v '^[[:space:]]*#' "$BUILDER")"
	assert_not_contains 'jq-windows' "$(cat "$BUILDER")"
}

function test_release_workflow_publishes_no_exe() {
	local wf
	wf=$(cat "$PROJECT_ROOT/.github/workflows/binaries.yml")
	assert_not_contains 'windows' "$wf"
	assert_not_contains '.exe' "$wf"
}

function test_monolith_still_carries_windows_runtime_fallbacks() {
	# Running from source under Git Bash, MSYS2 or WSL stays supported, so
	# the powershell/curl.exe/jq.exe detection must not be collateral damage.
	local mono
	mono=$(cat "$MONOLITH")
	assert_contains 'powershell.exe' "$mono"
	assert_contains 'curl.exe' "$mono"
	assert_contains 'jq.exe' "$mono"
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
		jq-macos-arm64; do
		grep -q "$asset)" "$BUILDER" || missing+=" $asset"
	done
	assert_empty "$missing"
}

# --- every script under tools/ ---

# The guards above read build-all.sh only. An older builder that nothing
# called any more slipped past them: it fetched a static curl from
# releases/latest with a silent curl and packed it under the release asset
# names. These read every script in tools/, so a leftover fails here too.

function test_every_curl_in_tools_fails_on_http_errors() {
	local silent
	silent=$(grep -hE '(^|[[:space:](])curl[[:space:]]+-' "$PROJECT_ROOT"/tools/*.sh |
		grep -v '^[[:space:]]*#' |
		grep -vE '[[:space:]](-[[:alpha:]]*f[[:alpha:]]*|--fail)([[:space:]]|$)' || true)
	assert_empty "$silent"
}

function test_no_tool_downloads_from_latest() {
	assert_not_contains 'releases/latest/download' "$(cat "$PROJECT_ROOT"/tools/*.sh)"
}

function test_no_tool_bundles_curl() {
	# The binaries carry bash and jq. curl always comes from the host.
	local tools
	tools=$(cat "$PROJECT_ROOT"/tools/*.sh)
	assert_not_contains 'static-curl' "$tools"
	assert_not_contains 'bin/curl' "$tools"
}

# --- target architecture ---

function test_launcher_is_built_for_the_target_not_the_builder() {
	# A bare "gcc" ignores the target: the published linux-aarch64 binary is
	# an x86-64 ELF and cannot start on ARM at all.
	assert_contains 'verify_launcher_arch' "$(cat "$BUILDER")"
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains '${arch}-linux-gnu-gcc' "$(cat "$BUILDER")"
	# shellcheck disable=SC2016 # asserting on literal source text
	assert_contains '-arch "$apple_arch"' "$(cat "$BUILDER")"
}

function test_verify_launcher_arch_rejects_a_mismatch() {
	local out
	out=$(cd "$PROJECT_ROOT" && bash -c '
		source <(sed -n "/^verify_launcher_arch()/,/^}/p" tools/build-all.sh)
		verify_launcher_arch "$(command -v bash)" "aarch64"
	' 2>&1)
	assert_contains "wrong architecture" "$out"
}

function test_verify_launcher_arch_accepts_the_host_arch() {
	local out
	out=$(cd "$PROJECT_ROOT" && bash -c '
		source <(sed -n "/^verify_launcher_arch()/,/^}/p" tools/build-all.sh)
		verify_launcher_arch "$(command -v bash)" "$(uname -m)"
	' 2>&1)
	assert_empty "$out"
}

function test_workflow_cross_compiles_and_checks_the_arm_target() {
	local wf
	wf=$(cat "$PROJECT_ROOT/.github/workflows/binaries.yml")
	assert_contains 'gcc-aarch64-linux-gnu' "$wf"
	assert_contains 'Verify artifact architecture' "$wf"
}

# --- the HTTP client check ---
#
# The source launcher puts /usr/bin and the other system directories back on
# PATH, so a narrowed PATH cannot hide the host's curl from it. These tests
# hide the clients from `command -v` instead, which is how the program looks
# for them, through a file that BASH_ENV sources into every bash the launcher
# starts. A client defined there as a function stays visible: that is how a
# test hands the program a stub wget.

function client_env() {
	local env_file="$1" stubs="$2"
	cat >"$env_file" <<'HIDE'
command() {
	if [[ "$1" == "-v" ]]; then
		case "$2" in
		curl | curl.exe | wget | wget2 | pwsh | pwsh.exe | powershell.exe)
			declare -F "$2" >/dev/null || return 1
			;;
		esac
	fi
	builtin command "$@"
}
HIDE
	printf '%s\n' "$stubs" >>"$env_file"
}

# A config of its own per test: the lock is per config file, so tests that
# share one could see each other as "already running" under --parallel.
function own_config() {
	local cfg
	cfg=$(mktemp "${TMPDIR:-/tmp}/launcher_client_XXXXXX")
	cp "$TESTS_DIR/fixtures/main_config.yaml" "$cfg"
	echo "$cfg"
}

function test_launcher_refuses_without_an_http_client() {
	local env cfg out status
	env=$(mktemp)
	cfg=$(own_config)
	client_env "$env" ""
	out=$(BASH_ENV="$env" "$PROJECT_ROOT/cloudflare-dns-updater.sh" "$cfg" 2>&1)
	status=$?
	rm -f "$env" "$cfg"
	assert_same 1 "$status"
	assert_contains "no HTTP client this program can use was found" "$out"
	assert_contains "curl, GNU Wget 1.15 or later (or GNU Wget2), or" "$out"
	assert_contains "PowerShell (pwsh, or powershell.exe under Git Bash, MSYS2 or WSL)" "$out"
	assert_contains "apt install curl" "$out"
	assert_not_contains "Loading configuration" "$out"
}

function test_launcher_names_busybox_wget_when_it_is_the_only_client() {
	local env cfg out status
	env=$(mktemp)
	cfg=$(own_config)
	client_env "$env" 'wget() {
	echo "wget: unrecognized option '"'"'--version'"'"'" >&2
	echo "BusyBox v1.37.0 (2026-01-10 15:38:28 UTC) multi-call binary." >&2
	return 1
}'
	out=$(BASH_ENV="$env" "$PROJECT_ROOT/cloudflare-dns-updater.sh" "$cfg" 2>&1)
	status=$?
	rm -f "$env" "$cfg"
	assert_same 1 "$status"
	assert_contains "The wget found here is BusyBox wget" "$out"
	assert_contains "Install curl" "$out"
}

# A GNU Wget that answers like the IP services and the Cloudflare API, and
# writes down every request it was asked to send.
# shellcheck disable=SC2016 # stub code
GNU_WGET_STUB='wget() {
	[[ "$1" == "--version" ]] && { echo "GNU Wget 1.21.4 built on linux-gnu."; return 0; }
	printf "%s\n" "$*" >>"$WGET_LOG"
	local url="${*: -1}"
	case " $* " in
	*" -6 "*) return 4 ;;
	esac
	case "$url" in
	https://icanhazip.com) echo "198.51.100.7" ;;
	*/dns_records/batch) echo "{\"success\":true,\"result\":{\"puts\":[{\"id\":\"rec-1\",\"name\":\"home.example.com\",\"content\":\"198.51.100.7\"}]}}" ;;
	*/dns_records*) echo "{\"success\":true,\"result\":[{\"id\":\"rec-1\",\"name\":\"home.example.com\",\"type\":\"A\",\"content\":\"192.0.2.1\",\"proxied\":false}],\"result_info\":{\"total_pages\":1}}" ;;
	*) return 4 ;;
	esac
}'

function test_launcher_runs_the_update_with_gnu_wget_and_no_curl() {
	local env cfg log out status requests
	env=$(mktemp)
	log=$(mktemp)
	cfg=$(mktemp "${TMPDIR:-/tmp}/launcher_client_XXXXXX")
	cat >"$cfg" <<'CFG'
cloudflare:
  zone_id: "zone-1"
  api_token: "token-1"
options:
  interface: "no-such-interface"
domains:
  - name: "home.example.com"
    ip_type: ipv4
    proxied: false
CFG
	client_env "$env" "$GNU_WGET_STUB"
	out=$(WGET_LOG="$log" BASH_ENV="$env" "$PROJECT_ROOT/cloudflare-dns-updater.sh" "$cfg" 2>&1)
	status=$?
	requests=$(cat "$log")
	rm -f "$env" "$cfg" "$log"
	assert_same 0 "$status"
	assert_contains "Detected IPv4: 198.51.100.7" "$out"
	assert_contains "Successfully updated 1 records!" "$out"
	assert_contains "--method=GET --header=Authorization: Bearer token-1" "$requests"
	assert_contains '--method=POST --header=Authorization: Bearer token-1 --header=Content-Type: application/json --body-data={"puts":[{"id":"rec-1","type":"A","name":"home.example.com","content":"198.51.100.7","ttl":1,"proxied":false}]}' "$requests"
}

function test_monolith_refuses_without_an_http_client() {
	# The bundle leaves PATH as it finds it, so here a PATH that holds the
	# usual tools and no HTTP client is enough.
	local sandbox cfg out status tool
	sandbox=$(mktemp -d)
	cfg=$(own_config)
	for tool in bash dirname cksum cut cat mkdir touch date rm flock ps tr sed grep awk head tail wc stat basename; do
		command -v "$tool" >/dev/null 2>&1 && ln -s "$(command -v "$tool")" "$sandbox/$tool"
	done
	out=$(PATH="$sandbox" "$sandbox/bash" "$MONOLITH" "$cfg" 2>&1)
	status=$?
	rm -rf "$sandbox" "$cfg"
	assert_same 1 "$status"
	assert_contains "no HTTP client this program can use was found" "$out"
}
