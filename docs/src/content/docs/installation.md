---
title: Installation
description: Install Cloudflare DNS Updater from a standalone binary or from source.
---

## Standalone binaries

Pre-compiled binaries bundle the script's own dependencies (Bash, curl, jq); the self-extracting launcher only relies on basic system tools (`tar`, and PowerShell on Windows) to unpack itself.

1. Download the latest release for your platform from the [Releases page](https://github.com/jmrplens/Cloudflare-DNS-Updater/releases):
   - **Linux**: `cf-updater-linux-x86_64` (Intel/AMD) or `cf-updater-linux-aarch64` (ARM/Raspberry Pi)
   - **macOS**: `cf-updater-macos-x86_64` (Intel) or `cf-updater-macos-aarch64` (Apple Silicon)
   - **Windows**: `cf-updater-windows-x86_64.exe`
2. Make it executable (Linux/macOS):

   ```bash
   chmod +x cf-updater-linux-x86_64
   ```

3. Run it from the directory that contains your `cloudflare-dns.yaml`, or pass the config path as an argument:

   ```bash
   ./cf-updater-linux-x86_64 /path/to/cloudflare-dns.yaml
   ```

## From source

**Requirements:**

- [Bash](https://www.gnu.org/software/bash/) 4.0+
- [curl](https://curl.se/) (wget or PowerShell are used as fallbacks)
- [jq](https://jqlang.github.io/jq/) — strongly recommended; without it a slower, limited parser is used

```bash
git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
cd Cloudflare-DNS-Updater
cp config.example.yaml cloudflare-dns.yaml
chmod 600 cloudflare-dns.yaml
./cloudflare-dns-updater.sh
```

The launcher looks for `cloudflare-dns.yaml` next to itself.

:::caution[Protect your token]
`cloudflare-dns.yaml` contains your Cloudflare API token. Keep it readable only by its owner (`chmod 600`); the program warns at startup if other users can read it.
:::
