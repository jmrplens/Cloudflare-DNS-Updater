---
title: Getting Started
description: Set up Cloudflare DNS Updater in five minutes.
---

Cloudflare DNS Updater keeps the A (IPv4) and AAAA (IPv6) records of your Cloudflare zone pointed at your current public IP. It is a plain Bash program: run it from source or grab a standalone binary, point it at a YAML config, and schedule it with cron or any task scheduler.

## 1. Get the program

Either download a [standalone binary](../installation/#standalone-binaries) or clone the repository:

```bash
git clone https://github.com/jmrplens/Cloudflare-DNS-Updater.git
cd Cloudflare-DNS-Updater
```

## 2. Create a Cloudflare API token

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/profile/api-tokens), create a token with the **Edit zone DNS** template.
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
