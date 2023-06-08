# Dynamic DNS - Cloudflare
Bash script to update IPv4 and IPv6 records in Cloudflare. Update with WAN or LAN IP.

Based on this project: [DDNS-Cloudflare-Bash](https://github.com/fire1ce/DDNS-Cloudflare-Bash)
README IN WORK, MEANWHILE I COPY DDNS-Cloudflare-Bash Readme.

<img width="1062" alt="Screenshot of Termius (9-6-23, 01-13-49)" src="https://github.com/jmrplens/DynDNS_Cloudflare_IPv4-6/assets/28966312/3209e061-27ee-4644-9890-d509a8ca4a28">


- TODO: Write readme
- TODO: create record with script
- TODO: Config file in YAML

## About

- DDNS Cloudflare Bash Script for most **Linux**, **Unix** distributions and **MacOS**.
- Choose any source IP address to update **external** or **internal** _(WAN/LAN)_.
- For multiply lan interfaces like Wifi, Docker Networks and Bridges the script will automatically detects the primary Interface by priority.
- Cloudflare's options proxy and TTL configurable via the config file.
- Optional Telegram Notifications


## Requirements

- curl
- Cloudflare [api-token](https://dash.cloudflare.com/profile/api-tokens) with ZONE-DNS-EDIT Permissions
- DNS Record must be pre created in web interface (api-token should only edit dns records)

### Creating Cloudflare API Token

To create a CloudFlare API token for your DNS zone go to [cloudflare-api-token-url](https://dash.cloudflare.com/profile/api-tokens) and follow these steps:

1. Click Create Token
2. Select Create Custom Token
3. Provide the token a name, for example, `example.com-dns-zone-readonly`
4. Grant the token the following permissions:
   - Zone - DNS - Edit
5. Set the zone resources to:
   - Include - Specific Zone - `example.com`
6. Complete the wizard and use the generated token at the `CLOUDFLARE_API_TOKEN` variable for the container

## Installation

You can place the script at any location manually.

**MacOS**: Don't use the _/usr/local/bin/_ for the script location. Create a separate folder under your user path _/Users/${USER}_

The automatic install examples below will place the script at _/usr/local/bin/_

```shell
wget https://raw.githubusercontent.com/jmrplens/DyDNS_Cloudflare_IPv4-6/main/update-cloudflare-records.sh
sudo chmod +x update-cloudflare-records.sh
sudo mv update-cloudflare-dns.sh /usr/local/bin/update-cloudflare-records
```

## Config file

You can use default config file _update-cloudflare-records.conf_ or pass your own config file as parameter to script.

```shell
wget https://raw.githubusercontent.com/jmrplens/DyDNS_Cloudflare_IPv4-6/main/update-cloudflare-records.conf
```

Place the **config** file in the directory as the **update-cloudflare-dns** for above example at _/usr/local/bin/_

```shell
sudo mv update-cloudflare-dns.conf /usr/local/bin/update-cloudflare-records.conf
```

## Config Parameters

| **Option**                | **Example**      | **Description**                                                                                                           |
| ------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------- |
| what_ip                   | internal         | Which IP should be used for the record: internal/external                                                                 |
| dns_record                | ddns.example.com | DNS **A** record which will be updated, you can pass multiple **A** records separated by comma                            |
| cloudflare_zone_api_token | ChangeMe         | Cloudflare API Token **KEEP IT PRIVATE!!!!**                                                                              |
| zoneid                    | ChangeMe         | Cloudflare's [Zone ID](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/find-account-and-zone-ids/) |
| proxied                   | false            | Use Cloudflare proxy on dns record true/false                                                                             |
| ttl                       | 120              | 120-7200 in seconds or 1 for Auto                                                                                         |

### Optional Notifications Parameters

| **Option**             | **Example** | **Description**                   |
| ---------------------- | ----------- | --------------------------------- |
| notify_me_telegram     | yes         | Use Telegram notifications yes/no |
| telegram_chat_id       | ChangeMe    | Chat ID of the bot                |
| telegram_bot_API_Token | ChangeMe    | Telegram's Bot API Token          |

## Running The Script

When placed in _/usr/local/bin/_

```shell
update-cloudflare-records
```

With your config file (need to be placed in same folder)

```shell
update-cloudflare-records yoru_config.conf
```

Or manually

```shell
<path>/.update-cloudflare-records.sh
```

## Automation With Crontab

You can run the script via crontab

```shell
crontab -e
```

### Examples

Run every minute

```shell
* * * * * /usr/local/bin/update-cloudflare-records
```

Run with your specific config file

```shell
* * * * * /usr/local/bin/update-cloudflare-records myconfig.conf
```

Run every 2 minutes

```shell
*/2 * * * * /usr/local/bin/update-cloudflare-records
```

Run at boot

```shell
@reboot /usr/local/bin/update-cloudflare-records
```

Run 1 minute after boot

```shell
@reboot sleep 60 && /usr/local/bin/update-cloudflare-records
```

Run at 08:00

```shell
0 8 * * * /usr/local/bin/update-cloudflare-records
```

## Logs

This Script will create a log file with **only** the last run information
Log file will be located at the script's location.

Example:

```bash
/usr/local/bin/update-cloudflare-records.log
```
