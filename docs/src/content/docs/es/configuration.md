---
title: Configuración
description: Referencia completa de cloudflare-dns.yaml.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/es/configuration/","inLanguage":"es","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"¿Qué TTL debo usar?","acceptedAnswer":{"@type":"Answer","text":"Deja ttl: 1 (Auto) para registros proxificados: Cloudflare ignora el TTL mientras un registro está proxificado. Para registros solo DNS, pon un valor en segundos (60–86400); un TTL más bajo propaga los cambios de IP más rápido."}},{"@type":"Question","name":"¿Qué hace proxied?","acceptedAnswer":{"@type":"Answer","text":"proxied: true enruta el tráfico por el proxy de Cloudflare (nube naranja); proxied: false es solo DNS (nube gris), que es lo que quieres para conexiones directas como SSH, servidores de juegos o correo."}},{"@type":"Question","name":"¿Puedo actualizar un registro comodín?","acceptedAnswer":{"@type":"Answer","text":"Sí. Usa name: \"*.example.com\". Como cualquier registro, el comodín debe existir ya en Cloudflare: el programa actualiza registros, no los crea."}},{"@type":"Question","name":"¿Puedo gestionar solo IPv4 o solo IPv6?","acceptedAnswer":{"@type":"Answer","text":"Sí. Cada dominio gestiona A y AAAA por defecto; pon ip_type: ipv4 o ip_type: ipv6 en un dominio para limitarlo."}},{"@type":"Question","name":"¿Dónde debe estar el fichero de configuración?","acceptedAnswer":{"@type":"Answer","text":"cloudflare-dns.yaml junto al lanzador por defecto. Pasa una ruta como argumento para usar otra ubicación."}}]}
---

El programa lee un fichero YAML — `cloudflare-dns.yaml` por defecto — con cuatro secciones: `cloudflare`, `options`, `domains` y `notifications`.

## Ejemplo completo

```yaml
cloudflare:
  zone_id: "tu_zone_id"
  api_token: "tu_api_token"

options:
  proxied: true   # valor por defecto global: true = proxy de Cloudflare (nube naranja)
  ttl: 1          # TTL por defecto: 1 = Auto, o segundos (60-86400)
  interface: ""   # opcional: interfaz de red para la detección local de IPv6 (p. ej. "eth0")

domains:
  # Actualiza los registros A y AAAA (comportamiento por defecto)
  - name: "example.com"

  # Solo IPv4 (registro A)
  - name: "ipv4.example.com"
    ip_type: "ipv4"

  # Solo IPv6 (registro AAAA)
  - name: "ipv6.example.com"
    ip_type: "ipv6"

  # Ajustes por dominio
  - name: "direct.example.com"
    proxied: false
    ttl: 300

notifications:
  telegram:
    enabled: false
    bot_token: ""
    chat_id: ""

  discord:
    enabled: false
    webhook_url: ""
```

## `cloudflare`

| Clave | Obligatoria | Descripción |
| --- | --- | --- |
| `zone_id` | sí | El Zone ID que aparece en la página *Overview* de tu zona. |
| `api_token` | sí | Un token de API con permiso [**Edit zone DNS**](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) para esa zona. |

:::caution[Protege tus credenciales]
`cloudflare-dns.yaml` contiene tu token de API. Restríngelo a tu usuario con `chmod 600 cloudflare-dns.yaml` y limita el token a **Edit zone DNS** para una sola zona en lugar de usar una Global API Key — así, si el fichero se filtra, solo puede afectar al DNS de esa zona. El programa avisa al arrancar si el fichero es legible por todos.
:::

## `options`

Valores por defecto globales que heredan todos los dominios.

| Clave | Por defecto | Descripción |
| --- | --- | --- |
| `proxied` | `true` | `true` enruta el tráfico a través de Cloudflare (nube naranja); `false` es solo DNS (nube gris). |
| `ttl` | `1` | TTL del registro en segundos. `1` significa *Auto*. Cloudflare lo ignora mientras el registro está proxificado. |
| `interface` | autodetección | Interfaz de red para la detección local de IPv6. Si está vacío, se usa la interfaz de la ruta por defecto. |

## `domains`

Lista de registros a mantener actualizados. Cada entrada acepta:

| Clave | Por defecto | Descripción |
| --- | --- | --- |
| `name` | — | Nombre del registro (p. ej. `casa.example.com`, `example.com` o el comodín `*.example.com`). El registro debe existir ya en Cloudflare; el programa actualiza registros, no los crea. |
| `ip_type` | `both` | Qué registros gestionar: `ipv4` (solo A), `ipv6` (solo AAAA) o `both` (ambos). |
| `proxied` | de `options` | Ajuste de proxy por dominio. |
| `ttl` | de `options` | TTL por dominio. |

Los valores pueden ir con o sin comillas; los comentarios al final de una línea se ignoran. Los ficheros con finales de línea de Windows (CRLF) se procesan correctamente.

## `notifications`

Consulta [Notificaciones](../notifications/) para las guías de configuración.

:::note[Zonas con muchos registros]
Los registros se obtienen de 5000 en 5000 por llamada y la paginación se sigue automáticamente, así que funcionan zonas de cualquier tamaño.
:::

## Preguntas frecuentes

### ¿Qué TTL debo usar?

Deja `ttl: 1` (Auto) para registros proxificados: Cloudflare ignora el TTL mientras un registro está proxificado. Para registros solo DNS, pon un valor en segundos (60–86400); un TTL más bajo propaga los cambios de IP más rápido.

### ¿Qué hace `proxied`?

`proxied: true` enruta el tráfico por el proxy de Cloudflare (nube naranja); `proxied: false` es solo DNS (nube gris), que es lo que quieres para conexiones directas como SSH, servidores de juegos o correo.

### ¿Puedo actualizar un registro comodín?

Sí. Usa `name: "*.example.com"`. Como cualquier registro, el comodín debe existir ya en Cloudflare: el programa actualiza registros, no los crea.

### ¿Puedo gestionar solo IPv4 o solo IPv6?

Sí. Cada dominio gestiona A y AAAA por defecto; pon `ip_type: ipv4` o `ip_type: ipv6` en un dominio para limitarlo.

### ¿Dónde debe estar el fichero de configuración?

`cloudflare-dns.yaml` junto al lanzador por defecto. Pasa una ruta como argumento para usar otra ubicación.
