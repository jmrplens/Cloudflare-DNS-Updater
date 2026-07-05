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
# --all compila los objetivos Linux (x86_64 + aarch64)
./tools/build-all.sh --all

# El resto de plataformas se compilan nombrándolas explícitamente
./tools/build-all.sh macos aarch64
./tools/build-all.sh windows x86_64
```

Requiere GCC (o MinGW para Windows). Los artefactos se generan en `dist/`.

## Publicar una release

Las releases se controlan con el fichero `VERSION` de la raíz del repositorio:

1. Sube la versión en **ambos** sitios: el fichero `VERSION` y la constante `VERSION` de `src/main.sh` (un test unitario falla si difieren).
2. Mergea a `main`.

El workflow **Build & Release Binaries** (que solo se dispara con cambios en `VERSION`) compila los cinco binarios, crea el tag `vX.Y.Z` y publica la release de GitHub con notas autogeneradas. Ejecutar el workflow manualmente (`workflow_dispatch`) compila los binarios sin publicar nada.
