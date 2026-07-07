---
title: Automatización
description: Ejecuta Cloudflare DNS Updater periódicamente con cron, systemd o el Programador de tareas.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/es/automation/","inLanguage":"es","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"¿Con qué frecuencia debe ejecutarse?","acceptedAnswer":{"@type":"Answer","text":"Cada 5 minutos es un valor cómodo para conexiones domésticas. El límite de Cloudflare de 1200 peticiones por 5 minutos deja un margen amplio incluso ejecutando cada minuto."}},{"@type":"Question","name":"¿Las ejecuciones solapadas causan problemas?","acceptedAnswer":{"@type":"Answer","text":"No. Un lockfile hace que una segunda invocación salga de inmediato, así que los intervalos agresivos son seguros."}},{"@type":"Question","name":"¿Cómo compruebo que funciona?","acceptedAnswer":{"@type":"Answer","text":"Ejecútalo una vez con --debug para ver la detección de IP y las llamadas a la API. Al ejecutar desde el código fuente, la misma salida se escribe también en logs/updater.log dentro del directorio del proyecto."}},{"@type":"Question","name":"¿Una ejecución cuesta una petición a la API cuando no hay cambios?","acceptedAnswer":{"@type":"Answer","text":"Sí, una petición de lectura por ejecución. Solo escribe en la API cuando la IP ha cambiado realmente (o cuando pasas --force)."}}]}
---

Las IP dinámicas cambian sin avisar, así que conviene ejecutar el actualizador periódicamente. Cuando no hay cambios termina enseguida (una lectura paginada de la API, ninguna escritura), y el lock evita ejecuciones solapadas.

## Linux / macOS: cron

Programa el actualizador con [cron](https://man7.org/linux/man-pages/man5/crontab.5.html):

```bash
crontab -e
```

```bash
# Cada 5 minutos, en silencio
*/5 * * * * /opt/Cloudflare-DNS-Updater/cloudflare-dns-updater.sh --silent
```

Usa la ruta absoluta al lanzador (o al binario). `--silent` ya suprime la salida; los errores se siguen imprimiendo y llegan al correo de cron si está configurado.

## Linux: timer de systemd

¿Prefieres un [timer de systemd](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)? Crea la unidad de servicio en `/etc/systemd/system/cf-updater.service`:

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

1. Abre el [**Programador de tareas**](https://learn.microsoft.com/es-es/windows/win32/taskschd/task-scheduler-start-page) → *Crear tarea básica*.
2. Ponle un nombre, p. ej. "Cloudflare DNS Updater".
3. Desencadenador: **Diariamente**; después, en las propiedades de la tarea, marca *Repetir la tarea cada 5 minutos* con duración *Indefinidamente*.
4. Acción: **Iniciar un programa** → busca `cf-updater-windows-x86_64.exe`.
5. Argumentos: `--silent`.
6. En la configuración de la tarea, establece *Iniciar en* a la carpeta que contiene `cloudflare-dns.yaml`.

## Elegir el intervalo

Cada ejecución sin cambios cuesta una petición de lectura a la API de Cloudflare. El límite global de la API (1200 peticiones por 5 minutos y usuario) deja un margen enorme incluso ejecutando cada minuto; cada 5 minutos es un valor cómodo para conexiones domésticas.

## Preguntas frecuentes

### ¿Con qué frecuencia debe ejecutarse?

Cada 5 minutos es un valor cómodo para conexiones domésticas. El límite de Cloudflare de 1200 peticiones por 5 minutos deja un margen amplio incluso ejecutando cada minuto.

### ¿Las ejecuciones solapadas causan problemas?

No. Un lockfile hace que una segunda invocación salga de inmediato, así que los intervalos agresivos son seguros.

### ¿Cómo compruebo que funciona?

Ejecútalo una vez con `--debug` para ver la detección de IP y las llamadas a la API. Al ejecutar desde el código fuente, la misma salida se escribe también en `logs/updater.log` dentro del directorio del proyecto.

### ¿Una ejecución cuesta una petición a la API cuando no hay cambios?

Sí, una petición de lectura por ejecución. Solo escribe en la API cuando la IP ha cambiado realmente (o cuando pasas `--force`).
