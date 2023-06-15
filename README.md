# Dynamic DNS - Cloudflare

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/b2c4010d9c46471aacd749ddb1cb0517)](https://app.codacy.com/gh/jmrplens/DynDNS_Cloudflare_IPv4-6?utm_source=github.com&utm_medium=referral&utm_content=jmrplens/DynDNS_Cloudflare_IPv4-6&utm_campaign=Badge_Grade)

Bash script to update IPv4 and IPv6 records in Cloudflare. Update with WAN or LAN IP.

Based on this project: [DDNS-Cloudflare-Bash](https://github.com/fire1ce/DDNS-Cloudflare-Bash).

## Example

<table>
<tr>
<td> Result </td> <td> Settings </td>
</tr>
<tr>
<td> <img width="100%" alt="Screenshot of Termius (9-6-23, 01-13-49)" src="https://github.com/jmrplens/DynDNS_Cloudflare_IPv4-6/assets/28966312/3209e061-27ee-4644-9890-d509a8ca4a28"> </td>
<td>
    
```yaml
domains:
    - name: jmrp.dev
      ip_type: external
      ipv4: true
      ipv6: true
      proxied: true
      ttl: auto
    - name: git.jmrp.dev
      ip_type: external
      ipv4: true
      ipv6: true
      proxied: true
      ttl: auto
    - name: jenkins.jmrp.dev
      ip_type: external
      ipv4: true
      ipv6: true
      proxied: true
      ttl: auto

settings:
    cloudflare:
        - zone_id: #########
        - zone_api_token: ########
    misc:
        - create_if_no_exist: false

notifications:
    telegram: 
        enabled: false
        bot_token: token
        chat_id: id
```

</td>
</tr>
</table>

## About

    - Bash Script for most **Linux**, **Unix** distributions and **MacOS**.
    - Choose any source IP address to update **external** or **internal** _(WAN/LAN)_ for ech domain.
    - For multiply lan interfaces like Wifi, Docker Networks and Bridges the script will automatically detects the primary Interface by priority.
    - Cloudflare's options proxy and TTL configurable via the config file for each domain.
    - Optional Telegram Notifications


## Requirements

    - [curl](https://everything.curl.dev/get) 
    - Cloudflare [api-token](https://dash.cloudflare.com/profile/api-tokens) with ZONE-DNS-EDIT Permissions
    - DNS Record must be pre created in web interface (WIP: Create record if no exist)

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

You can use default config file _update-cloudflare-records.yaml_ or pass your own config file as parameter to script.

```shell
wget https://raw.githubusercontent.com/jmrplens/DyDNS_Cloudflare_IPv4-6/main/update-cloudflare-records.yaml
```

Place the **config** file in the directory as the **update-cloudflare-dns** for above example at _/usr/local/bin/_

```shell
sudo mv update-cloudflare-dns.yaml /usr/local/bin/update-cloudflare-records.yaml
```

## Config Parameters

```yaml
domains:
  - name: example.com
    ip_type: external
    ipv4: true
    ipv6: true
    proxied: true
    ttl: auto
    
settings:
  cloudflare:
    - zone_id: #########
    - zone_api_token: ########
  misc:
    - create_if_no_exist: false

notifications:
  telegram: 
    enabled: false
    bot_token: token
    chat_id: id
```

Multiple domains is supported:

```yaml
domains:
  - name: example.com
    ip_type: external
    ipv4: true
    ipv6: true
    proxied: true
    ttl: auto
  - name: example2.com
    ip_type: external
    ipv4: true
    ipv6: true
    proxied: true
    ttl: auto
  - name: ..........
.........
```

#### Domains

| **Option**                | **Example**       | **Description**                                                                                                           |
| ------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| name                      | example.com       | Domain name. **Required**                                                                                                 |
| ip_type                   | external          | Which IP should be used for the record: internal/external. **Optional** (default: external)                               |
| ipv4                      | true              | Update IPv4 DNS Record: true/false. **Optional** (default: true)                                                          |
| ipv6                      | true              | Update IPv6 DNS Record: true/false. **Optional** (default: true)                                                          |
| proxied                   | true              | Use Cloudflare proxy on dns record: true/false. **Optional** (default: true)                                              |
| ttl                       | 3600              | 120-7200 in seconds or auto. **Optional** (default: true)                                                                 |

#### Cloudflare

| **Option**                | **Example**       | **Description**                                                                                                           |
| ------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| zone_api_token            | token             | Cloudflare [API Token](https://dash.cloudflare.com/profile/api-tokens) **KEEP IT PRIVATE!!!!**                                                                              |
| zone_id                   | id                | Cloudflare's [Zone ID](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/find-account-and-zone-ids/) |

##### Cloudflare misc

| **Option**                | **Example**       | **Description**                                                                                                           |
| ------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| create_if_no_exist        | false             | Not yet implemented                                                                                                       |

#### Notifications

##### Telegram

| **Option**              | **Example** | **Description**                          |
| ----------------------- | ----------- | ---------------------------------------- |
| enabled                 | true        | Use Telegram notifications: true/false.  |
| bot_token               | token       | Telegram's Bot API Token                 |
| chat_id                 | id          | Chat ID of the bot                       |

## Running The Script

When placed in _/usr/local/bin/_

```shell
update-cloudflare-records
```

With your config file (need to be placed in same folder)

```shell
update-cloudflare-records yoru_config.conf
```

## Automation With Crontab

You can run the script via crontab

```shell
crontab -e
```

### Examples

<table>
<tr>
<td> Example </td> <td> Code </td>
</tr>
<tr>
  <td> Run <a href="https://crontab.guru/every-1-minute">every minute</a> </td>
<td>
    
```shell
* * * * * /usr/local/bin/update-cloudflare-records
```

</td>
</tr>
<tr>
  <td> Run every minute with your specific config file </td>
<td>
    
```shell
* * * * * /usr/local/bin/update-cloudflare-records myconfig.yaml
```

</td>
</tr>
<tr>
  <td> Run every <a href="https://crontab.guru/#*/2_*_*_*_*">every 2 minutes</a> </td>
<td>
    
```shell
*/2 * * * * /usr/local/bin/update-cloudflare-records
```

</td>
</tr>
<tr>
  <td> Run at <a href="https://crontab.guru/#@reboot">boot</a> </td>
<td>
    
```shell
@reboot /usr/local/bin/update-cloudflare-records
```

</td>
</tr>
<tr>
  <td> Run 1 minute after boot </td>
<td>
    
```shell
@reboot sleep 60 && /usr/local/bin/update-cloudflare-records
```

</td>
</tr>
</table>

## Logs

This Script will create a log file with **only** the last run information
Log file will be located at the script's location.

Example:

```bash
/usr/local/bin/update-cloudflare-records.log
```
