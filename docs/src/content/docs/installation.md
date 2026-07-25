---
title: Installation
description: Install Cloudflare DNS Updater from a standalone binary or from source.
---

## Standalone binaries

Pre-compiled binaries are available for Linux and macOS. They bundle Bash and jq, the two dependencies a host is most likely to lack or to have in too old a version. `curl` and the usual command line tools are taken from the system, and the self-extracting launcher needs `tar` to unpack itself. On Windows, see [below](#windows).

1. Download the latest release for your platform from the [Releases page](https://github.com/jmrplens/Cloudflare-DNS-Updater/releases):
   - **Linux**: `cf-updater-linux-x86_64` (Intel/AMD) or `cf-updater-linux-aarch64` (ARM/Raspberry Pi)
   - **macOS**: `cf-updater-macos-x86_64` (Intel) or `cf-updater-macos-aarch64` (Apple Silicon)
2. Make it executable (Linux/macOS):

   ```bash
   chmod +x cf-updater-linux-x86_64
   ```

3. Run it from the directory that contains your `cloudflare-dns.yaml`, or pass the config path as an argument:

   ```bash
   ./cf-updater-linux-x86_64 /path/to/cloudflare-dns.yaml
   ```

## Windows

There is no Windows binary. This program needs a real Bash: it relies on arrays, `BASH_SOURCE` and here-strings, none of which BusyBox's `ash` implements, and there is no single-file static Bash for Windows to bundle instead.

Run it from source under one of:

- [**WSL**](https://learn.microsoft.com/windows/wsl/install), which gives you a normal Linux environment and is the smoothest option.
- [**Git Bash**](https://git-scm.com/downloads), which ships Bash, `sed`, `grep` and `curl`.
- [**MSYS2**](https://www.msys2.org/), if you already use it.

Follow the [From source](#from-source) steps as on Linux. See [Automation](../automation/#windows-task-scheduler) for scheduling with Task Scheduler.

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
