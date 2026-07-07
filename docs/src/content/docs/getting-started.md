---
title: Getting Started
description: Set up Cloudflare DNS Updater in five minutes.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/getting-started/#faq","inLanguage":"en","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"Does Cloudflare DNS Updater create DNS records?","acceptedAnswer":{"@type":"Answer","text":"No. It only updates records that already exist. Create the A or AAAA record once in the Cloudflare dashboard (any IP — it is corrected on the next run), then run the program."}},{"@type":"Question","name":"Does it support IPv6?","acceptedAnswer":{"@type":"Answer","text":"Yes. It keeps AAAA records updated, preferring the stable global IPv6 address on your local interface and falling back to external services."}},{"@type":"Question","name":"Do I need jq to run it?","acceptedAnswer":{"@type":"Answer","text":"No, but it is recommended. Standalone binaries bundle jq; from source, a slower sed-based JSON parser is used when jq is absent."}},{"@type":"Question","name":"Which Cloudflare API token permission does it need?","acceptedAnswer":{"@type":"Answer","text":"An API token scoped to Edit zone DNS for your zone. A Global API Key is not required and is discouraged."}},{"@type":"Question","name":"How often should it run?","acceptedAnswer":{"@type":"Answer","text":"Every 5 minutes is a comfortable default for home connections. A lockfile makes overlapping runs safe, so shorter intervals also work."}},{"@type":"Question","name":"Is it free and open source?","acceptedAnswer":{"@type":"Answer","text":"Yes. It is released under the MIT license."}}]}
---

Cloudflare DNS Updater keeps the A (IPv4) and AAAA (IPv6) records of your Cloudflare zone pointed at your current public IP. It is a plain Bash program: run it from source or grab a standalone binary, point it at a YAML config, and schedule it with cron or any task scheduler.

## 1. Get the program

Either download a [standalone binary](../installation/#standalone-binaries) or clone the repository:

```bash
git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
cd Cloudflare-DNS-Updater
```

## 2. Create a Cloudflare API token

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/profile/api-tokens), create a token with the [**Edit zone DNS**](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) template.
2. Scope it to the zone you want to update.
3. Copy the token — you will not see it again.

You also need the **Zone ID**, shown on the zone's *Overview* page in the dashboard.

## 3. Configure

```bash
cp config.example.yaml cloudflare-dns.yaml
chmod 600 cloudflare-dns.yaml   # it contains your API token
```

Minimal configuration:

```yaml
cloudflare:
  zone_id: "your_zone_id"
  api_token: "your_api_token"

domains:
  - name: "example.com"
  - name: "www.example.com"
```

See the [configuration reference](../configuration/) for every option.

## 4. Run it

```bash
# From source
./cloudflare-dns-updater.sh --debug

# Or with a standalone binary
./cf-updater-linux-x86_64 --debug /path/to/cloudflare-dns.yaml
```

With `--debug` you see every step: IP detection, the API calls and the per-record decision. When everything looks right, [schedule it](../automation/) and add `--silent` for quiet operation.

## Frequently asked questions

### Does Cloudflare DNS Updater create DNS records?

No. It only updates records that already exist. Create the A or AAAA record once in the Cloudflare dashboard (any IP — it is corrected on the next run), then run the program.

### Does it support IPv6?

Yes. It keeps AAAA records updated, preferring the stable global IPv6 address on your local interface and falling back to external services.

### Do I need jq to run it?

No, but it is recommended. Standalone binaries bundle jq; from source, a slower sed-based JSON parser is used when jq is absent.

### Which Cloudflare API token permission does it need?

An API token scoped to **Edit zone DNS** for your zone. A Global API Key is not required and is discouraged.

### How often should it run?

Every 5 minutes is a comfortable default for home connections. A lockfile makes overlapping runs safe, so shorter intervals also work.

### Is it free and open source?

Yes. It is released under the [MIT license](https://github.com/jmrplens/Cloudflare-DNS-Updater/blob/main/LICENSE).
