---
title: Automatización
description: Ejecuta Cloudflare DNS Updater periódicamente con cron, systemd o el Programador de tareas.
---

Las IP dinámicas cambian sin avisar, así que conviene ejecutar el actualizador periódicamente. Cuando no hay cambios termina enseguida (una lectura paginada de la API, ninguna escritura), y el lock evita ejecuciones solapadas.

## Linux / macOS: cron

```bash
crontab -e
```

```bash
# Cada 5 minutos, en silencio
*/5 * * * * /opt/Cloudflare-DNS-Updater/cloudflare-dns-updater.sh --silent
```

Usa la ruta absoluta al lanzador (o al binario). `--silent` ya suprime la salida; los errores se siguen imprimiendo y llegan al correo de cron si está configurado.

## Linux: timer de systemd

`/etc/systemd/system/cf-updater.service`:

```ini
[Unit]
Description=Cloudflare DNS Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/Cloudflare-DNS-Updater/cloudflare-dns-updater.sh --silent
```

`/etc/systemd/system/cf-updater.timer`:

```ini
[Unit]
Description=Ejecutar Cloudflare DNS Updater cada 5 minutos

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cf-updater.timer
systemctl list-timers cf-updater.timer
```

## Windows: Programador de tareas

1. Abre el **Programador de tareas** → *Crear tarea básica*.
2. Ponle un nombre, p. ej. "Cloudflare DNS Updater".
3. Desencadenador: **Diariamente**; después, en las propiedades de la tarea, marca *Repetir la tarea cada 5 minutos* con duración *Indefinidamente*.
4. Acción: **Iniciar un programa** → busca `cf-updater-windows-x86_64.exe`.
5. Argumentos: `--silent`.
6. En la configuración de la tarea, establece *Iniciar en* a la carpeta que contiene `cloudflare-dns.yaml`.

## Elegir el intervalo

Cada ejecución sin cambios cuesta una petición de lectura a la API de Cloudflare. El límite global de la API (1200 peticiones por 5 minutos y usuario) deja un margen enorme incluso ejecutando cada minuto; cada 5 minutos es un valor cómodo para conexiones domésticas.
