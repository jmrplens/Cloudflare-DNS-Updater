---
title: Configuration
description: Complete reference for cloudflare-dns.yaml.
---

The program reads a YAML file — `cloudflare-dns.yaml` by default — with four sections: `cloudflare`, `options`, `domains` and `notifications`.

## Full example

```yaml
cloudflare:
  zone_id: "your_zone_id"
  api_token: "your_api_token"

options:
  proxied: true   # default for all domains: true = Cloudflare proxy (orange cloud)
  ttl: 1          # default TTL: 1 = Auto, or seconds (60-86400)
  interface: ""   # optional: network interface for local IPv6 detection (e.g. "eth0")

domains:
  # Updates both A and AAAA records (default)
  - name: "example.com"

  # Only IPv4 (A record)
  - name: "ipv4.example.com"
    ip_type: "ipv4"

  # Only IPv6 (AAAA record)
  - name: "ipv6.example.com"
    ip_type: "ipv6"

  # Per-domain overrides
  - name: "direct.example.com"
    proxied: false
    ttl: 300

notifications:
  telegram:
    enabled: false
    bot_token: ""
    chat_id: ""

  discord:
    enabled: false
    webhook_url: ""
```

## `cloudflare`

| Key | Required | Description |
| --- | --- | --- |
| `zone_id` | yes | The Zone ID shown on your zone's *Overview* page. |
| `api_token` | yes | An API token with **Edit zone DNS** permission for that zone. |

## `options`

Global defaults inherited by every domain.

| Key | Default | Description |
| --- | --- | --- |
| `proxied` | `true` | `true` routes traffic through Cloudflare (orange cloud); `false` is DNS-only (grey cloud). |
| `ttl` | `1` | Record TTL in seconds. `1` means *Auto*. Ignored by Cloudflare while a record is proxied. |
| `interface` | auto-detect | Network interface used for local IPv6 detection. When empty, the default-route interface is used. |

## `domains`

A list of records to keep updated. Each entry accepts:

| Key | Default | Description |
| --- | --- | --- |
| `name` | — | Record name (e.g. `home.example.com`, `example.com` or a wildcard `*.example.com`). The record must already exist in Cloudflare; the program updates records, it does not create them. |
| `ip_type` | `both` | Which records to manage: `ipv4` (A only), `ipv6` (AAAA only) or `both`. |
| `proxied` | from `options` | Per-domain override of the proxy setting. |
| `ttl` | from `options` | Per-domain TTL override. |

Values may be quoted or unquoted; inline comments after a value are ignored. Files with Windows (CRLF) line endings are handled.

## `notifications`

See [Notifications](../notifications/) for setup guides.

:::note[Zones with many records]
Records are fetched 5000 per API call and pagination is followed automatically, so zones of any size work.
:::
