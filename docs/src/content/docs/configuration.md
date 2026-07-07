---
title: Configuration
description: Complete reference for cloudflare-dns.yaml.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/configuration/","inLanguage":"en","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"What TTL should I use?","acceptedAnswer":{"@type":"Answer","text":"Leave ttl: 1 (Auto) for proxied records — Cloudflare ignores the TTL while a record is proxied. For DNS-only records, set a value in seconds (60–86400); a lower TTL propagates IP changes faster."}},{"@type":"Question","name":"What does proxied do?","acceptedAnswer":{"@type":"Answer","text":"proxied: true routes traffic through Cloudflare's proxy (orange cloud); proxied: false is DNS-only (grey cloud), which you want for direct connections such as SSH, game servers or mail."}},{"@type":"Question","name":"Can I update a wildcard record?","acceptedAnswer":{"@type":"Answer","text":"Yes. Use name: \"*.example.com\". Like any record, the wildcard must already exist in Cloudflare — the program updates records, it does not create them."}},{"@type":"Question","name":"Can I manage only IPv4 or only IPv6?","acceptedAnswer":{"@type":"Answer","text":"Yes. Each domain manages both A and AAAA by default; set ip_type: ipv4 or ip_type: ipv6 on a domain to limit it."}},{"@type":"Question","name":"Where does the config file need to be?","acceptedAnswer":{"@type":"Answer","text":"cloudflare-dns.yaml next to the launcher by default. Pass a path as an argument to use another location."}}]}
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
| `api_token` | yes | An API token with [**Edit zone DNS**](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) permission for that zone. |

:::caution[Protect your credentials]
`cloudflare-dns.yaml` holds your API token. Restrict it to your user with `chmod 600 cloudflare-dns.yaml`, and scope the token to **Edit zone DNS** for a single zone rather than using a Global API Key — so a leaked file can only touch that one zone's DNS. The program warns on startup if the file is world-readable.
:::

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

## Frequently asked questions

### What TTL should I use?

Leave `ttl: 1` (Auto) for proxied records — Cloudflare ignores the TTL while a record is proxied. For DNS-only records, set a value in seconds (60–86400); a lower TTL propagates IP changes faster.

### What does `proxied` do?

`proxied: true` routes traffic through Cloudflare's proxy (orange cloud); `proxied: false` is DNS-only (grey cloud), which you want for direct connections such as SSH, game servers or mail.

### Can I update a wildcard record?

Yes. Use `name: "*.example.com"`. Like any record, the wildcard must already exist in Cloudflare — the program updates records, it does not create them.

### Can I manage only IPv4 or only IPv6?

Yes. Each domain manages both A and AAAA by default; set `ip_type: ipv4` or `ip_type: ipv6` on a domain to limit it.

### Where does the config file need to be?

`cloudflare-dns.yaml` next to the launcher by default. Pass a path as an argument to use another location.
