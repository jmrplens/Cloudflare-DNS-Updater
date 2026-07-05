#!/usr/bin/env bash
# Unit tests for src/network.sh (HTTP client wrapper)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/network.sh"
	HTTP_CLIENT="curl"
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
		-q -O - --method=POST "--header=Content-Type: application/json" \
		'--body-data={"puts":[]}' --timeout=10 "https://api.example.com/batch"
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
