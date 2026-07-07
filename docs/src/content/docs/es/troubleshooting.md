---
title: Solución de problemas
description: Diagnostica los problemas más comunes de Cloudflare DNS Updater.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/es/troubleshooting/#faq","inLanguage":"es","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"¿Por qué dice que el script ya se está ejecutando?","acceptedAnswer":{"@type":"Answer","text":"Otra instancia tiene el lock (/tmp/cloudflare-dns-updater.lock). Es normal con cron si una ejecución anterior sigue activa. Vuelve a ejecutar; con flock el kernel libera el lock automáticamente, y con el mecanismo de PID-file un lock obsoleto se detecta y se sobrescribe."}},{"@type":"Question","name":"¿Por qué no detecta mi IPv4 o IPv6 pública?","acceptedAnswer":{"@type":"Answer","text":"La IPv4 se detecta con servicios externos (icanhazip.com, ifconfig.co, api.ipify.org), así que comprueba la conectividad HTTPS de salida. La IPv6 se lee primero de una interfaz local y luego de servicios externos. Si no tienes IPv6, pon ip_type: ipv4 en tus dominios para saltarte los registros AAAA."}},{"@type":"Question","name":"¿Por qué informa de que el registro no se ha encontrado?","acceptedAnswer":{"@type":"Answer","text":"El programa solo actualiza registros existentes. Crea el registro A o AAAA una vez en el panel de Cloudflare (con cualquier IP; se corrige en la siguiente ejecución) y vuelve a ejecutar."}},{"@type":"Question","name":"Los registros se actualizan pero los servicios fallan, ¿por qué?","acceptedAnswer":{"@type":"Answer","text":"Si un registro está proxificado (nube naranja), Cloudflare termina el tráfico y el TTL se ignora — es lo esperado. Para conexiones directas como SSH, servidores de juegos o correo, pon proxied: false en ese dominio."}},{"@type":"Question","name":"¿Cómo soluciono failed to fetch records o batch update failed?","acceptedAnswer":{"@type":"Answer","text":"Comprueba que el token tiene permiso Edit zone DNS para la zona configurada y no ha caducado, confirma que zone_id corresponde a la zona que contiene tus registros y vuelve a ejecutar con --debug para ver el cuerpo del error de la API (redactado)."}}]}
---

Ejecuta primero con `--debug`: imprime la detección de IP, cada petición a la API (con secretos redactados) y la decisión por registro. Al ejecutar desde el código fuente, la misma información queda en `logs/updater.log` dentro del directorio del proyecto.

## «Script is already running»

Otra instancia tiene el lock (`/tmp/cloudflare-dns-updater.lock`). Es normal con cron si una ejecución anterior sigue activa. Si realmente no hay ningún proceso, el lock usa `flock` y el kernel lo libera automáticamente — basta con volver a ejecutar; con el mecanismo alternativo de PID-file, el lock obsoleto se detecta y se sobrescribe.

## «Could not detect Public IPv4/IPv6»

- La IPv4 se detecta con servicios externos (`icanhazip.com`, `ifconfig.co`, `api.ipify.org`) — comprueba la conectividad HTTPS de salida.
- La IPv6 se lee primero de una interfaz local. Si tu interfaz no tiene IPv6 global, se intenta la detección externa. Define `options.interface` explícitamente si la interfaz autodetectada no es la correcta.
- ¿No tienes IPv6? Pon `ip_type: "ipv4"` en tus dominios para saltarte los registros AAAA.

## «Record ... not found. Creation not implemented.»

El programa solo **actualiza** registros existentes. Crea el registro A/AAAA una vez en el panel de Cloudflare (con cualquier IP; se corregirá en la siguiente ejecución) y vuelve a ejecutar.

## «Failed to fetch records» / «Batch update failed»

- Comprueba que el token tiene permiso **Edit zone DNS** para la zona configurada y no ha caducado.
- Comprueba que `zone_id` corresponde a la zona que contiene tus registros.
- Ejecuta con `--debug` para ver el cuerpo del error de la API (redactado).

## Los registros se actualizan pero los servicios fallan

Si un registro está proxificado (nube naranja), Cloudflare termina el tráfico y el TTL se ignora — es lo esperado. Para conexiones directas (SSH, servidores de juegos, correo), pon `proxied: false` en ese dominio.

## Aviso sobre los permisos de la configuración

`cloudflare-dns.yaml` contiene tu token de API. Silencia el aviso con:

```bash
chmod 600 cloudflare-dns.yaml
```

## Aviso sobre jq

Sin `jq` se usa un parser JSON limitado basado en sed. Funciona, pero instalar `jq` es más rápido y robusto — es un único paquete en cualquier sistema (`apt install jq`, `brew install jq`).
