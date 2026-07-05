---
title: Notificaciones
description: Recibe avisos por Telegram o Discord cuando cambien tus registros DNS.
---

El actualizador puede avisarte cada vez que envía cambios de registros (y cuando falla una actualización por lotes). Ambos canales son opcionales y están desactivados por defecto.

## Telegram

1. Habla con [@BotFather](https://t.me/BotFather), envía `/newbot` y sigue las instrucciones. Copia el **token del bot**.
2. Obtén tu **chat ID**: envía cualquier mensaje a tu bot y abre `https://api.telegram.org/bot<TOKEN>/getUpdates` en el navegador; lee `chat.id` en la respuesta. (Para un grupo, añade antes el bot al grupo.)
3. Configura:

```yaml
notifications:
  telegram:
    enabled: true
    bot_token: "123456789:AAF..."
    chat_id: "123456789"
```

El texto del mensaje se codifica (URL-encode) automáticamente, así que IPs y espacios llegan intactos.

## Discord

1. En tu servidor: **Ajustes del servidor → Integraciones → Webhooks → Nuevo webhook**.
2. Elige el canal y copia la **URL del webhook**.
3. Configura:

```yaml
notifications:
  discord:
    enabled: true
    webhook_url: "https://discord.com/api/webhooks/..."
```

El contenido del mensaje se escapa como JSON automáticamente.

## ¿Cuándo se envían?

- Tras una actualización por lotes correcta: un mensaje con cuántos registros cambiaron y la(s) nueva(s) IP(s).
- Tras un fallo en la actualización por lotes: un aviso de error.
- Nunca cuando no hay cambios — un cron sin novedades permanece en silencio.
