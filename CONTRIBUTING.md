# Contributing to Cloudflare DNS Updater

Thank you for your interest in contributing! This document provides technical details on how to develop, test, and build the project.

## 📂 Project Structure

*   `src/`: Source files for the script.
    *   `main.sh`: Entry point and logic coordinator.
    *   `cloudflare.sh`: API interaction logic.
    *   `ip.sh`: IP detection logic (local and external).
    *   `config.sh`: Configuration parsing.
    *   `logger.sh`: Logging utilities.
*   `tools/`: Build and validation scripts.
    *   `build-all.sh`: Main build orchestrator for all platforms.
    *   `bundle.sh`: Combines `src/` files into a single script.
    *   `launcher.c`: C wrapper for creating standalone binaries.
*   `cloudflare-dns-updater.sh`: A dev-friendly wrapper to run the code from source without building.

## 🛠️ Development Environment

To fully work on this project, you will need the following tools:

### Core Dependencies
*   `bash` (4.0+)
*   `curl`
*   `jq`

### Dev Tools (for Building & Validating)
*   **ShellCheck**: For static analysis of Bash scripts.
*   **shfmt**: For code formatting.
*   **yamllint**: For validating `config.yaml` and GitHub workflows.
*   **actionlint**: For validating GitHub Actions workflows.
*   **GCC / MinGW**: For compiling the C launcher (required for `build-all.sh`).

## ✅ Validation

Before submitting a Pull Request, please ensure the code passes all checks. We use a unified validation script:

```bash
./tools/validate.sh
```

This script performs:
1.  **Static Analysis**: Runs `shellcheck` on all `.sh` files.
2.  **Syntax Check**: Runs `bash -n` to catch syntax errors.
3.  **Formatting**: Checks style compliance using `shfmt`.
4.  **Linting**: Checks YAML files and GitHub Actions workflows.

## 🏗️ Build System

This project uses a custom build system to generate "standalone" binaries that run on systems without pre-installed dependencies.

### 1. Monolith Generation
The project is split into multiple files in `src/`. To distribute it as a single script, we "bundle" it:

```bash
./tools/bundle.sh
```
This creates `dist/cloudflare-dns-updater-monolith.sh`.

### 2. Standalone Binaries
To create the dependency-free binaries (like `cf-updater-linux-x86_64`), we use `tools/build-all.sh`.

**How it works:**
1.  Downloads static versions of `bash`, `curl`, `jq`, and `busybox` for the target architecture.
2.  Bundles them into a directory structure along with the script.
3.  Compiles `tools/launcher.c`. This C program acts as a self-extracting runner: it extracts the tools to a temp dir and executes the script.
4.  Appends a `.tar.gz` payload of the tools+script to the compiled C binary.

**To build for all platforms:**
```bash
./tools/build-all.sh --all
```

**To build for a specific platform:**
```bash
./tools/build-all.sh linux x86_64
./tools/build-all.sh windows x86_64
```

## 🧪 Testing

### Unit Tests

Unit tests are written with [bashunit](https://bashunit.com) and live in `tests/` (one file per `src/` module, fixtures under `tests/fixtures/`).

```bash
# One-time setup: installs a pinned bashunit release into lib/ (gitignored)
./tools/install-bashunit.sh

# Run the whole suite
./lib/bashunit --parallel tests/

# Run a single file or filter by test name
./lib/bashunit tests/config_test.sh
./lib/bashunit tests/ --filter "cache_lookup"
```

Tests are plain Bash functions named `test_*`. External commands and functions (e.g. `curl`, `http_request`) are replaced with `bashunit::mock`/`bashunit::spy` — tests never hit the network. `./tools/validate.sh` also runs the suite when bashunit is installed, and CI runs it on every push/PR via `.github/workflows/test.yml`.

### Manual Testing

You can run the script directly from the source during development:

```bash
./cloudflare-dns-updater.sh --debug --config config.dev.yaml
```

*   `--debug`: Enables verbose output (showing API calls).
*   `--force`: Forces an update even if IP hasn't changed (useful for testing API logic).
