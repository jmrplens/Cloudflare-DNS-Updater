---
title: Primeros pasos
description: Configura Cloudflare DNS Updater en cinco minutos.
---

Cloudflare DNS Updater mantiene los registros A (IPv4) y AAAA (IPv6) de tu zona de Cloudflare apuntando a tu IP pública actual. Es un programa Bash puro: ejecútalo desde el código fuente o con un binario autónomo, apúntalo a una configuración YAML y prográmalo con cron o cualquier planificador de tareas.

## 1. Obtén el programa

Descarga un [binario autónomo](../installation/#binarios-autonomos) o clona el repositorio:

```bash
git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
cd Cloudflare-DNS-Updater
```

## 2. Crea un token de API de Cloudflare

1. En el [panel de Cloudflare](https://dash.cloudflare.com/profile/api-tokens), crea un token con la plantilla **Edit zone DNS**.
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
