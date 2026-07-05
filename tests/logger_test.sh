#!/usr/bin/env bash
# Unit tests for src/logger.sh

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/logger.sh"
}

# --- Boolean helpers ---

function test_is_debug_reads_env() {
	DEBUG="true"
	assert_successful_code "$(is_debug)"
	DEBUG="false"
	assert_general_error "$(is_debug)"
}

function test_is_silent_reads_env() {
	SILENT="true"
	assert_successful_code "$(is_silent)"
	SILENT="false"
	assert_general_error "$(is_silent)"
}

function test_is_force_reads_env() {
	FORCE="true"
	assert_successful_code "$(is_force)"
	FORCE="false"
	assert_general_error "$(is_force)"
}

# --- sanitize_log ---

function test_sanitize_redacts_api_token() {
	CF_API_TOKEN="super-secret-token"
	CF_ZONE_ID=""
	assert_same "Bearer ********" "$(sanitize_log "Bearer super-secret-token")"
}

function test_sanitize_redacts_zone_id() {
	CF_API_TOKEN=""
	CF_ZONE_ID="zone-id-42"
	assert_same "zones/********/dns_records" "$(sanitize_log "zones/zone-id-42/dns_records")"
}

function test_sanitize_redacts_multiple_occurrences() {
	CF_API_TOKEN="tok123"
	CF_ZONE_ID=""
	assert_same "******** and ********" "$(sanitize_log "tok123 and tok123")"
}

function test_sanitize_keeps_clean_messages_intact() {
	CF_API_TOKEN="tok123"
	CF_ZONE_ID="zone456"
	assert_same "nothing sensitive here" "$(sanitize_log "nothing sensitive here")"
}

# --- File logging ---

function test_logger_init_creates_log_file() {
	local log_dir
	log_dir=$(mktemp -d)
	logger_init "$log_dir/nested/updater.log"
	assert_successful_code "$(test -f "$log_dir/nested/updater.log")"
	rm -rf "$log_dir"
}

function test_log_info_writes_to_file() {
	local log_dir
	log_dir=$(mktemp -d)
	logger_init "$log_dir/updater.log"
	log_info "hello from test" 2>/dev/null
	assert_contains "[INFO] hello from test" "$(cat "$log_dir/updater.log")"
	rm -rf "$log_dir"
}

function test_log_error_writes_to_file() {
	local log_dir
	log_dir=$(mktemp -d)
	logger_init "$log_dir/updater.log"
	log_error "something failed" 2>/dev/null
	assert_contains "[ERROR] something failed" "$(cat "$log_dir/updater.log")"
	rm -rf "$log_dir"
}

function test_log_debug_silent_when_debug_off() {
	local log_dir
	log_dir=$(mktemp -d)
	logger_init "$log_dir/updater.log"
	DEBUG="false"
	log_debug "invisible" 2>/dev/null
	assert_not_contains "invisible" "$(cat "$log_dir/updater.log")"
	rm -rf "$log_dir"
}

function test_log_debug_redacted_sanitizes_output() {
	local log_dir
	log_dir=$(mktemp -d)
	logger_init "$log_dir/updater.log"
	DEBUG="true"
	CF_API_TOKEN="tok-abc"
	CF_ZONE_ID=""
	log_debug_redacted "calling with tok-abc" 2>/dev/null
	assert_contains "calling with ********" "$(cat "$log_dir/updater.log")"
	rm -rf "$log_dir"
}
