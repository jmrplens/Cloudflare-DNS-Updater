#!/usr/bin/env bash
# Unit tests for src/notifications.sh

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/notifications.sh"
}

# --- Encoding helpers ---

function test_url_encode_keeps_unreserved_characters() {
	assert_same "abc-123_x.y~z" "$(url_encode "abc-123_x.y~z")"
}

function test_url_encode_encodes_spaces_and_symbols() {
	assert_same "Updated%202%20records%20to%201.2.3.4" \
		"$(url_encode "Updated 2 records to 1.2.3.4")"
}

function test_url_encode_encodes_ampersand_and_equals() {
	assert_same "a%3Db%26c%3Dd" "$(url_encode "a=b&c=d")"
}

function test_json_escape_escapes_quotes() {
	assert_same 'say \"hi\"' "$(json_escape 'say "hi"')"
}

function test_json_escape_escapes_backslashes_and_newlines() {
	assert_same 'path\\to\nend' "$(json_escape $'path\\to\nend')"
}

# --- send_notification ---

function test_telegram_notification_sends_encoded_body() {
	TG_ENABLED="true" TG_BOT_TOKEN="bt" TG_CHAT_ID="42" DISCORD_ENABLED="false"
	bashunit::spy http_request
	send_notification "IP changed to 1.2.3.4"
	assert_have_been_called_with http_request \
		POST "https://api.telegram.org/botbt/sendMessage" \
		"chat_id=42&text=IP%20changed%20to%201.2.3.4"
}

function test_discord_notification_escapes_json() {
	TG_ENABLED="false" DISCORD_ENABLED="true" DISCORD_WEBHOOK="https://discord.example.invalid/wh"
	bashunit::spy http_request
	send_notification 'quote " inside'
	assert_have_been_called_with http_request \
		POST "https://discord.example.invalid/wh" \
		'{"content": "quote \" inside"}' "Content-Type: application/json"
}

function test_no_notification_sent_when_disabled() {
	TG_ENABLED="false" DISCORD_ENABLED="false"
	bashunit::spy http_request
	send_notification "nothing should happen"
	assert_have_been_called_times 0 http_request
}

function test_telegram_skipped_without_credentials() {
	TG_ENABLED="true" TG_BOT_TOKEN="" TG_CHAT_ID="" DISCORD_ENABLED="false"
	bashunit::spy http_request
	send_notification "no creds"
	assert_have_been_called_times 0 http_request
}
