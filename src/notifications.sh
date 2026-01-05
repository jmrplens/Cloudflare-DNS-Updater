#!/usr/bin/env bash

send_notification() {
	local message="$1"

	# Telegram
	if [[ "$TG_ENABLED" == "true" ]]; then
		if [[ -n "$TG_BOT_TOKEN" && -n "$TG_CHAT_ID" ]]; then
			# Simple body construction (Telegram supports URL-encoded POST)
			local body="chat_id=${TG_CHAT_ID}&text=${message}"
			http_request "POST" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" "$body" >/dev/null
		fi
	fi

	# Discord
	if [[ "$DISCORD_ENABLED" == "true" ]]; then
		if [[ -n "$DISCORD_WEBHOOK" ]]; then
			local body="{\"content\": \"$message\"}"
			http_request "POST" "$DISCORD_WEBHOOK" "$body" "Content-Type: application/json" >/dev/null
		fi
	fi
}
