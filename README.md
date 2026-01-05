# Cloudflare DNS Updater

A high-performance, **100% Bash** script to automatically update Cloudflare DNS records with your dynamic public IP address. Designed for maximum efficiency, robustness, and universal compatibility across **Linux**, **macOS**, and **Windows**.

![CI Build](https://github.com/jmrplens/Cloudflare-DNS-Updater/actions/workflows/binaries.yml/badge.svg)

## 🚀 Key Features

-   **⚡ Batch Updates**: Updates multiple DNS records in a **single API call**, minimizing latency.
-   **📡 Advanced IP Detection**:
    -   **Local Preference**: Detects global IPv6 addresses directly from your network interface.
    -   **Redundant Fallbacks**: Multi-service external detection (`icanhazip`, `ifconfig.co`, `ipify`).
-   **🛡️ Universal Compatibility**: Uses `curl`, `wget`, or **Windows PowerShell** depending on availability.
-   **📊 Enterprise-Grade Logging**: Rotation-aware logs with a `--debug` mode and credential masking.
-   **🔒 Secure by Design**: Lockfile mechanism and automated API confirmation.

---

## 📥 Installation & Usage

### Option A: Standalone Binaries (Recommended)
Our binaries are **Zero-Dependency** and include everything needed (Bash, Curl, JQ).

1.  **Download** the version for your OS from [Releases](../../releases):
    *   `cf-updater-linux-x86_64` (Intel/AMD) or `aarch64` (ARM/Raspberry Pi)
    *   `cf-updater-macos-x86_64` (Intel) or `aarch64` (Apple Silicon)
    *   `cf-updater-windows-x86_64.exe` (Windows 10/11)
2.  **Run**:
    ```bash
    chmod +x cf-updater-linux-x86_64
    ./cf-updater-linux-x86_64 [options] [config.yaml]
    ```

### Option B: Run from Source
1.  **Clone**: `git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git`
2.  **Execute**: `./cloudflare-dns-updater.sh`

---

## ⚙️ Configuration

Create `cloudflare-dns.yaml` in the tool's directory:

```yaml
---
cloudflare:
  zone_id: "your_zone_id"
  api_token: "your_api_token"

options:
  proxied: true    # Global default: Orange Cloud (true) or Grey Cloud (false)
  ttl: 1           # 1 for Auto, or 60-3600 seconds
  interface: ""    # Optional: Force a specific interface (e.g., "eth0")

domains:
  - name: "example.com"         # Updates both IPv4 & IPv6 by default
  - name: "ipv4.example.com"
    ip_type: "ipv4"             # Force IPv4 only
  - name: "direct.example.com"
    proxied: false              # Override global proxy setting
```

### Options Reference:
| Parameter | Description | Default |
| :--- | :--- | :--- |
| `ip_type` | `ipv4`, `ipv6`, or `both` | `both` |
| `proxied` | Enable Cloudflare Proxy (Orange Cloud) | `true` |
| `interface` | Local network interface for IP detection | Auto-detect |

---

## 🏃 CLI Options

-   `-h, --help`: Show help screen and version.
-   `-s, --silent`: No console output (perfect for Cron).
-   `-d, --debug`: Show API requests/responses and detailed checks.
-   `-f, --force`: Force update records even if IPs match.

---

## 🕒 Automation Guide

### Linux / macOS (Cron)
```bash
# Run every 5 minutes silently
*/5 * * * * /path/to/cf-updater-linux-x86_64 --silent
```

### Windows (Task Scheduler)
1.  **Create Basic Task** -> Name it "Cloudflare DNS".
2.  **Trigger**: Daily -> Repeat every 10 minutes.
3.  **Action**: Start a Program -> Browse to `cf-updater-windows-x86_64.exe`.
4.  **Arguments**: `--silent`.

---

## 🛠️ Developer Guide

Want to contribute? Here is how to test and build the project locally.

### 1. Prerequisites
-   `bash`, `curl`, `jq`
-   `shellcheck`, `shfmt` (for validation)
-   `gcc` (for building standalone binaries)
-   `makeself` (for Linux .run bundles)

### 2. Validation
Before committing, run the validation suite to ensure code quality:
```bash
./tools/validate.sh
```

### 3. Local Testing
You can test changes without building binaries:
```bash
./cloudflare-dns-updater.sh --debug
```

### 4. Building
*   **Generate Monolith**: Merges all `src/` files into one.
    ```bash
    ./tools/bundle.sh
    ```
*   **Build Standalone Bundles**: Generates the C-wrapped binaries in `dist/`.
    ```bash
    ./tools/build-all.sh --linux-amd64
    ```

---

Built with ❤️ by [jmrplens](https://github.com/jmrplens).
