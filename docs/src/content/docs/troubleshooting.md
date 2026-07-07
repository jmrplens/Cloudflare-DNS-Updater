---
title: Troubleshooting
description: Diagnose common Cloudflare DNS Updater problems.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/troubleshooting/#faq","inLanguage":"en","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"Why does it say the script is already running?","acceptedAnswer":{"@type":"Answer","text":"Another instance holds the lock (/tmp/cloudflare-dns-updater.lock). This is normal under cron if a previous run is still active. Re-run; with flock the kernel releases the lock automatically, and a stale PID-file lock is detected and overwritten."}},{"@type":"Question","name":"Why can it not detect my public IPv4 or IPv6?","acceptedAnswer":{"@type":"Answer","text":"IPv4 is detected via external services (icanhazip.com, ifconfig.co, api.ipify.org), so check outbound HTTPS connectivity. IPv6 is read from a local interface first and then external services. If you have no IPv6, set ip_type: ipv4 on your domains so AAAA lookups are skipped."}},{"@type":"Question","name":"Why does it report that the record was not found?","acceptedAnswer":{"@type":"Answer","text":"The program only updates existing records. Create the A or AAAA record once in the Cloudflare dashboard (any IP — it is corrected on the next run) and re-run."}},{"@type":"Question","name":"Records update but my websites break — why?","acceptedAnswer":{"@type":"Answer","text":"If a record is proxied (orange cloud), Cloudflare terminates traffic and the TTL is ignored — that is normal. For direct connections such as SSH, game servers or mail, set proxied: false on that domain."}},{"@type":"Question","name":"How do I fix failed to fetch records or batch update failed?","acceptedAnswer":{"@type":"Answer","text":"Check the token has Edit zone DNS permission for the configured zone and has not expired, confirm zone_id matches the zone that holds your records, and re-run with --debug to see the redacted API error body."}}]}
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
