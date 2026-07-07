---
title: Automation
description: Run Cloudflare DNS Updater on a schedule with cron, systemd or Task Scheduler.
head:
  - tag: script
    attrs:
      type: application/ld+json
    content: |-
      {"@context":"https://schema.org","@type":"FAQPage","@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/automation/","inLanguage":"en","isPartOf":{"@id":"https://jmrplens.github.io/Cloudflare-DNS-Updater/#website"},"about":{"@id":"https://github.com/jmrplens/Cloudflare-DNS-Updater#software"},"mainEntity":[{"@type":"Question","name":"How often should it run?","acceptedAnswer":{"@type":"Answer","text":"Every 5 minutes is a comfortable default for home connections. Cloudflare's limit of 1200 requests per 5 minutes leaves large headroom even at one run per minute."}},{"@type":"Question","name":"Will overlapping runs cause problems?","acceptedAnswer":{"@type":"Answer","text":"No. A lockfile makes a second invocation exit immediately, so aggressive schedules are safe."}},{"@type":"Question","name":"How do I check it is working?","acceptedAnswer":{"@type":"Answer","text":"Run it once with --debug to watch IP detection and the API calls. When running from source, the same output is also written to logs/updater.log in the project directory."}},{"@type":"Question","name":"Does a run cost an API request when nothing changed?","acceptedAnswer":{"@type":"Answer","text":"Yes, one read request per run. It only writes to the API when the IP actually changed (or when you pass --force)."}}]}
---

Dynamic IPs change without warning, so run the updater on a schedule. It exits quickly when nothing changed (one paginated API read, no writes), and the lock prevents overlapping runs.

## Linux / macOS: cron

Schedule the updater with [cron](https://man7.org/linux/man-pages/man5/crontab.5.html):

```bash
crontab -e
```

```bash
# Every 5 minutes, quietly
*/5 * * * * /opt/Cloudflare-DNS-Updater/cloudflare-dns-updater.sh --silent
```

Use the absolute path to the launcher (or binary). Output is already suppressed by `--silent`; errors still print and land in cron mail if configured.

## Linux: systemd timer

Prefer a [systemd timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)? Create the service unit at `/etc/systemd/system/cf-updater.service`:

```ini
[Unit]
Description=Cloudflare DNS Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/Cloudflare-DNS-Updater/cloudflare-dns-updater.sh --silent
```

`/etc/systemd/system/cf-updater.timer`:

```ini
[Unit]
Description=Run Cloudflare DNS Updater every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cf-updater.timer
systemctl list-timers cf-updater.timer
```

## Windows: Task Scheduler

1. Open [**Task Scheduler**](https://learn.microsoft.com/windows/win32/taskschd/task-scheduler-start-page) → *Create Basic Task*.
2. Name it e.g. "Cloudflare DNS Updater".
3. Trigger: **Daily**, then edit the task's properties to *Repeat task every 5 minutes* for a duration of *Indefinitely*.
4. Action: **Start a Program** → browse to `cf-updater-windows-x86_64.exe`.
5. Arguments: `--silent`.
6. In the task's settings, set *Start in* to the folder containing `cloudflare-dns.yaml`.

## Choosing an interval

Every run that detects no change costs one read request to the Cloudflare API. Cloudflare's global API rate limit (1200 requests per 5 minutes per user) leaves enormous headroom even at one run per minute; every 5 minutes is a comfortable default for home connections.

## Frequently asked questions

### How often should it run?

Every 5 minutes is a comfortable default for home connections. Cloudflare's limit of 1200 requests per 5 minutes leaves large headroom even at one run per minute.

### Will overlapping runs cause problems?

No. A lockfile makes a second invocation exit immediately, so aggressive schedules are safe.

### How do I check it is working?

Run it once with `--debug` to watch IP detection and the API calls. When running from source, the same output is also written to `logs/updater.log` in the project directory.

### Does a run cost an API request when nothing changed?

Yes, one read request per run. It only writes to the API when the IP actually changed (or when you pass `--force`).
