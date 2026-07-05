---
title: Building Binaries
description: Bundle the script and build standalone binaries.
---

## Project layout

```text
src/            program modules
├── main.sh          entry point and orchestration
├── cloudflare.sh    Cloudflare API interaction
├── config.sh        YAML config parsing
├── ip.sh            IP detection (local interface + external services)
├── network.sh       curl/wget/PowerShell HTTP wrapper
├── logger.sh        console + file logging, secret redaction
└── notifications.sh Telegram / Discord

tools/          build & QA tooling
tests/          bashunit unit tests
cloudflare-dns-updater.sh   dev launcher (runs from source)
```

## Monolith

All `src/` modules merged into one self-contained script:

```bash
./tools/bundle.sh
# → dist/cloudflare-dns-updater-monolith.sh
```

## Standalone binaries

`tools/build-all.sh` produces dependency-free binaries: it downloads static builds of bash, curl, jq and busybox for the target architecture, bundles them with the monolith, and compiles `tools/launcher.c` as a self-extracting runner.

```bash
# Everything
./tools/build-all.sh --all

# One platform
./tools/build-all.sh linux x86_64
./tools/build-all.sh windows x86_64
```

Requires GCC (or MinGW for Windows targets). Artifacts land in `dist/`.

## Release binaries in CI

The **Binaries Build** workflow builds all platforms on every release. See `.github/workflows/binaries.yml`.
