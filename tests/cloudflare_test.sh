#!/usr/bin/env bash
# Unit tests for src/cloudflare.sh

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."
FIXTURES="$TESTS_DIR/fixtures"

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/logger.sh"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/cloudflare.sh"
	CF_ZONE_ID="test-zone-123"
	CF_API_TOKEN="test-token-abc"
}

# --- cf_needs_update ---

function test_needs_update_when_ip_differs() {
	assert_successful_code "$(cf_needs_update "192.0.2.1" "192.0.2.2" "true" "true")"
}

function test_needs_update_when_proxied_differs() {
	assert_successful_code "$(cf_needs_update "192.0.2.1" "192.0.2.1" "true" "false")"
}

function test_no_update_when_everything_matches() {
	assert_general_error "$(cf_needs_update "192.0.2.1" "192.0.2.1" "true" "true")"
}

function test_needs_update_when_both_differ() {
	assert_successful_code "$(cf_needs_update "192.0.2.1" "192.0.2.2" "false" "true")"
}

# --- cf_build_put_object ---

function test_build_put_object_with_auto_ttl() {
	local obj
	obj=$(cf_build_put_object "rec-1" "A" "example.com" "192.0.2.1" "true" "auto")
	assert_same '{"id":"rec-1","type":"A","name":"example.com","content":"192.0.2.1","ttl":1,"proxied":true}' "$obj"
}

function test_build_put_object_with_numeric_ttl() {
	local obj
	obj=$(cf_build_put_object "rec-2" "AAAA" "v6.example.com" "2001:db8::1" "false" "300")
	assert_same '{"id":"rec-2","type":"AAAA","name":"v6.example.com","content":"2001:db8::1","ttl":300,"proxied":false}' "$obj"
}

# --- cf_get_record_from_cache ---

CACHE_LINES="rec-a-root|example.com|A|192.0.2.10|true
rec-aaaa-root|example.com|AAAA|2001:db8::10|true
rec-a-wildcard|*.example.com|A|192.0.2.10|false"

function test_cache_lookup_finds_a_record() {
	assert_same "rec-a-root|example.com|A|192.0.2.10|true" \
		"$(cf_get_record_from_cache "$CACHE_LINES" "example.com" "A")"
}

function test_cache_lookup_finds_aaaa_record() {
	assert_same "rec-aaaa-root|example.com|AAAA|2001:db8::10|true" \
		"$(cf_get_record_from_cache "$CACHE_LINES" "example.com" "AAAA")"
}

function test_cache_lookup_finds_wildcard_domain() {
	assert_same "rec-a-wildcard|*.example.com|A|192.0.2.10|false" \
		"$(cf_get_record_from_cache "$CACHE_LINES" "*.example.com" "A")"
}

function test_cache_lookup_miss_returns_empty() {
	assert_empty "$(cf_get_record_from_cache "$CACHE_LINES" "missing.example.com" "A")"
}

# --- cf_parse_records_to_lines (jq path) ---

function test_parse_records_jq_extracts_a_record() {
	local parsed
	parsed=$(cf_parse_records_to_lines "$(cat "$FIXTURES/dns_records.json")")
	assert_contains "rec-a-root|example.com|A|192.0.2.10|true" "$parsed"
}

function test_parse_records_jq_extracts_aaaa_record() {
	local parsed
	parsed=$(cf_parse_records_to_lines "$(cat "$FIXTURES/dns_records.json")")
	assert_contains "rec-aaaa-root|example.com|AAAA|2001:db8::10|true" "$parsed"
}

function test_parse_records_jq_extracts_wildcard_record() {
	local parsed
	parsed=$(cf_parse_records_to_lines "$(cat "$FIXTURES/dns_records.json")")
	assert_contains "rec-a-wildcard|*.example.com|A|192.0.2.10|false" "$parsed"
}

function test_parse_records_jq_filters_out_other_types() {
	local parsed
	parsed=$(cf_parse_records_to_lines "$(cat "$FIXTURES/dns_records.json")")
	assert_not_contains "rec-txt-root" "$parsed"
}

# --- cf_parse_records_to_lines (sed fallback path, no jq in PATH) ---

function test_parse_records_sed_fallback_extracts_records() {
	local shim parsed
	shim=$(mktemp -d)
	local tool
	for tool in sed grep cut tr date head cat mkdir dirname touch wc; do
		ln -s "$(command -v "$tool")" "$shim/$tool"
	done

	# shellcheck disable=SC2016 # single-quoted on purpose; values injected via quote-breaks
	parsed=$(PATH="$shim" "$BASH" -c '
		export DEBUG=false SILENT=true
		source "'"$PROJECT_ROOT"'/src/logger.sh"
		source "'"$PROJECT_ROOT"'/src/cloudflare.sh"
		cf_parse_records_to_lines "$(cat "'"$FIXTURES"'/dns_records.json")"
	' 2>/dev/null)
	rm -rf "$shim"

	assert_contains "rec-a-root|example.com|A|192.0.2.10|true" "$parsed"
	assert_contains "rec-aaaa-root|example.com|AAAA|2001:db8::10|true" "$parsed"
	assert_contains "rec-a-wildcard|*.example.com|A|192.0.2.10|false" "$parsed"
	assert_not_contains "rec-txt-root" "$parsed"
}

# --- cf_get_all_records ---

function fake_http_request_success() {
	cat "$FIXTURES/dns_records.json"
}

function fake_http_request_failure() {
	echo '{"result":null,"success":false,"errors":[{"code":10000,"message":"Authentication error"}]}'
}

function test_get_all_records_returns_response_on_success() {
	bashunit::mock http_request fake_http_request_success
	local response
	response=$(cf_get_all_records "A,AAAA")
	assert_successful_code "$response"
	assert_contains '"success":true' "$response"
}

function test_get_all_records_fails_on_api_error() {
	bashunit::mock http_request fake_http_request_failure
	assert_general_error "$(cf_get_all_records "A,AAAA" 2>/dev/null)"
}

function fake_http_request_paginated() {
	local url="$2"
	if [[ "$url" == *"page=1"* ]]; then
		echo '{"result":[{"id":"page1-rec","name":"p1.example.com","type":"A","content":"192.0.2.1","proxied":true,"ttl":1}],"result_info":{"page":1,"per_page":5000,"count":1,"total_count":2,"total_pages":2},"success":true,"errors":[]}'
	else
		echo '{"result":[{"id":"page2-rec","name":"p2.example.com","type":"AAAA","content":"2001:db8::2","proxied":false,"ttl":1}],"result_info":{"page":2,"per_page":5000,"count":1,"total_count":2,"total_pages":2},"success":true,"errors":[]}'
	fi
}

function test_get_all_records_follows_pagination() {
	bashunit::mock http_request fake_http_request_paginated
	local response parsed
	response=$(cf_get_all_records "A,AAAA")
	parsed=$(cf_parse_records_to_lines "$response")
	assert_contains "page1-rec|p1.example.com|A|192.0.2.1|true" "$parsed"
	assert_contains "page2-rec|p2.example.com|AAAA|2001:db8::2|false" "$parsed"
}

# --- cf_batch_update ---

function fake_http_request_batch_ok() {
	echo '{"result":{"puts":[{"id":"rec-a-root","name":"example.com","content":"192.0.2.99"}]},"success":true,"errors":[]}'
}

function test_batch_update_succeeds_and_echoes_response() {
	bashunit::mock http_request fake_http_request_batch_ok
	local response
	response=$(cf_batch_update '{"puts":[]}')
	assert_successful_code "$response"
	assert_contains '"content":"192.0.2.99"' "$response"
}

function test_batch_update_fails_on_api_error() {
	bashunit::mock http_request fake_http_request_failure
	assert_general_error "$(cf_batch_update '{"puts":[]}' 2>/dev/null)"
}
