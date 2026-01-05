# Cloudflare DNS Updater

A high-performance, **100% Bash** script to automatically update Cloudflare DNS records with your dynamic public IP address. Designed for maximum efficiency, robustness, and universal compatibility across **Linux**, **macOS**, and **Windows**.

![CI Build](https://github.com/jmrplens/Cloudflare-DNS-Updater/actions/workflows/binaries.yml/badge.svg)

## 🚀 Key Features

-   **⚡ Batch Updates**: Updates multiple DNS records in a **single API call** using Cloudflare's Batch API, minimizing latency and API overhead.
-   **📡 Advanced IP Detection**:
    -   **Local Preference**: Intelligently detects global IPv6 addresses directly from your network interface (ideal for avoiding gateway/NAT masking).
    -   **Redundant Fallbacks**: Multi-service external detection (`icanhazip`, `ifconfig.co`, `ipify`) if local detection is unavailable.
-   **🛡️ Universal Compatibility**:
    -   **Multi-Client Support**: Uses `curl`, `wget`, or **Windows PowerShell** (`Invoke-RestMethod`) depending on what's available.
    -   **Zero Heavy Dependencies**: No Python, Node.js, or complex runtimes required.
-   **📊 Enterprise-Grade Logging**:
    -   **Detailed Observability**: Rotation-aware logs with a `--debug` mode that redacts sensitive API tokens automatically.
    -   **Instant Notifications**: Native support for **Telegram** and **Discord** alerts.
-   **🔒 Secure by Design**:
    -   **Lockfile Mechanism**: Prevents race conditions and duplicate executions.
    -   **Credential Masking**: Debug logs never leak your API tokens.

---

## 📥 Installation

### Option A: Use Compiled Binaries (Recommended)

1.  **Download** the latest version for your platform from the **[GitHub Releases Page](../../releases)**.
2.  **Deploy**: Place the binary in a permanent location (e.g., `/usr/local/bin/` or `/opt/cf-updater/`).
3.  **Configure**: Create your `cloudflare-dns.yaml` (see [Configuration](#-configuration)).

### Option B: Run from Source

1.  **Clone**:
    ```bash
    git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
    cd Cloudflare-DNS-Updater
    ```
2.  **Execute**: Use `./cloudflare-dns-updater.sh`.

---

## 🛠️ Requirements

The script is designed to run on minimal environments. It requires at least **one** of the following:
-   `curl` (Preferred)
-   `wget`
-   `PowerShell` (Windows native)

**Optional but Recommended:**
-   `jq`: For faster and more robust JSON processing. If missing, the script uses an internal `sed`-based parser.

---

## ⚙️ Configuration

Create a `cloudflare-dns.yaml` file. Use the template below:

```yaml
cloudflare:
  zone_id: "your_zone_id"
  api_token: "your_api_token" # Requires DNS:Edit permissions

options:
  proxied: true    # Default for all: Orange Cloud (true) or Grey Cloud (false)
  ttl: 1           # 1 for Auto, or 60-3600 for specific seconds
  interface: ""    # Optional: Force a specific network interface (e.g., "eth0")

domains:
  # 1. Automatic: Updates both IPv4 (A) and IPv6 (AAAA)
  - name: "example.com"

  # 2. IPv4 Only
  - name: "ipv4.example.com"
    ip_type: "ipv4"

  # 3. Custom Proxy setting
  - name: "direct.example.com"
    proxied: false

notifications:
  telegram:
    enabled: false
    bot_token: ""
    chat_id: ""
  discord:
    enabled: false
    webhook_url: ""
```

---

## 🏃 Usage & Options

### Basic Run
```bash
./cloudflare-dns-updater.sh
```

### CLI Arguments
-   `-s, --silent`: No console output (perfect for Cron).
-   `-d, --debug`: Show API payloads, full responses, and redaction logic.
-   `-f, --force`: Force update Cloudflare even if IPs already match.

### Windows (PowerShell)
```powershell
.\cf-updater.exe --debug
```

---

## 🕒 Automation

### Linux / macOS (Cron)
```bash
# Run every 5 minutes silently
*/5 * * * * /opt/cf-updater/cloudflare-dns-updater.sh --silent
```

### Windows (Task Scheduler)
1.  Create a **Basic Task**.
2.  Trigger: **Daily** -> Repeat every **10 minutes**.
3.  Action: **Start a Program** -> Path to `cf-updater.exe`.
4.  Arguments: `--silent`.

---

## 🏗️ Technical Architecture

This project follows a modular Bash architecture:
-   `network.sh`: Abstracted HTTP layer (Curl/Wget/PS).
-   `ip.sh`: Advanced IP resolution engine.
-   `cloudflare.sh`: Cloudflare API bindings and diff engine.
-   `logger.sh`: Unified logging and Boolean state management.
-   `config.sh`: YAML parsing logic.

Built with ❤️ by [jmrplens](https://github.com/jmrplens).