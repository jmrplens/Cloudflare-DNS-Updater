---
title: Primeros pasos
description: Configura Cloudflare DNS Updater en cinco minutos.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/es/getting-started/#faq","inLanguage":"es","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"¿Cloudflare DNS Updater crea registros DNS?","acceptedAnswer":{"@type":"Answer","text":"No. Solo actualiza registros que ya existen. Crea el registro A o AAAA una vez en el panel de Cloudflare (con cualquier IP; se corrige en la siguiente ejecución) y luego ejecuta el programa."}},{"@type":"Question","name":"¿Es compatible con IPv6?","acceptedAnswer":{"@type":"Answer","text":"Sí. Mantiene actualizados los registros AAAA, prefiriendo la dirección IPv6 global estable de tu interfaz local y recurriendo a servicios externos como respaldo."}},{"@type":"Question","name":"¿Necesito jq para ejecutarlo?","acceptedAnswer":{"@type":"Answer","text":"No, pero es recomendable. Los binarios autónomos incluyen jq; desde el código fuente se usa un parser JSON más lento basado en sed cuando jq no está disponible."}},{"@type":"Question","name":"¿Qué permiso de token de API de Cloudflare necesita?","acceptedAnswer":{"@type":"Answer","text":"Un token de API limitado a Edit zone DNS para tu zona. No hace falta una Global API Key y se desaconseja."}},{"@type":"Question","name":"¿Con qué frecuencia debe ejecutarse?","acceptedAnswer":{"@type":"Answer","text":"Cada 5 minutos es un valor cómodo para conexiones domésticas. Un lockfile hace seguras las ejecuciones solapadas, así que también funcionan intervalos más cortos."}},{"@type":"Question","name":"¿Es gratuito y de código abierto?","acceptedAnswer":{"@type":"Answer","text":"Sí. Se publica bajo la licencia MIT."}}]}
---

Cloudflare DNS Updater mantiene los registros A (IPv4) y AAAA (IPv6) de tu zona de Cloudflare apuntando a tu IP pública actual. Es un programa Bash puro: ejecútalo desde el código fuente o con un binario autónomo, apúntalo a una configuración YAML y prográmalo con cron o cualquier planificador de tareas.

## 1. Obtén el programa

Descarga un [binario autónomo](../installation/#binarios-autonomos) o clona el repositorio:

```bash
git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
cd Cloudflare-DNS-Updater
```

## 2. Crea un token de API de Cloudflare

1. En el [panel de Cloudflare](https://dash.cloudflare.com/profile/api-tokens), crea un token con la plantilla [**Edit zone DNS**](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/).
2. Limítalo a la zona que quieres actualizar.
3. Copia el token — no volverás a verlo.

También necesitas el **Zone ID**, visible en la página *Overview* de la zona.

## 3. Configura

```bash
cp config.example.yaml cloudflare-dns.yaml
chmod 600 cloudflare-dns.yaml   # contiene tu token de API
```

Configuración mínima:

```yaml
cloudflare:
  zone_id: "tu_zone_id"
  api_token: "tu_api_token"

domains:
  - name: "example.com"
  - name: "www.example.com"
```

Consulta la [referencia de configuración](../configuration/) para ver todas las opciones.

## 4. Ejecútalo

```bash
# Desde el código fuente
./cloudflare-dns-updater.sh --debug

# O con un binario autónomo
./cf-updater-linux-x86_64 --debug /ruta/a/cloudflare-dns.yaml
```

Con `--debug` verás cada paso: la detección de IP, las llamadas a la API y la decisión por registro. Cuando todo esté correcto, [prográmalo](../automation/) y añade `--silent` para un funcionamiento silencioso.

## Preguntas frecuentes

### ¿Cloudflare DNS Updater crea registros DNS?

No. Solo actualiza registros que ya existen. Crea el registro A o AAAA una vez en el panel de Cloudflare (con cualquier IP; se corrige en la siguiente ejecución) y luego ejecuta el programa.

### ¿Es compatible con IPv6?

Sí. Mantiene actualizados los registros AAAA, prefiriendo la dirección IPv6 global estable de tu interfaz local y recurriendo a servicios externos como respaldo.

### ¿Necesito jq para ejecutarlo?

No, pero es recomendable. Los binarios autónomos incluyen jq; desde el código fuente se usa un parser JSON más lento basado en sed cuando jq no está disponible.

### ¿Qué permiso de token de API de Cloudflare necesita?

Un token de API limitado a **Edit zone DNS** para tu zona. No hace falta una Global API Key y se desaconseja.

### ¿Con qué frecuencia debe ejecutarse?

Cada 5 minutos es un valor cómodo para conexiones domésticas. Un lockfile hace seguras las ejecuciones solapadas, así que también funcionan intervalos más cortos.

### ¿Es gratuito y de código abierto?

Sí. Se publica bajo la [licencia MIT](https://github.com/jmrplens/Cloudflare-DNS-Updater/blob/main/LICENSE).
