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
# --all builds the Linux targets (x86_64 + aarch64)
./tools/build-all.sh --all

# Other platforms are built by naming them explicitly
./tools/build-all.sh macos aarch64
./tools/build-all.sh windows x86_64
```

Requires GCC (or MinGW for Windows targets). Artifacts land in `dist/`.

## Cutting a release

Releases are driven by the `VERSION` file at the repository root:

1. Bump the version in **both** the `VERSION` file and the `VERSION` constant in `src/main.sh` (a unit test fails if they differ).
2. Merge to `main`.

The **Build & Release Binaries** workflow (triggered only by changes to `VERSION`) builds all five platform binaries, creates the `vX.Y.Z` tag and publishes the GitHub release with auto-generated notes. Running the workflow manually (`workflow_dispatch`) builds the binaries without publishing anything.
