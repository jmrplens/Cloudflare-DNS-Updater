---
title: Compilar binarios
description: Empaqueta el script y compila los binarios autónomos.
---

## Estructura del proyecto

```text
src/            módulos del programa
├── main.sh          punto de entrada y orquestación
├── cloudflare.sh    interacción con la API de Cloudflare
├── config.sh        parseo de la configuración YAML
├── ip.sh            detección de IP (interfaz local + servicios externos)
├── network.sh       wrapper HTTP sobre curl/wget/PowerShell
├── logger.sh        logging a consola y fichero, redacción de secretos
└── notifications.sh Telegram / Discord

tools/          herramientas de build y calidad
tests/          tests unitarios con bashunit
cloudflare-dns-updater.sh   lanzador de desarrollo (ejecuta desde el código fuente)
```

## Monolito

Todos los módulos de `src/` fusionados en un único script autocontenido:

```bash
./tools/bundle.sh
# → dist/cloudflare-dns-updater-monolith.sh
```

## Binarios autónomos

`tools/build-all.sh` genera binarios sin dependencias: descarga builds estáticos de bash, curl, jq y busybox para la arquitectura objetivo, los empaqueta con el monolito y compila `tools/launcher.c` como ejecutor autoextraíble.

```bash
# Todo
./tools/build-all.sh --all

# Una plataforma
./tools/build-all.sh linux x86_64
./tools/build-all.sh windows x86_64
```

Requiere GCC (o MinGW para Windows). Los artefactos se generan en `dist/`.

## Binarios de release en CI

El workflow **Binaries Build** compila todas las plataformas en cada release. Consulta `.github/workflows/binaries.yml`.
