#!/usr/bin/env bash
# Unit tests for src/config.sh (YAML parser)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."
FIXTURES="$TESTS_DIR/fixtures"

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/logger.sh"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/config.sh"
	parse_config "$FIXTURES/full_config.yaml"
}

# --- Global settings ---

function test_parses_zone_id() {
	assert_same "test-zone-123" "$CF_ZONE_ID"
}

function test_parses_api_token() {
	assert_same "test-token-abc" "$CF_API_TOKEN"
}

function test_parses_network_interface() {
	assert_same "eth0" "$NET_INTERFACE"
}

# --- Notifications ---

function test_parses_telegram_settings() {
	assert_same "true" "$TG_ENABLED"
	assert_same "tg-bot-token" "$TG_BOT_TOKEN"
	assert_same "12345" "$TG_CHAT_ID"
}

function test_parses_discord_settings() {
	assert_same "false" "$DISCORD_ENABLED"
	assert_same "https://discord.example.invalid/webhook" "$DISCORD_WEBHOOK"
}

# --- Domains block ---

function test_parses_all_domains() {
	assert_same "4" "$DOMAIN_COUNT"
	assert_same "example.com" "${domains_names[0]}"
	assert_same "v4.example.com" "${domains_names[1]}"
	assert_same "v6.example.com" "${domains_names[2]}"
	assert_same "direct.example.com" "${domains_names[3]}"
}

function test_domain_defaults() {
	assert_same "true" "${domains_proxied[0]}"
	assert_same "true" "${domains_ipv4[0]}"
	assert_same "true" "${domains_ipv6[0]}"
	assert_same "auto" "${domains_ttl[0]}"
}

function test_ip_type_ipv4_disables_ipv6() {
	assert_same "true" "${domains_ipv4[1]}"
	assert_same "false" "${domains_ipv6[1]}"
}

function test_ip_type_ipv6_disables_ipv4() {
	assert_same "false" "${domains_ipv4[2]}"
	assert_same "true" "${domains_ipv6[2]}"
}

function test_ip_type_both_enables_all() {
	assert_same "true" "${domains_ipv4[3]}"
	assert_same "true" "${domains_ipv6[3]}"
}

function test_domain_overrides_proxied_and_ttl() {
	assert_same "false" "${domains_proxied[3]}"
	assert_same "300" "${domains_ttl[3]}"
}

# --- Error handling ---

function test_missing_config_file_returns_error() {
	assert_general_error "$(parse_config "$FIXTURES/does-not-exist.yaml" 2>/dev/null)"
}
