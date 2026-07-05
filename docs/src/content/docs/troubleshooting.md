---
title: Troubleshooting
description: Diagnose common Cloudflare DNS Updater problems.
---

Run with `--debug` first — it prints IP detection, every API request (secrets redacted) and the per-record decision. When running from source, the same information also lands in `logs/updater.log` in the project directory.

## "Script is already running"

Another instance holds the lock (`/tmp/cloudflare-dns-updater.lock`). Normal under cron if a previous run is still active. If no process is actually running, the lock uses `flock` and is released by the kernel automatically — simply re-run; with the PID-file fallback a stale lock is detected and overwritten.

## "Could not detect Public IPv4/IPv6"

- IPv4 is detected via external services (`icanhazip.com`, `ifconfig.co`, `api.ipify.org`) — check outbound HTTPS connectivity.
- IPv6 is first read from a local interface. If your interface has no global IPv6, external detection is tried next. Set `options.interface` explicitly if the auto-detected interface is wrong.
- No IPv6 at all? Set `ip_type: "ipv4"` on your domains so AAAA lookups are skipped.

## "Record ... not found. Creation not implemented."

The program only **updates** existing records. Create the A/AAAA record once in the Cloudflare dashboard (any IP, it will be corrected on the next run) and re-run.

## "Failed to fetch records" / "Batch update failed"

- Check the token has **Edit zone DNS** permission for the configured zone and hasn't expired.
- Check `zone_id` matches the zone that holds your records.
- Re-run with `--debug` to see the API error body (redacted).

## Records update but websites break

If a record is proxied (orange cloud), Cloudflare terminates traffic and the TTL setting is ignored — that is normal. For direct connections (SSH, game servers, mail), set `proxied: false` on that domain.

## Warning about config file permissions

`cloudflare-dns.yaml` holds your API token. Silence the warning with:

```bash
chmod 600 cloudflare-dns.yaml
```

## jq warning

Without `jq` a limited sed-based JSON parser is used. It works, but installing `jq` is faster and more robust — it's a single package everywhere (`apt install jq`, `brew install jq`).
