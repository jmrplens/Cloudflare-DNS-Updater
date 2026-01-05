# Cloudflare DNS Updater

A high-performance, **100% Bash** script to automatically update Cloudflare DNS records with your dynamic public IP address. Designed for efficiency, robustness, and ease of use across all major platforms.

![CI Build](https://github.com/jmrplens/Cloudflare-DNS-Updater/actions/workflows/binaries.yml/badge.svg)

## 🚀 Features

-   **⚡ Batch Updates**: Efficiently updates multiple records in a **single API call** using Cloudflare's Batch API.
-   **🛡️ Robustness**:
    -   **Zero Dependencies**: No Python or Node.js required. Runs on standard tools (`curl` or `wget`, `jq`).
    -   **Redundant IP Detection**: Checks multiple services (`icanhazip`, `ifconfig.co`, `ipify`) and falls back to `wget` if `curl` is missing.
    -   **Lockfile Protection**: Prevents multiple instances from running simultaneously.
-   **📊 Observability**:
    -   **Logging**: Detailed logs saved to `logs/updater.log` with auto-rotation (1MB max).
    -   **Notifications**: Instant alerts via **Telegram** and **Discord**.
-   **📦 Cross-Platform**: Runs natively on **Linux**, **macOS**, and **Windows**.

---

## 📥 Installation

You can run this tool using pre-compiled binaries (recommended) or directly from the source code.

### Option A: Uses Binaries (Recommended)

1.  **Download** the latest release for your OS from the **[GitHub Releases Page](../../releases)**.
    *   🐧 **Linux**: `cf-updater-linux`
    *   🍎 **macOS**: `cf-updater-mac`
    *   🪟 **Windows**: `cf-updater.exe`

2.  **Prepare**:
    Place the binary in a permanent folder (e.g., `/opt/cf-updater/` or `C:\Program Files\CF-Updater\`).

3.  **Config**:
    Create a `cloudflare-dns.yaml` file in the same directory (see [Configuration](#-configuration)).

### Option B: Run from Source

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
    cd Cloudflare-DNS-Updater
    ```

---

## 🛠️ Requirements (Binaries & Source)

Both the **Binaries** and **Source Code** require the following system tools installed:

1.  **curl**: Required for API communication.
    *   *Most systems have this pre-installed.*
2.  **jq** (Recommended): For robust JSON parsing.
    *   *The script has a fallback parser, but `jq` is faster and safer.*

**Installation Commands:**
*   **Debian/Ubuntu**: `sudo apt install curl jq`
*   **RHEL/CentOS**: `sudo yum install curl jq`
*   **macOS**: `brew install jq` (curl is built-in)
*   **Windows**:
    *   **Chocolatey**: `choco install jq curl`
    *   **Winget**: `winget install jqlang.jq` (curl is built-in on Windows 10/11)

---

## ⚙️ Configuration

Copy `config.example.yaml` to `cloudflare-dns.yaml` and edit it with your details.

### Example Configuration

```yaml
cloudflare:
  zone_id: "your_zone_id_here"      # Found in Cloudflare Dashboard -> Overview
  api_token: "your_api_token_here"  # Create at My Profile -> API Tokens (Template: Edit Zone DNS)

options:
  proxied: true    # Default: Proxy traffic through Cloudflare (Orange Cloud)
  ttl: 1           # Default: 1 (Auto)
  interface: ""    # Optional: Network interface to use (e.g., "eth0"). Auto-detected if empty.

domains:
  # 1. Update both IPv4 (A) and IPv6 (AAAA) automatically
  - name: "example.com"

  # 2. Update IPv4 ONLY (A Record)
  - name: "ipv4.example.com"
    ip_type: "ipv4"

  # 3. Update IPv6 ONLY (AAAA Record)
  - name: "ipv6.example.com"
    ip_type: "ipv6"

  # 4. DNS Only (Grey Cloud - No Proxy)
  - name: "direct.example.com"
    proxied: false

notifications:
  telegram:
    enabled: true
    bot_token: "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
    chat_id: "123456789"
```

---

## 🏃 Usage Guide

### Basic Execution
Run the script manually to test it.

**Linux / macOS:**
```bash
./cloudflare-dns-updater.sh
```

**Options:**
-   `--silent` (`-s`): Suppress console output (useful for Cron). Errors are still printed.
-   `--debug` (`-d`): Enable verbose logging (API requests, detailed IP checks, verification).
-   `--force` (`-f`): Force update records even if they already match the current IP.

**Windows (PowerShell / CMD):**
```powershell
.\cf-updater.exe
```

### Custom Config File
You can specify a different configuration file path as an argument.

```bash
./cf-updater-linux /path/to/my-custom-config.yaml
```

---

## 🕒 Automation (Cron / Task Scheduler)

To keep your DNS up-to-date, schedule the script to run automatically.

### Linux / macOS (Cron)
Run every 5 minutes.

1.  Open crontab:
    ```bash
    crontab -e
    ```
2.  Add the line:
    ```bash
    */5 * * * * /opt/cf-updater/cloudflare-dns-updater.sh --silent
    ```

### Windows (Task Scheduler)
Run every 10 minutes.

1.  Open **Task Scheduler**.
2.  Select **Create Basic Task** -> Name: "Cloudflare Update".
3.  Trigger: **Daily** -> Repeat task every **10 minutes**.
4.  Action: **Start a Program**.
    *   Program/script: `C:\Path\To\cf-updater.exe`
    *   Start in (Optional): `C:\Path\To\` (directory containing config file).
5.  Finish.

---

## 🏗️ CI/CD & Security

### Automated Builds
We use **GitHub Actions** to guarantee safe, reproducible builds.
-   **Source**: The `tools/bundle.sh` script compiles all source modules into a temporary bundle.
-   **Compiler**: Uses `shc` to convert the Bash scripts into standalone binaries for Linux, Mac, and Windows (Cross-compiled).
-   **Versioning**: Every release tag (e.g., `v1.0.0`) triggers a build and upload of authenticated assets.


