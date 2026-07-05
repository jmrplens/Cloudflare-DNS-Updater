---
title: Notifications
description: Get Telegram or Discord alerts when your DNS records change.
---

The updater can notify you whenever it pushes record changes (and when a batch update fails). Both channels are optional and disabled by default.

## Telegram

1. Talk to [@BotFather](https://t.me/BotFather), send `/newbot` and follow the prompts. Copy the **bot token**.
2. Get your **chat ID**: send any message to your new bot, then open `https://api.telegram.org/bot<TOKEN>/getUpdates` in a browser and read `chat.id` from the response. (For a group, add the bot to the group first.)
3. Configure:

```yaml
notifications:
  telegram:
    enabled: true
    bot_token: "123456789:AAF..."
    chat_id: "123456789"
```

Message text is URL-encoded automatically, so IPs and spaces arrive intact.

## Discord

1. In your server: **Server Settings → Integrations → Webhooks → New Webhook**.
2. Pick the channel and copy the **webhook URL**.
3. Configure:

```yaml
notifications:
  discord:
    enabled: true
    webhook_url: "https://discord.com/api/webhooks/..."
```

Message content is JSON-escaped automatically.

## When are notifications sent?

- After a successful batch update: one message listing how many records changed and the new IP(s).
- After a failed batch update: a failure notice.
- Never when nothing changed — a quiet cron run stays quiet.
