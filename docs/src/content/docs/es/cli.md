---
title: Línea de comandos
description: Opciones de línea de comandos de Cloudflare DNS Updater.
---

```bash
./cloudflare-dns-updater.sh [opciones]
cf-updater [opciones] [config_file.yaml]
```

El lanzador del código fuente (`cloudflare-dns-updater.sh`) usa siempre el `cloudflare-dns.yaml` que tiene al lado. Los binarios autónomos y el monolito también aceptan la ruta de una configuración como argumento posicional, con `cloudflare-dns.yaml` del directorio actual como alternativa.

## Opciones

| Opción | Descripción |
| --- | --- |
| `-h`, `--help` | Muestra la ayuda y termina. |
| `-s`, `--silent` | Sin salida por consola salvo errores. Recomendado para cron. |
| `-d`, `--debug` | Salida detallada: detección de IP, peticiones/respuestas de la API (con secretos redactados) y decisión por registro. |
| `-f`, `--force` | Envía actualizaciones aunque el registro ya coincida con la IP actual. |

## Códigos de salida

| Código | Significado |
| --- | --- |
| `0` | Éxito: registros actualizados o ya al día. |
| `1` | Error: otra instancia en ejecución, dependencia ausente (`curl`), configuración inexistente o inválida, ninguna IP detectada, o fallo en la API de Cloudflare. |

## Concurrencia

Solo se ejecuta una instancia a la vez: el programa toma un lock exclusivo (`flock` cuando está disponible, con PID-file como alternativa) sobre `/tmp/cloudflare-dns-updater.lock`. Una segunda invocación termina inmediatamente con un mensaje — lo que hace seguros los cron agresivos.

## Logs

Al ejecutar desde el código fuente, cada ejecución se registra en `logs/updater.log` dentro del directorio del proyecto (texto plano, sin colores), con rotación automática a `updater.log.old` al alcanzar 1 MB. Los binarios autónomos se ejecutan desde un directorio temporal, así que su log de fichero no persiste en una ubicación fija — usa la salida de consola (o `--debug`).
