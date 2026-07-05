---
title: Instalación
description: Instala Cloudflare DNS Updater desde un binario autónomo o desde el código fuente.
---

## Binarios autónomos

Los binarios precompilados incluyen todo lo que necesita el script (Bash, curl, jq), así que funcionan en sistemas sin dependencias instaladas.

1. Descarga la última versión para tu plataforma desde la [página de Releases](https://github.com/jmrplens/Cloudflare-DNS-Updater/releases):
   - **Linux**: `cf-updater-linux-x86_64` (Intel/AMD) o `cf-updater-linux-aarch64` (ARM/Raspberry Pi)
   - **macOS**: `cf-updater-macos-x86_64` (Intel) o `cf-updater-macos-aarch64` (Apple Silicon)
   - **Windows**: `cf-updater-windows-x86_64.exe`
2. Dale permisos de ejecución (Linux/macOS):

   ```bash
   chmod +x cf-updater-linux-x86_64
   ```

3. Ejecútalo desde el directorio que contiene tu `cloudflare-dns.yaml`, o pasa la ruta de la configuración como argumento:

   ```bash
   ./cf-updater-linux-x86_64 /ruta/a/cloudflare-dns.yaml
   ```

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
