---
title: Command Line
description: Command-line options for Cloudflare DNS Updater.
---

```bash
./cloudflare-dns-updater.sh [options]
cf-updater [options] [config_file.yaml]
```

The source launcher (`cloudflare-dns-updater.sh`) always uses the `cloudflare-dns.yaml` next to itself. Standalone binaries and the bundled monolith also accept a config file path as a positional argument and fall back to `cloudflare-dns.yaml` in the current directory.

## Options

| Option | Description |
| --- | --- |
| `-h`, `--help` | Show usage help and exit. |
| `-s`, `--silent` | No console output except errors. Recommended for cron. |
| `-d`, `--debug` | Verbose output: IP detection, API requests/responses (secrets redacted) and per-record decisions. |
| `-f`, `--force` | Push updates even when the record already matches the current IP. |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success — records updated or already up to date. |
| `1` | Error: another instance is running, missing dependency (`curl`), missing/invalid config, no IP detected, or the Cloudflare API request failed. |

## Concurrency

Only one instance runs at a time: the program takes an exclusive lock (`flock` when available, with a PID-file fallback) on `/tmp/cloudflare-dns-updater.lock`. A second invocation exits immediately with a message — which makes aggressive cron schedules safe.

## Logs

When running from source, runs are logged to `logs/updater.log` in the project directory (plain text, no colors), rotating automatically at 1 MB to `updater.log.old`. Standalone binaries execute from a temporary directory, so their file log does not persist in a fixed location — rely on console output (or `--debug`) instead.
