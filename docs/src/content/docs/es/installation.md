---
title: Instalación
description: Instala Cloudflare DNS Updater desde un binario autónomo o desde el código fuente.
---

## Binarios autónomos

Hay binarios precompilados para Linux y macOS. Incluyen Bash y jq, las dos dependencias que con más probabilidad faltan en el anfitrión o están en una versión demasiado antigua. El [cliente HTTP](#cliente-http) y las herramientas habituales de línea de comandos se toman del sistema, y el ejecutor autoextraíble necesita `tar` para desempaquetarse. Para Windows, mira [más abajo](#windows).

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
- Un [cliente HTTP](#cliente-http): [curl](https://curl.se/), [GNU Wget](https://www.gnu.org/software/wget/) 1.15 o posterior, o [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
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

## Cliente HTTP

Cada petición pasa por el primero de estos que encuentre el programa:

1. `curl`, o el `curl.exe` del propio Windows desde WSL
2. GNU Wget 1.15 o posterior, o GNU Wget2, instalado como `wget` o como `wget2`
3. PowerShell: `pwsh`, o el `powershell.exe` de Windows PowerShell en Git Bash, MSYS2 o WSL

Si no hay ninguno, el programa se detiene antes de hacer nada más, y dice qué falta y cómo instalar curl. Cualquiera de los tres envía todas las peticiones que hace el programa:

| Petición | curl, GNU Wget | PowerShell |
| --- | --- | --- |
| IPv4 pública | `icanhazip.com`, `ifconfig.co` y `api.ipify.org`, forzando IPv4 | `ipv4.icanhazip.com` y `api.ipify.org` |
| IPv6 pública, cuando ninguna interfaz local la tiene | `icanhazip.com` e `ifconfig.co`, forzando IPv6 | `ipv6.icanhazip.com` |
| Cloudflare: leer los registros A y AAAA de la zona (GET) | Sí | Sí |
| Cloudflare: actualización por lotes (POST con cuerpo JSON) | Sí | Sí |
| Notificaciones de Telegram y Discord (POST) | Sí | Sí |

PowerShell no puede elegir entre IPv4 e IPv6 para una petición, así que pregunta a los nombres de esos servicios que solo responden en una familia, y se salta `ifconfig.co`, que no los tiene. Nada en el programa necesita curl en concreto.

### wget de BusyBox

El `wget` de Alpine, de las imágenes BusyBox y de muchos routers es el de BusyBox, y el programa no lo usa: no puede forzar IPv4 ni IPv6, descarta el cuerpo de una respuesta de error (donde Cloudflare explica qué ha fallado) y varias de sus compilaciones no comprueban los certificados TLS, lo que entregaría tu token de API a cualquiera que esté en medio. Instala curl (`apk add curl` en Alpine) o GNU Wget (`apk add wget`) junto a él.
