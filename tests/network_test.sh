#!/usr/bin/env bash
# Unit tests for src/network.sh (HTTP client wrapper)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/network.sh"
	HTTP_CLIENT="curl"
	STUBS=$(mktemp -d)
	# The wget path keeps its headers in a temporary file
	link_tools mktemp rm
}

function tear_down() {
	rm -rf "$STUBS"
}

# --- stub clients ---
#
# Each stub client is an executable in a directory of its own, and the code
# under test runs with that directory as its whole PATH, beside links to the
# few tools http_send needs: a client the test did not make is not there to
# find. A stub writes its arguments, one per line, to NAME.args beside
# itself, and answers with the script it was given.

function link_tools() {
	local tool
	for tool in "$@"; do
		ln -s "$(command -v "$tool")" "$STUBS/$tool"
	done
}

function make_stub() {
	local name="$1" script="$2"
	{
		printf '#!%s\n' "$BASH"
		printf 'printf "%%s\\n" "$@" >%q\n' "$STUBS/$name.args"
		printf '%s\n' "$script"
	} >"$STUBS/$name"
	chmod +x "$STUBS/$name"
}

# A stub that also keeps its stdin, where curl's config and PowerShell's
# request travel
function make_stdin_stub() {
	local name="$1" script="$2"
	make_stub "$name" "IFS= read -r -d '' request; printf '%s' \"\$request\" >$(printf %q "$STUBS/$name.stdin")
$script"
}

# A wget stub. Asked for its version, it answers with the line given.
# Otherwise it keeps its stdin, where the URL travels, and the startup file
# it was pointed at: both paths it was given ($WGETRC for GNU Wget, $WGET2RC
# for Wget2) in NAME.rcpath, the content in NAME.rc and, where stat is
# linked, the mode in NAME.rcmode. Then it runs the script.
# shellcheck disable=SC2016 # stub code
function make_wget_stub() {
	local name="$1" version="$2" script="$3" keep
	keep=$(printf %q "$STUBS/$name")
	make_stub "$name" "$(
		printf '[[ "$1" == "--version" ]] && { echo %q; exit 0; }\n' "$version"
		printf 'IFS= read -r -d "" request; printf "%%s" "$request" >%s.stdin\n' "$keep"
		printf 'printf "%%s\\n" "$WGETRC" "$WGET2RC" >%s.rcpath\n' "$keep"
		printf 'if [[ -f "$WGETRC" ]]; then\n'
		printf '\tIFS= read -r -d "" rc <"$WGETRC"; printf "%%s|" "$rc" >%s.rc\n' "$keep"
		printf '\t{ stat -c %%a "$WGETRC" || stat -f %%Lp "$WGETRC"; } >%s.rcmode 2>/dev/null\n' "$keep"
		printf 'fi\n'
		printf '%s\n' "$script"
	)"
}

# Runs a command in a subshell whose PATH holds the stubs and the linked
# tools and nothing else, after picking the client again from that PATH.
function with_stubs() {
	(
		PATH="$STUBS"
		http_detect_client
		"$@"
	)
}

function stub_args() {
	cat "$STUBS/$1.args"
}

# What a stub read on stdin, trailing newlines included (a command
# substitution would drop them), closed by a | so they show
function stub_stdin() {
	local request
	IFS= read -r -d '' request <"$STUBS/$1.stdin"
	printf '%s|' "$request"
}

# The startup file a wget stub was pointed at, closed by a |
function stub_wgetrc() {
	cat "$STUBS/$1.rc"
}

# The path of that file, which must be gone once the request is over
function stub_wgetrc_path() {
	local paths
	paths=$(cat "$STUBS/$1.rcpath")
	printf '%s\n' "${paths%%$'\n'*}"
}

# Stub scripts are literal code for the stub, not for this shell
# shellcheck disable=SC2016
GNU_WGET_VERSION='[[ "$1" == "--version" ]] && { echo "GNU Wget 1.21.4 built on linux-gnu."; exit 0; }'
GNU_WGET_LINE="GNU Wget 1.21.4 built on linux-gnu."
WGET2_LINE="GNU Wget2 2.2.0 - multithreaded metalink/file/website downloader"

# --- curl ---
#
# The URL and the headers go to curl as a config on its stdin (-K -), never
# on its command line, where any local user could read them with ps: the
# API token is in a header, the Telegram bot token and the Discord webhook
# token are in the URL.

function test_curl_get_keeps_the_url_and_headers_off_the_command_line() {
	make_stdin_stub curl 'printf "%s" "{\"success\":true}"'
	local out status
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "" \
		"Authorization: Bearer tok")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -s --connect-timeout 10 --max-time 30 -X GET -K -)" \
		"$(stub_args curl)"
	assert_same 'url = "https://api.example.com/records"
header = "Authorization: Bearer tok"
|' "$(stub_stdin curl)"
}

function test_curl_post_puts_only_the_body_on_the_command_line() {
	make_stdin_stub curl ''
	with_stubs http_request "POST" "https://api.example.com/batch" '{"puts":[]}' \
		"Authorization: Bearer tok" "Content-Type: application/json" >/dev/null
	assert_same "$(printf '%s\n' -s --connect-timeout 10 --max-time 30 -X POST \
		-d '{"puts":[]}' -K -)" "$(stub_args curl)"
	assert_same 'url = "https://api.example.com/batch"
header = "Authorization: Bearer tok"
header = "Content-Type: application/json"
|' "$(stub_stdin curl)"
}

function test_curl_config_escapes_backslashes_and_double_quotes() {
	make_stdin_stub curl ''
	with_stubs http_request "GET" 'https://api.example.com/a"b\c' "" \
		'X-Note: say "hi" \ bye' >/dev/null
	assert_same 'url = "https://api.example.com/a\"b\\c"
header = "X-Note: say \"hi\" \\ bye"
|' "$(stub_stdin curl)"
}

function test_http_request_fails_without_client() {
	HTTP_CLIENT=""
	assert_general_error "$(http_request "GET" "https://api.example.com" "" 2>/dev/null)"
}

function test_curl_ip_lookup_forces_the_family() {
	make_stdin_stub curl 'printf "%s\n" "192.0.2.10"'
	local out
	out=$(with_stubs http_get "https://icanhazip.com" 4)
	assert_same "192.0.2.10" "$out"
	assert_same "$(printf '%s\n' -s -4 --max-time 10 -K -)" "$(stub_args curl)"
	assert_same 'url = "https://icanhazip.com"
|' "$(stub_stdin curl)"
	with_stubs http_get "https://icanhazip.com" 6 >/dev/null
	assert_same "$(printf '%s\n' -s -6 --max-time 10 -K -)" "$(stub_args curl)"
}

function test_curl_ip_lookup_on_any_family_passes_no_empty_flag() {
	make_stdin_stub curl ''
	with_stubs http_get "https://icanhazip.com" >/dev/null
	# No stray "" argument between -s and --max-time
	assert_same "$(printf '%s\n' -s --max-time 10 -K -)" "$(stub_args curl)"
}

# --- GNU Wget and Wget2 ---
#
# The URL goes to wget on its stdin (-i -), the headers in a startup file
# only this user can read, removed once the request is over.

function test_wget_sends_an_api_request_without_curl() {
	make_wget_stub wget "$GNU_WGET_LINE" 'printf "%s" "{\"success\":true}"'
	local out status rcpaths
	out=$(with_stubs http_request "POST" "https://api.example.com/batch" '{"puts":[]}' \
		"Authorization: Bearer tok" "Content-Type: application/json")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -q -O - --content-on-error --method=POST \
		'--body-data={"puts":[]}' --dns-timeout=10 --connect-timeout=10 \
		--read-timeout=30 --tries=1 -i -)" "$(stub_args wget)"
	assert_same 'https://api.example.com/batch
|' "$(stub_stdin wget)"
	assert_same 'header = Authorization: Bearer tok
header = Content-Type: application/json
|' "$(stub_wgetrc wget)"
	# GNU Wget reads $WGETRC, Wget2 $WGET2RC: both name the same file
	rcpaths=$(cat "$STUBS/wget.rcpath")
	assert_same "${rcpaths%%$'\n'*}" "${rcpaths#*$'\n'}"
	assert_file_not_exists "$(stub_wgetrc_path wget)"
}

function test_wget_startup_file_is_readable_by_its_owner_only() {
	link_tools stat
	make_wget_stub wget "$GNU_WGET_LINE" ''
	with_stubs http_request "GET" "https://api.example.com/records" "" \
		"Authorization: Bearer tok" >/dev/null
	assert_same "600" "$(cat "$STUBS/wget.rcmode")"
	assert_file_not_exists "$(stub_wgetrc_path wget)"
}

# shellcheck disable=SC2016 # stub code
function test_wget_returns_the_body_of_an_http_error() {
	# GNU Wget keeps an error body only with --content-on-error, and exits 8
	# ("server issued an error response"). curl -s exits 0 with the body.
	make_wget_stub wget "$GNU_WGET_LINE" 'for arg in "$@"; do
	[[ "$arg" == "--content-on-error" ]] && printf "%s" "{\"success\":false,\"errors\":[{\"code\":10000}]}"
done
exit 8'
	local out status
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer bad")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":false,"errors":[{"code":10000}]}' "$out"
	assert_file_not_exists "$(stub_wgetrc_path wget)"
}

function test_wget_network_failure_fails_after_one_attempt() {
	# wget retries up to 20 times by default; curl never retries
	make_wget_stub wget "$GNU_WGET_LINE" 'exit 4'
	local out status
	out=$(with_stubs http_request "POST" "https://api.example.com/batch" '{"puts":[]}')
	status=$?
	assert_same 4 "$status"
	assert_empty "$out"
	assert_contains "--tries=1" "$(stub_args wget)"
	assert_file_not_exists "$(stub_wgetrc_path wget)"
}

function test_wget_ip_lookup_forces_the_family() {
	make_wget_stub wget "$GNU_WGET_LINE" 'printf "%s\n" "192.0.2.10"'
	local out
	out=$(with_stubs http_get "https://icanhazip.com" 4)
	assert_same "192.0.2.10" "$out"
	assert_same "$(printf '%s\n' -q -O - -4 --timeout=10 --tries=1 -i -)" "$(stub_args wget)"
	assert_same 'https://icanhazip.com
|' "$(stub_stdin wget)"
	assert_same '|' "$(stub_wgetrc wget)"
}

function test_wget_ip_lookup_on_any_family_passes_no_empty_flag() {
	make_wget_stub wget "$GNU_WGET_LINE" ''
	with_stubs http_get "https://icanhazip.com" >/dev/null
	assert_same "$(printf '%s\n' -q -O - --timeout=10 --tries=1 -i -)" "$(stub_args wget)"
}

# --- what no client may put on its command line ---

function test_tokens_in_a_url_stay_off_the_command_line() {
	# The Telegram bot token and the Discord webhook token are in the URL
	local url="https://api.telegram.org/bot123:SECRET-1/sendMessage"
	make_stdin_stub curl ''
	with_stubs http_request "POST" "$url" "chat_id=1&text=hi" >/dev/null
	assert_not_contains "SECRET-1" "$(stub_args curl)"
	assert_contains "$url" "$(stub_stdin curl)"
	rm -f "$STUBS/curl"
	make_wget_stub wget "$GNU_WGET_LINE" ''
	with_stubs http_request "POST" "$url" "chat_id=1&text=hi" >/dev/null
	assert_not_contains "SECRET-1" "$(stub_args wget)"
	assert_contains "$url" "$(stub_stdin wget)"
}

function test_a_line_break_in_a_header_or_url_is_refused() {
	# Each travels on a line of its own, so a break would add another line
	make_stdin_stub curl ''
	local err status
	err=$(with_stubs http_request "GET" "https://api.example.com/records" "" \
		$'X-A: 1\nX-B: 2' 2>&1 >/dev/null)
	status=$?
	assert_general_error "" "" "$status"
	assert_contains "line break" "$err"
	with_stubs http_request "GET" $'https://api.example.com/\rrecords' "" 2>/dev/null
	status=$?
	assert_general_error "" "" "$status"
	assert_file_not_exists "$STUBS/curl.args"
}

# --- which client is picked ---

function test_gnu_wget2_is_used() {
	make_wget_stub wget "$WGET2_LINE" 'printf "%s" "{\"success\":true}"'
	local out
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "")
	assert_same '{"success":true}' "$out"
	assert_contains "--content-on-error" "$(stub_args wget)"
}

function test_gnu_wget2_is_used_under_its_own_name() {
	# Debian, Ubuntu and Arch install Wget2 as wget2 only; Fedora's
	# wget2-wget installs it as wget
	make_wget_stub wget2 "$WGET2_LINE" 'printf "%s" "{\"success\":true}"'
	local client out
	client=$(with_stubs declare -p HTTP_CLIENT)
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "")
	assert_same 'declare -- HTTP_CLIENT="wget2"' "$client"
	assert_same '{"success":true}' "$out"
	assert_contains "--content-on-error" "$(stub_args wget2)"
}

function test_gnu_wget2_is_used_beside_busybox_wget() {
	make_stub wget 'echo "BusyBox v1.37.0 (2026-01-10 15:38:28 UTC) multi-call binary." >&2
exit 1'
	make_wget_stub wget2 "$WGET2_LINE" 'printf "%s" "{\"success\":true}"'
	local out
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "")
	assert_same '{"success":true}' "$out"
	assert_same "--version" "$(stub_args wget)"
}

function test_busybox_wget_is_never_used() {
	make_stub wget 'echo "wget: unrecognized option '"'"'--version'"'"'" >&2
echo "BusyBox v1.37.0 (2026-01-10 15:38:28 UTC) multi-call binary." >&2
exit 1'
	local status problem
	with_stubs http_request "POST" "https://api.example.com/batch" '{"puts":[]}' 2>/dev/null
	status=$?
	assert_general_error "" "" "$status"
	# Asked for its version, never for a request
	assert_same "--version" "$(stub_args wget)"
	problem=$(with_stubs http_client_problem)
	assert_contains "BusyBox wget" "$problem"
	assert_contains "Install curl" "$problem"
}

# shellcheck disable=SC2016 # stub code
function test_gnu_wget_older_than_1_15_is_not_used() {
	# --method and --body-data came with GNU Wget 1.15
	make_stub wget '[[ "$1" == "--version" ]] && { echo "GNU Wget 1.14 built on linux-gnu."; exit 0; }
printf "%s" "{\"success\":true}"'
	local client problem
	client=$(with_stubs declare -p HTTP_CLIENT)
	problem=$(with_stubs http_client_problem)
	assert_same 'declare -- HTTP_CLIENT=""' "$client"
	assert_contains "GNU Wget 1.14, older than 1.15" "$problem"
}

function test_curl_exe_comes_before_wget() {
	# Windows' own curl, reachable from WSL, takes the same arguments as curl
	make_stdin_stub curl.exe 'printf "%s" "{\"success\":true}"'
	make_stub wget "$GNU_WGET_VERSION"
	local out
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer tok")
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -s --connect-timeout 10 --max-time 30 -X GET -K -)" \
		"$(stub_args curl.exe)"
	assert_same 'url = "https://api.example.com/records"
header = "Authorization: Bearer tok"
|' "$(stub_stdin curl.exe)"
}

function test_pwsh_gets_the_request_on_stdin() {
	make_stdin_stub pwsh 'printf "%s" "{\"success\":true}"'
	local out status
	out=$(with_stubs http_request "POST" "https://api.example.com/batch" '{"name":"it'"'"'s"}' \
		"Authorization: Bearer tok" "Content-Type: application/json")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":true}' "$out"
	# Neither the token nor the body is on the command line
	assert_same "$(printf '%s\n' -NoProfile -NonInteractive -Command "$_HTTP_PS_SCRIPT")" "$(stub_args pwsh)"
	assert_same 'POST
https://api.example.com/batch
30
Authorization: Bearer tok
Content-Type: application/json

{"name":"it'"'"'s"}|' "$(stub_stdin pwsh)"
}

function test_pwsh_passes_an_error_body_through() {
	# The PowerShell side exits 0 for any response and writes its body
	make_stdin_stub pwsh 'printf "%s" "{\"success\":false}"'
	local out status
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer bad")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":false}' "$out"
}

function test_pwsh_network_failure_returns_non_zero() {
	make_stdin_stub pwsh 'exit 1'
	local out status
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "")
	status=$?
	assert_same 1 "$status"
	assert_empty "$out"
	assert_same "GET
https://api.example.com/records
30

|" "$(stub_stdin pwsh)"
}

function test_powershell_exe_is_used_without_pwsh() {
	make_stdin_stub powershell.exe 'printf "%s" "{\"success\":true}"'
	local out
	out=$(with_stubs http_request "GET" "https://api.example.com/records" "")
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -NoProfile -NonInteractive -Command "$_HTTP_PS_SCRIPT")" \
		"$(stub_args powershell.exe)"
}

function test_pwsh_ip_lookup_asks_the_host_of_that_family() {
	# PowerShell cannot pick IPv4 or IPv6, so the lookup goes to a host
	# name that only has records of the wanted family
	make_stdin_stub pwsh 'printf "%s\n" "192.0.2.10"'
	local out
	out=$(with_stubs http_get "https://icanhazip.com" 4)
	assert_same "192.0.2.10" "$out"
	assert_same "GET
https://ipv4.icanhazip.com
10

|" "$(stub_stdin pwsh)"
	with_stubs http_get "https://icanhazip.com" 6 >/dev/null
	assert_same "GET
https://ipv6.icanhazip.com
10

|" "$(stub_stdin pwsh)"
}

function test_pwsh_skips_a_service_that_answers_on_both_families() {
	make_stdin_stub pwsh 'printf "%s\n" "2001:db8::10"'
	local out status
	out=$(
		PATH="$STUBS"
		http_detect_client
		printf '%s|' "$HTTP_CLIENT"
		http_get "https://ifconfig.co" 4
	)
	status=$?
	assert_same "pwsh|" "$out"
	assert_general_error "" "" "$status"
	assert_file_not_exists "$STUBS/pwsh.args"
}

# --- the PowerShell side itself, when pwsh is installed ---
#
# These run the real script in the real pwsh, with Invoke-WebRequest
# replaced by a function that records how it was called and answers as
# the test asks (a PowerShell function wins over the cmdlet of the same
# name). GitHub's ubuntu runners ship pwsh; elsewhere they are skipped.

# shellcheck disable=SC2016 # PowerShell code
PS_FAKE='function Invoke-WebRequest {
	param($Method, $Uri, $TimeoutSec, $Headers, $ContentType, $Body, [switch]$UseBasicParsing, [switch]$SkipHttpErrorCheck)
	$seen = [ordered]@{ Method = [string]$Method; Uri = [string]$Uri; TimeoutSec = $TimeoutSec; Headers = $Headers; ContentType = $ContentType; Body = $(if ($null -ne $Body) { [Convert]::ToBase64String($Body) } else { $null }); UseBasicParsing = [bool]$UseBasicParsing; SkipHttpErrorCheck = [bool]$SkipHttpErrorCheck }
	$seen | ConvertTo-Json -Compress | Set-Content -LiteralPath $env:PS_FAKE_SEEN
	if ($env:PS_FAKE_MODE -eq "unreachable") { throw [System.Net.Http.HttpRequestException]::new("No such host is known.") }
	if ($env:PS_FAKE_MODE -eq "windows-powershell-error") {
		$record = [System.Management.Automation.ErrorRecord]::new([FakeResponseError]::new(), "WebCmdletWebResponseException", "InvalidOperation", $null)
		$record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($env:PS_FAKE_BODY)
		throw $record
	}
	[pscustomobject]@{ RawContentStream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($env:PS_FAKE_BODY)) }
}
class FakeResponseError : System.Exception { [object]$Response = "403 Forbidden" }'

# Installs a pwsh stub that runs the real pwsh with the fake prepended
# shellcheck disable=SC2016 # stub code
function use_real_pwsh() {
	local real
	real=$(command -v pwsh) || return 1
	printf '%s' "$PS_FAKE" >"$STUBS/fake.ps1"
	make_stub pwsh 'fake=$(<'"$(printf %q "$STUBS/fake.ps1")"')
exec '"$(printf %q "$real")"' -NoProfile -NonInteractive -Command "$fake; $4"'
}

function test_powershell_script_sends_the_request_as_given() {
	use_real_pwsh || {
		bashunit::skip "pwsh is not installed"
		return
	}
	local out status
	out=$(PS_FAKE_SEEN="$STUBS/seen.json" PS_FAKE_MODE=ok PS_FAKE_BODY='{"success":true,"name":"café"}' \
		with_stubs http_request "POST" "https://api.example.com/batch" '{"content":"it'"'"'s café"}' \
		"Authorization: Bearer tok" "Content-Type: application/json")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":true,"name":"café"}' "$out"
	# The body arrives byte for byte (UTF-8, quote included); Content-Type
	# goes where Invoke-WebRequest wants it; an error status does not throw.
	assert_same '{"Method":"POST","Uri":"https://api.example.com/batch","TimeoutSec":30,"Headers":{"Authorization":"Bearer tok"},"ContentType":"application/json","Body":"'"$(printf '%s' '{"content":"it'"'"'s café"}' | base64 -w0)"'","UseBasicParsing":true,"SkipHttpErrorCheck":true}' \
		"$(cat "$STUBS/seen.json")"
}

function test_powershell_script_returns_the_error_body_windows_powershell_throws() {
	use_real_pwsh || {
		bashunit::skip "pwsh is not installed"
		return
	}
	local out status
	out=$(PS_FAKE_SEEN="$STUBS/seen.json" PS_FAKE_MODE=windows-powershell-error \
		PS_FAKE_BODY='{"success":false,"errors":[{"code":10000}]}' \
		with_stubs http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer bad")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":false,"errors":[{"code":10000}]}' "$out"
}

function test_powershell_script_exits_1_when_no_response_arrives() {
	use_real_pwsh || {
		bashunit::skip "pwsh is not installed"
		return
	}
	local out status
	out=$(PS_FAKE_SEEN="$STUBS/seen.json" PS_FAKE_MODE=unreachable \
		with_stubs http_get "https://icanhazip.com" 4 2>&1)
	status=$?
	assert_same 1 "$status"
	assert_empty "$out"
	assert_contains '"Uri":"https://ipv4.icanhazip.com","TimeoutSec":10,"Headers":{},"ContentType":null,"Body":null' \
		"$(cat "$STUBS/seen.json")"
}
