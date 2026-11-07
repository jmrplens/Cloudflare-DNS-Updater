---
title: Installation
description: Install Cloudflare DNS Updater from a standalone binary or from source.
---

## Standalone binaries

Pre-compiled binaries are available for Linux and macOS. They bundle Bash and jq, the two dependencies a host is most likely to lack or to have in too old a version. The [HTTP client](#http-client) and the usual command line tools are taken from the system, and the self-extracting launcher needs `tar` to unpack itself. On Windows, see [below](#windows).

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
- An [HTTP client](#http-client): [curl](https://curl.se/), [GNU Wget](https://www.gnu.org/software/wget/) 1.15 or later, or [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
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

## HTTP client

Every request goes through the first of these the program finds:

1. `curl`, or Windows' own `curl.exe` from WSL
2. GNU Wget 1.15 or later, or GNU Wget2
3. PowerShell: `pwsh`, or Windows PowerShell's `powershell.exe` under Git Bash, MSYS2 or WSL

When there is none, the program stops before doing anything else, and says what is missing and how to install curl. Any of the three sends every request the program makes:

| Request | curl, GNU Wget | PowerShell |
| --- | --- | --- |
| Public IPv4 | `icanhazip.com`, `ifconfig.co` and `api.ipify.org`, forced over IPv4 | `ipv4.icanhazip.com` and `api.ipify.org` |
| Public IPv6, when no local interface has one | `icanhazip.com` and `ifconfig.co`, forced over IPv6 | `ipv6.icanhazip.com` |
| Cloudflare: read the zone's A and AAAA records (GET) | Yes | Yes |
| Cloudflare: batch update (POST with a JSON body) | Yes | Yes |
| Telegram and Discord notifications (POST) | Yes | Yes |

PowerShell has no way to pick IPv4 or IPv6 for a request, so it asks the host names of those services that only answer on one family, and skips `ifconfig.co`, which has none. Nothing in the program needs curl in particular.

### BusyBox wget

The `wget` of Alpine, BusyBox images and many routers is BusyBox's, and the program does not use it: it cannot force IPv4 or IPv6, it drops the body of an error response (where Cloudflare says what went wrong), and several of its builds do not check TLS certificates, which would hand your API token to anyone on the path. Install curl (`apk add curl` on Alpine) or GNU Wget (`apk add wget`) next to it.
