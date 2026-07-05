#!/usr/bin/env bash
# Unit and integration tests for src/main.sh

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."
FIXTURES="$TESTS_DIR/fixtures"

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# Sourcing main.sh loads every module; the run guard keeps main() from executing
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/main.sh"
	CF_ZONE_ID="test-zone"
	CF_API_TOKEN="test-token"

	# Fresh queue state for every test
	updates_json_list=""
	update_count=0
	verification_list=()
	parsed_records="rec-a|home.example.com|A|192.0.2.1|true
rec-aaaa|home.example.com|AAAA|2001:db8::1|true
rec-direct|direct.example.com|A|192.0.2.1|false"
}

# --- queue_if_changed ---

function test_queue_skips_without_target_ip() {
	queue_if_changed "A" "home.example.com" "" "true" "auto"
	assert_same "0" "$update_count"
	assert_empty "$updates_json_list"
}

function test_queue_skips_unknown_record() {
	queue_if_changed "A" "missing.example.com" "192.0.2.9" "true" "auto" 2>/dev/null
	assert_same "0" "$update_count"
}

function test_queue_skips_when_record_matches() {
	queue_if_changed "A" "home.example.com" "192.0.2.1" "true" "auto"
	assert_same "0" "$update_count"
}

function test_queue_adds_update_when_ip_changes() {
	queue_if_changed "A" "home.example.com" "192.0.2.99" "true" "auto"
	assert_same "1" "$update_count"
	assert_contains '"id":"rec-a"' "$updates_json_list"
	assert_contains '"content":"192.0.2.99"' "$updates_json_list"
}

function test_queue_adds_update_when_proxied_changes() {
	queue_if_changed "A" "home.example.com" "192.0.2.1" "false" "auto"
	assert_same "1" "$update_count"
	assert_contains '"proxied":false' "$updates_json_list"
}

function test_queue_force_updates_matching_record() {
	FORCE="true"
	queue_if_changed "A" "home.example.com" "192.0.2.1" "true" "auto"
	assert_same "1" "$update_count"
}

function test_queue_joins_multiple_updates_with_commas() {
	queue_if_changed "A" "home.example.com" "192.0.2.99" "true" "auto"
	queue_if_changed "AAAA" "home.example.com" "2001:db8::99" "true" "auto"
	assert_same "2" "$update_count"
	assert_matches '\},\{' "$updates_json_list"
}

function test_queue_tracks_unproxied_records_for_verification() {
	queue_if_changed "A" "direct.example.com" "192.0.2.99" "false" "auto"
	assert_same "1" "${#verification_list[@]}"
	assert_same "direct.example.com|4|192.0.2.99" "${verification_list[0]}"
}

function test_queue_skips_verification_for_proxied_records() {
	queue_if_changed "A" "home.example.com" "192.0.2.99" "true" "auto"
	assert_same "0" "${#verification_list[@]}"
}

# --- main() integration (all I/O mocked) ---

UP_TO_DATE_JSON='{"result":[{"id":"rec-a","name":"home.example.com","type":"A","content":"192.0.2.1","proxied":true,"ttl":1},{"id":"rec-aaaa","name":"home.example.com","type":"AAAA","content":"2001:db8::1","proxied":true,"ttl":1}],"result_info":{"page":1,"per_page":5000,"count":2,"total_count":2,"total_pages":1},"success":true,"errors":[]}'

function fake_api_all_current() {
	echo "$UP_TO_DATE_JSON"
}

function fake_api_needs_update() {
	local method="$1"
	if [[ "$method" == "GET" ]]; then
		echo "$UP_TO_DATE_JSON"
	else
		echo '{"result":{"puts":[{"id":"rec-a","name":"home.example.com","content":"192.0.2.99"}]},"success":true,"errors":[]}'
	fi
}

function fake_public_v4_current() { echo "192.0.2.1"; }
function fake_public_v4_changed() { echo "192.0.2.99"; }
function fake_public_v6_current() { echo "2001:db8::1"; }

function test_main_reports_no_changes_when_records_match() {
	SILENT="false"
	bashunit::mock get_public_ipv4 fake_public_v4_current
	bashunit::mock get_public_ipv6 fake_public_v6_current
	bashunit::mock http_request fake_api_all_current

	local out
	out=$(main "$FIXTURES/main_config.yaml" 2>&1)
	assert_contains "No changes needed" "$out"
	assert_contains "Loaded 1 domains" "$out"
}

function test_main_pushes_batch_update_when_ip_changed() {
	SILENT="false"
	bashunit::mock get_public_ipv4 fake_public_v4_changed
	bashunit::mock get_public_ipv6 fake_public_v6_current
	bashunit::spy http_request fake_api_needs_update

	local out
	out=$(main "$FIXTURES/main_config.yaml" 2>&1)
	assert_contains "Change detected for home.example.com (A): 192.0.2.1 -> 192.0.2.99" "$out"
	assert_contains "Successfully updated 1 records!" "$out"
}

function test_main_help_flag_prints_usage() {
	assert_contains "Usage:" "$(main --help)"
}

# --- Version consistency ---

function test_version_constant_matches_version_file() {
	# The release workflow reads the VERSION file; the runtime constant in
	# main.sh must never drift from it.
	assert_same "$(tr -d '[:space:]' <"$PROJECT_ROOT/VERSION")" "$VERSION"
	assert_matches '^[0-9]+\.[0-9]+\.[0-9]+$' "$VERSION"
}
