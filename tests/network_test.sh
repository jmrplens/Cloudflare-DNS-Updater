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
}

function tear_down() {
	rm -rf "$STUBS"
}

# --- http_request (curl) ---

function test_http_request_get_builds_curl_command() {
	bashunit::spy curl
	http_request "GET" "https://api.example.com/records" "" \
		"Authorization: Bearer tok" >/dev/null
	assert_have_been_called_with curl \
		-s --connect-timeout 10 --max-time 30 -X GET \
		-H "Authorization: Bearer tok" "https://api.example.com/records"
}

function test_http_request_post_includes_body() {
	bashunit::spy curl
	http_request "POST" "https://api.example.com/batch" '{"puts":[]}' \
		"Authorization: Bearer tok" "Content-Type: application/json" >/dev/null
	assert_have_been_called_with curl \
		-s --connect-timeout 10 --max-time 30 -X POST \
		-H "Authorization: Bearer tok" -H "Content-Type: application/json" \
		-d '{"puts":[]}' "https://api.example.com/batch"
}

function test_http_request_fails_without_client() {
	HTTP_CLIENT=""
	assert_general_error "$(http_request "GET" "https://api.example.com" "" 2>/dev/null)"
}

# --- http_get protocol flags ---

function test_http_get_uses_ipv4_flag() {
	bashunit::spy curl
	http_get "https://icanhazip.com" 4 >/dev/null
	assert_have_been_called_with curl -s -4 --max-time 10 "https://icanhazip.com"
}

function test_http_get_uses_ipv6_flag() {
	bashunit::spy curl
	http_get "https://icanhazip.com" 6 >/dev/null
	assert_have_been_called_with curl -s -6 --max-time 10 "https://icanhazip.com"
}

function test_http_get_any_protocol_passes_no_empty_flag() {
	bashunit::spy curl
	http_get "https://icanhazip.com" >/dev/null
	# No stray "" argument between -s and --max-time
	assert_have_been_called_with curl -s --max-time 10 "https://icanhazip.com"
}

# --- wget fallback branch ---

function test_http_request_wget_builds_command() {
	HTTP_CLIENT="wget"
	bashunit::spy wget
	http_request "POST" "https://api.example.com/batch" '{"puts":[]}' \
		"Content-Type: application/json" >/dev/null
	assert_have_been_called_with wget \
		-q -O - --content-on-error --method=POST "--header=Content-Type: application/json" \
		'--body-data={"puts":[]}' --dns-timeout=10 --connect-timeout=10 --read-timeout=30 \
		--tries=1 "https://api.example.com/batch"
}

function test_http_get_wget_uses_ipv4_flag() {
	HTTP_CLIENT="wget"
	bashunit::spy wget
	http_get "https://icanhazip.com" 4 >/dev/null
	assert_have_been_called_with wget \
		-q -O - -4 --timeout=10 --tries=1 "https://icanhazip.com"
}

function test_http_get_wget_omits_empty_flag() {
	HTTP_CLIENT="wget"
	bashunit::spy wget
	http_get "https://icanhazip.com" >/dev/null
	assert_have_been_called_with wget \
		-q -O - --timeout=10 --tries=1 "https://icanhazip.com"
}

# --- the other clients, with curl hidden ---
#
# Each stub client is an executable in a directory of its own, and the code
# under test runs with that directory as its whole PATH: there is no curl
# to find. A stub writes its arguments, one per line, to NAME.args beside
# itself, and answers with the script it was given.

function make_stub() {
	local name="$1" script="$2"
	{
		printf '#!%s\n' "$BASH"
		printf 'printf "%%s\\n" "$@" >%q\n' "$STUBS/$name.args"
		printf '%s\n' "$script"
	} >"$STUBS/$name"
	chmod +x "$STUBS/$name"
}

# A PowerShell stub also keeps its stdin, where the request travels
function make_ps_stub() {
	local name="$1" script="$2"
	make_stub "$name" "IFS= read -r -d '' request; printf '%s' \"\$request\" >$(printf %q "$STUBS/$name.stdin")
$script"
}

# Runs a command in a subshell whose PATH holds the stubs and nothing else,
# after picking the client again from that PATH.
function without_curl() {
	(
		PATH="$STUBS"
		http_detect_client
		"$@"
	)
}

function stub_args() {
	cat "$STUBS/$1.args"
}

# What a PowerShell stub read, trailing newlines included (a command
# substitution would drop them), closed by a | so they show
function stub_stdin() {
	local request
	IFS= read -r -d '' request <"$STUBS/$1.stdin"
	printf '%s|' "$request"
}

# Stub scripts are literal code for the stub, not for this shell
# shellcheck disable=SC2016
GNU_WGET_VERSION='[[ "$1" == "--version" ]] && { echo "GNU Wget 1.21.4 built on linux-gnu."; exit 0; }'

# shellcheck disable=SC2016 # stub code
function test_wget_sends_an_api_request_without_curl() {
	make_stub wget "$GNU_WGET_VERSION"'
printf "%s" "{\"success\":true}"'
	local out status
	out=$(without_curl http_request "POST" "https://api.example.com/batch" '{"puts":[]}' \
		"Authorization: Bearer tok" "Content-Type: application/json")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -q -O - --content-on-error --method=POST \
		"--header=Authorization: Bearer tok" "--header=Content-Type: application/json" \
		'--body-data={"puts":[]}' --dns-timeout=10 --connect-timeout=10 \
		--read-timeout=30 --tries=1 "https://api.example.com/batch")" "$(stub_args wget)"
}

# shellcheck disable=SC2016 # stub code
function test_wget_returns_the_body_of_an_http_error() {
	# GNU Wget keeps an error body only with --content-on-error, and exits 8
	# ("server issued an error response"). curl -s exits 0 with the body.
	make_stub wget "$GNU_WGET_VERSION"'
for arg in "$@"; do
	[[ "$arg" == "--content-on-error" ]] && printf "%s" "{\"success\":false,\"errors\":[{\"code\":10000}]}"
done
exit 8'
	local out status
	out=$(without_curl http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer bad")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":false,"errors":[{"code":10000}]}' "$out"
}

# shellcheck disable=SC2016 # stub code
function test_wget_network_failure_fails_after_one_attempt() {
	# wget retries up to 20 times by default; curl never retries
	make_stub wget "$GNU_WGET_VERSION"'
exit 4'
	local out status
	out=$(without_curl http_request "POST" "https://api.example.com/batch" '{"puts":[]}')
	status=$?
	assert_same 4 "$status"
	assert_empty "$out"
	assert_contains "--tries=1" "$(stub_args wget)"
}

# shellcheck disable=SC2016 # stub code
function test_gnu_wget2_is_used() {
	make_stub wget '[[ "$1" == "--version" ]] && { echo "GNU Wget2 2.2.0 - multithreaded metalink/file/website downloader"; exit 0; }
printf "%s" "{\"success\":true}"'
	local out
	out=$(without_curl http_request "GET" "https://api.example.com/records" "")
	assert_same '{"success":true}' "$out"
	assert_contains "--content-on-error" "$(stub_args wget)"
}

function test_busybox_wget_is_never_used() {
	make_stub wget 'echo "wget: unrecognized option '"'"'--version'"'"'" >&2
echo "BusyBox v1.37.0 (2026-01-10 15:38:28 UTC) multi-call binary." >&2
exit 1'
	local status problem
	without_curl http_request "POST" "https://api.example.com/batch" '{"puts":[]}' 2>/dev/null
	status=$?
	assert_general_error "" "" "$status"
	# Asked for its version, never for a request
	assert_same "--version" "$(stub_args wget)"
	problem=$(without_curl http_client_problem)
	assert_contains "BusyBox wget" "$problem"
	assert_contains "Install curl" "$problem"
}

# shellcheck disable=SC2016 # stub code
function test_gnu_wget_older_than_1_15_is_not_used() {
	# --method and --body-data came with GNU Wget 1.15
	make_stub wget '[[ "$1" == "--version" ]] && { echo "GNU Wget 1.14 built on linux-gnu."; exit 0; }
printf "%s" "{\"success\":true}"'
	local client problem
	client=$(without_curl declare -p HTTP_CLIENT)
	problem=$(without_curl http_client_problem)
	assert_same 'declare -- HTTP_CLIENT=""' "$client"
	assert_contains "GNU Wget 1.14, older than 1.15" "$problem"
}

function test_curl_exe_comes_before_wget() {
	# Windows' own curl, reachable from WSL, takes the same arguments as curl
	make_stub curl.exe 'printf "%s" "{\"success\":true}"'
	make_stub wget "$GNU_WGET_VERSION"
	local out
	out=$(without_curl http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer tok")
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -s --connect-timeout 10 --max-time 30 -X GET \
		-H "Authorization: Bearer tok" "https://api.example.com/records")" "$(stub_args curl.exe)"
}

function test_pwsh_gets_the_request_on_stdin() {
	make_ps_stub pwsh 'printf "%s" "{\"success\":true}"'
	local out status
	out=$(without_curl http_request "POST" "https://api.example.com/batch" '{"name":"it'"'"'s"}' \
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
	make_ps_stub pwsh 'printf "%s" "{\"success\":false}"'
	local out status
	out=$(without_curl http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer bad")
	status=$?
	assert_same 0 "$status"
	assert_same '{"success":false}' "$out"
}

function test_pwsh_network_failure_returns_non_zero() {
	make_ps_stub pwsh 'exit 1'
	local out status
	out=$(without_curl http_request "GET" "https://api.example.com/records" "")
	status=$?
	assert_same 1 "$status"
	assert_empty "$out"
	assert_same "GET
https://api.example.com/records
30

|" "$(stub_stdin pwsh)"
}

function test_powershell_exe_is_used_without_pwsh() {
	make_ps_stub powershell.exe 'printf "%s" "{\"success\":true}"'
	local out
	out=$(without_curl http_request "GET" "https://api.example.com/records" "")
	assert_same '{"success":true}' "$out"
	assert_same "$(printf '%s\n' -NoProfile -NonInteractive -Command "$_HTTP_PS_SCRIPT")" \
		"$(stub_args powershell.exe)"
}

function test_pwsh_ip_lookup_asks_the_host_of_that_family() {
	# PowerShell cannot pick IPv4 or IPv6, so the lookup goes to a host
	# name that only has records of the wanted family
	make_ps_stub pwsh 'printf "%s\n" "192.0.2.10"'
	local out
	out=$(without_curl http_get "https://icanhazip.com" 4)
	assert_same "192.0.2.10" "$out"
	assert_same "GET
https://ipv4.icanhazip.com
10

|" "$(stub_stdin pwsh)"
	without_curl http_get "https://icanhazip.com" 6 >/dev/null
	assert_same "GET
https://ipv6.icanhazip.com
10

|" "$(stub_stdin pwsh)"
}

function test_pwsh_skips_a_service_that_answers_on_both_families() {
	make_ps_stub pwsh 'printf "%s\n" "2001:db8::10"'
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
		without_curl http_request "POST" "https://api.example.com/batch" '{"content":"it'"'"'s café"}' \
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
		without_curl http_request "GET" "https://api.example.com/records" "" "Authorization: Bearer bad")
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
		without_curl http_get "https://icanhazip.com" 4 2>&1)
	status=$?
	assert_same 1 "$status"
	assert_empty "$out"
	assert_contains '"Uri":"https://ipv4.icanhazip.com","TimeoutSec":10,"Headers":{},"ContentType":null,"Body":null' \
		"$(cat "$STUBS/seen.json")"
}
