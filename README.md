# Cloudflare DNS Updater

A Bash-based script to automatically update Cloudflare DNS records with your dynamic public IP address. Designed for efficiency and compatibility across **Linux**, **macOS**, and **Windows**.

![Binaries Build](https://github.com/jmrplens/Cloudflare-DNS-Updater/actions/workflows/binaries.yml/badge.svg)
![Lint Check](https://github.com/jmrplens/Cloudflare-DNS-Updater/actions/workflows/lint.yml/badge.svg)

## Key Features

-   **Batch Updates**: Updates multiple DNS records in a single API call to minimize latency.
-   **IP Detection**:
    -   **Local**: Detects global IPv6 addresses directly from the network interface.
    -   **External**: Uses multiple fallback services (`icanhazip`, `ifconfig.co`, `ipify`) for redundancy.
-   **Cross-Platform**: Runs on Linux, macOS, and Windows (via bundled binaries or Bash).
-   **Notifications**: Support for Telegram and Discord alerts upon IP changes.
-   **Logging**: Rotation-aware logs with optional debug mode.
-   **Safety**: Lockfile mechanism to prevent concurrent executions.

---

## Installation

### Option A: Standalone Binaries
Pre-compiled binaries are available that bundle all necessary dependencies (Bash, Curl, JQ).

1.  **Download** the latest release for your OS from the [Releases Page](../../releases).
    *   **Linux**: `cf-updater-linux-x86_64` (Intel/AMD) or `cf-updater-linux-aarch64` (ARM/Raspberry Pi)
    *   **macOS**: `cf-updater-macos-x86_64` (Intel) or `cf-updater-macos-aarch64` (Apple Silicon)
    *   **Windows**: `cf-updater-windows-x86_64.exe`
2.  **Make Executable** (Linux/macOS only):
    ```bash
    chmod +x cf-updater-linux-x86_64
    ```

### Option B: Run from Source
If you prefer to run the script directly, ensure you have the required dependencies installed.

**Dependencies:**
*   [Bash](https://www.gnu.org/software/bash/) (4.0+)
*   [Curl](https://curl.se/)
*   [JQ](https://jqlang.github.io/jq/)

**Setup:**
1.  Clone the repository:
    ```bash
    git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
    cd Cloudflare-DNS-Updater
    ```
2.  Run the script:
    ```bash
    ./cloudflare-dns-updater.sh
    ```

---

## Configuration

Copy the example configuration file and edit it with your details.

```bash
cp config.example.yaml cloudflare-dns.yaml
```

**Example `cloudflare-dns.yaml`:**

```yaml
---
cloudflare:
  zone_id: "your_zone_id_here"
  api_token: "your_api_token_here"

options:
  proxied: true   # true for Orange Cloud (Proxy), false for DNS only
  ttl: 1          # 1 for Auto, or value in seconds (60-3600)
  interface: ""   # Optional: Force specific interface (e.g., "eth0")

domains:
  # Update both IPv4 and IPv6 (default)
  - name: "example.com"

  # Update only IPv4
  - name: "ipv4.example.com"
    ip_type: "ipv4"

  # Update only IPv6
  - name: "ipv6.example.com"
    ip_type: "ipv6"

  # Override global proxy setting
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

## Usage Examples

### CLI Options
*   `-s, --silent`: Run without console output (ideal for Cron).
*   `-d, --debug`: Enable verbose logging and API response output.
*   `-f, --force`: Force an update even if the IP has not changed.

### Linux / macOS Automation (Cron)
To run the updater every 5 minutes:

1.  Open crontab: `crontab -e`
2.  Add the line:
    ```bash
    */5 * * * * /path/to/cf-updater-linux-x86_64 --silent
    ```

### Windows Automation (Task Scheduler)
1.  Open **Task Scheduler** and "Create Basic Task".
2.  Name it "Cloudflare DNS Updater".
3.  Set Trigger to **Daily**, then in properties set "Repeat task every X minutes" (e.g., 5 or 10).
4.  Action: **Start a Program**.
5.  Program/script: Browse to `cf-updater-windows-x86_64.exe`.
6.  Add arguments: `--silent`.

---

## Development

For detailed instructions on building, testing, and understanding the project structure, please see [CONTRIBUTING.md](CONTRIBUTING.md).

Quick start for building binaries:

1.  **Validate Code**:
    ```bash
    ./tools/validate.sh
    ```
2.  **Build All Binaries**:
    ```bash
    ./tools/build-all.sh --all
    ```
    Artifacts will be created in the `dist/` directory.