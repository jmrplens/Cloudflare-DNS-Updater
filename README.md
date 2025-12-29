# Cloudflare DNS Updater (Bash Refactor)

A high-performance, **100% Bash** script to update Cloudflare DNS records with your public IP. Refactored for efficiency, robustness, and ease of use.

## 🚀 Features

-   **⚡ Batch Updates**: Updates multiple DNS records in a **single API call** using Cloudflare's Batch API.
-   **🛡️ Robust Design**:
    -   **Zero Dependencies**: No Python/Node.js required. Uses standard tools (`curl`, `awk`, `sed`, `jq`).
    -   **IP Fallback**: Automatically tries `curl` then `wget` to detect public IP.
    -   **Redundancy**: Checks multiple IP services (`icanhazip`, `ifconfig.co`, `ipify`).
    -   **Lockfile Protection**: Prevents multiple instances from running simultaneously.
-   **📊 Observability**:
    -   **Logging**: Automatic logging to `logs/updater.log` with **auto-rotation** (1MB limit).
    -   **Notifications**: Real-time alerts via **Telegram** and **Discord**.
-   **📦 Cross-Platform Binaries**: Pre-compiled standalone binaries for **Linux**, **macOS**, and **Windows**.

---

## 📥 Installation

You can run this tool using a pre-compiled binary (easiest) or directly from source.

### Option A: Uses Binaries (Recommended)

No installation required. Just download and run.

1.  **Download** the latest release for your OS from the **[GitHub Releases Page](../../releases)**.
    *   🐧 **Linux**: `cf-updater-linux`
    *   🍎 **macOS**: `cf-updater-mac`
    *   🪟 **Windows**: `cf-updater.exe`

2.  **Configuration**:
    Create a file named `cloudflare-dns.yaml` in the same folder as the binary. (See [Configuration](#-configuration) below).

3.  **Run**:
    *   **Linux/Mac**:
        ```bash
        chmod +x cf-updater-linux
        ./cf-updater-linux
        ```
    *   **Windows (CMD/PowerShell)**:
        ```powershell
        .\cf-updater.exe
        ```

### Option B: Run from Source (Clone/Zip)

If you prefer to run the raw Bash scripts.

1.  **Get the Code**:
    *   **Clone**: `git clone https://github.com/your/repo.git`
    *   **Zip**: Download "Source Code (zip)" from Releases and extract.

2.  **Configuration**:
    Copy `config.example.yaml` to `cloudflare-dns.yaml` and edit it.

3.  **Run**:
    ```bash
    ./cloudflare-dns-updater.sh
    ```
    *(Note: Ensure you have `bash`, `curl` (or `wget`), and `jq` installed).*

---

## ⚙️ Configuration

Create `cloudflare-dns.yaml` in the script directory.

```yaml
cloudflare:
  zone_id: "your_zone_id_here"
  api_token: "your_api_token_here"

options:
  proxied: true    # Default proxy state (orange cloud)
  ttl: 1           # 1 = Auto

# List of domains to update
domains:
  - name: "example.com"      # Updates both IPv4 (A) and IPv6 (AAAA) if detected

  - name: "sub.example.com"
    proxied: false           # Disable Cloudflare Proxy (Grey Cloud)

  - name: "ipv4.example.com"
    ip_type: "ipv4"          # Force IPv4 only (A record)

  - name: "ipv6.example.com"
    ip_type: "ipv6"          # Force IPv6 only (AAAA record)


notifications:
  telegram:
    enabled: true
    bot_token: "YOUR_BOT_TOKEN"
    chat_id: "YOUR_CHAT_ID"
  
  discord:
    enabled: true
    webhook_url: "YOUR_WEBHOOK_URL"
```

---

## 🤖 CI/CD & Binaries

This project uses **GitHub Actions** to automatically build and release binaries.

### How it works
1.  **Bundler**: The `tools/bundle.sh` script merges all source files (`src/*.sh`) into a single monolithic script (`dist/monolith.sh`).
2.  **Compilation**:
    *   **Linux/Mac**: Uses [`shc`](https://github.com/neurobin/shc) to compile the shell script into an executable binary.
    *   **Windows**: Uses `shc` to generate C source code, then cross-compiles it to `.exe` using `MinGW-w64`.
3.  **Releases**: On every Git Tag (e.g., `v1.0.0`), a Release is created with these artifacts attached.

### Workflows
-   `.github/workflows/binaries.yml`: The logic for building and releasing.

---

## 📂 Project Structure

```text
.
├── cloudflare-dns-updater.sh    # Entry point (handles locking & paths)
├── cloudflare-dns.yaml          # Your config (ignored by git)
├── logs/                        # Log files directory
│   └── updater.log              # Rotated log
├── src/
│   ├── main.sh                  # Main logic controller
│   ├── config.sh                # Pure Bash YAML parser
│   ├── cloudflare.sh            # API interactions (Bulk Read/Batch Write)
│   ├── ip.sh                    # IP detection (Redundant providers)
│   ├── logger.sh                # Logging system
│   └── notifications.sh         # Alerting system
└── tools/
    └── bundle.sh                # Script bundler for CI
```
