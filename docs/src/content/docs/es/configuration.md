---
title: Configuración
description: Referencia completa de cloudflare-dns.yaml.
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
