#!/usr/bin/env bash

send_notification() {
    local message="$1"
    
    # Telegram
    if [[ "$TG_ENABLED" == "true" ]]; then
        if [[ -n "$TG_BOT_TOKEN" && -n "$TG_CHAT_ID" ]]; then
             curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
                -d chat_id="$TG_CHAT_ID" \
                -d text="$message" > /dev/null
        fi
    fi

    # Discord
    if [[ "$DISCORD_ENABLED" == "true" ]]; then
        if [[ -n "$DISCORD_WEBHOOK" ]]; then
            curl -s -H "Content-Type: application/json" \
                -d "{\"content\": \"$message\"}" \
                "$DISCORD_WEBHOOK" > /dev/null
        fi
    fi
}
