# Security Policy

## Supported versions

Security fixes are applied to the latest released version. Always run the most
recent [release](https://github.com/jmrplens/Cloudflare-DNS-Updater/releases).

| Version | Supported |
| ------- | --------- |
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue for a
vulnerability.

- Preferred: use GitHub's private vulnerability reporting via the repository's
  [**Security → Report a vulnerability**](https://github.com/jmrplens/Cloudflare-DNS-Updater/security/advisories/new)
  form.
- Alternatively, contact the maintainer by encrypted email using the published
  PGP key
  [`0A993B268654DBBA52B7E8D3FCF653391E2C91FC`](https://keys.openpgp.org/vks/v1/by-fingerprint/0A993B268654DBBA52B7E8D3FCF653391E2C91FC).

When reporting, please include:

- affected version (`cloudflare-dns-updater.sh --version` or the binary name),
- a description of the issue and its impact,
- steps to reproduce, and
- any suggested remediation if you have one.

You can expect an initial acknowledgement within a few days. Once a fix is
released, you will be credited in the advisory unless you prefer to remain
anonymous.

## Handling credentials safely

This tool reads a Cloudflare API token from `cloudflare-dns.yaml`. To limit
exposure:

- Scope the token to **Edit zone DNS** for a single zone — never use a Global
  API Key.
- Restrict the config file to your user: `chmod 600 cloudflare-dns.yaml`. The
  program warns on startup if the file is world-readable.
- Secrets are redacted from `--debug` output and logs.
