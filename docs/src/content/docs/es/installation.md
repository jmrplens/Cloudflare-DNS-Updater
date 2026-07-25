---
title: Instalación
description: Instala Cloudflare DNS Updater desde un binario autónomo o desde el código fuente.
---

## Binarios autónomos

Hay binarios precompilados para Linux y macOS. Incluyen Bash y jq, las dos dependencias que con más probabilidad faltan en el anfitrión o están en una versión demasiado antigua. `curl` y las herramientas habituales de línea de comandos se toman del sistema, y el ejecutor autoextraíble necesita `tar` para desempaquetarse. Para Windows, mira [más abajo](#windows).

1. Descarga la última versión para tu plataforma desde la [página de Releases](https://github.com/jmrplens/Cloudflare-DNS-Updater/releases):
   - **Linux**: `cf-updater-linux-x86_64` (Intel/AMD) o `cf-updater-linux-aarch64` (ARM/Raspberry Pi)
   - **macOS**: `cf-updater-macos-x86_64` (Intel) o `cf-updater-macos-aarch64` (Apple Silicon)
2. Dale permisos de ejecución (Linux/macOS):

   ```bash
   chmod +x cf-updater-linux-x86_64
   ```

3. Ejecútalo desde el directorio que contiene tu `cloudflare-dns.yaml`, o pasa la ruta de la configuración como argumento:

   ```bash
   ./cf-updater-linux-x86_64 /ruta/a/cloudflare-dns.yaml
   ```

## Windows

No hay binario para Windows. Este programa necesita un Bash real: usa arrays, `BASH_SOURCE` y here-strings, nada de lo cual implementa el `ash` de BusyBox, y no existe un Bash estático de un solo fichero para Windows que empaquetar en su lugar.

Ejecútalo desde el código fuente con una de estas opciones:

- [**WSL**](https://learn.microsoft.com/windows/wsl/install), que te da un entorno Linux normal y es la opción más cómoda.
- [**Git Bash**](https://git-scm.com/downloads), que incluye Bash, `sed`, `grep` y `curl`.
- [**MSYS2**](https://www.msys2.org/), si ya lo usas.

Sigue los pasos de [Desde el código fuente](#desde-el-código-fuente) igual que en Linux. Para programarlo con el Programador de tareas, mira [Automatización](../automation/#windows-programador-de-tareas).

## Desde el código fuente

**Requisitos:**

- [Bash](https://www.gnu.org/software/bash/) 4.0+
- [curl](https://curl.se/) (wget o PowerShell se usan como alternativas)
- [jq](https://jqlang.github.io/jq/) — muy recomendado; sin él se usa un parser más lento y limitado

```bash
git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
cd Cloudflare-DNS-Updater
cp config.example.yaml cloudflare-dns.yaml
chmod 600 cloudflare-dns.yaml
./cloudflare-dns-updater.sh
```

El lanzador busca `cloudflare-dns.yaml` junto a sí mismo.

:::caution[Protege tu token]
`cloudflare-dns.yaml` contiene tu token de API de Cloudflare. Mantenlo legible solo por su propietario (`chmod 600`); el programa avisa al arrancar si otros usuarios pueden leerlo.
:::
