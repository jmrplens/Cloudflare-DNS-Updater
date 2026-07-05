#!/usr/bin/env bash

# Percent-encode a string for use in an application/x-www-form-urlencoded body
url_encode() {
	local raw="$1"
	local out=""
	local i c
	for ((i = 0; i < ${#raw}; i++)); do
		c="${raw:i:1}"
		case "$c" in
		[a-zA-Z0-9.~_-]) out+="$c" ;;
		*) out+=$(printf '%%%02X' "'$c") ;;
		esac
	done
	echo "$out"
}

# Escape a string for embedding inside a JSON string literal
json_escape() {
	local raw="$1"
	raw="${raw//\\/\\\\}"
	raw="${raw//\"/\\\"}"
	raw="${raw//$'\n'/\\n}"
	raw="${raw//$'\r'/\\r}"
	raw="${raw//$'\t'/\\t}"
	echo "$raw"
}

send_notification() {
	local message="$1"

	local body

	# Telegram
	if [[ "$TG_ENABLED" == "true" ]]; then
		if [[ -n "$TG_BOT_TOKEN" && -n "$TG_CHAT_ID" ]]; then
			body="chat_id=${TG_CHAT_ID}&text=$(url_encode "$message")"
			http_request "POST" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" "$body" >/dev/null
		fi
	fi

	# Discord
	if [[ "$DISCORD_ENABLED" == "true" ]]; then
		if [[ -n "$DISCORD_WEBHOOK" ]]; then
			body="{\"content\": \"$(json_escape "$message")\"}"
			http_request "POST" "$DISCORD_WEBHOOK" "$body" "Content-Type: application/json" >/dev/null
		fi
	fi
}
