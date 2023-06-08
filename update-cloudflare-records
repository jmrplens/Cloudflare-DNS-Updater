#!/usr/bin/env bash

# Colors
end_color=$(tput sgr0)
done_fb=$(tput setab 2 && tput setaf 0 && tput bold)
done_c=$(tput setaf 2 && tput bold)
err_c=$(tput setaf 1)
load_c=$(tput setaf 3 && tput bold)
blue_b_c=$(tput setaf 4 && tput bold)
green_c=$(tput setaf 2)

# Server to check external IP
get_ip_from="https://icanhazip.com"


##################################################################
# FUNCTIONS
done_fb_msg(){
  echo "${done_fb}$1${end_color}" 
}
done_msg(){
  echo "${done_c}$1${end_color}" 
}
error_msg(){
  echo "${err_c}$1${end_color}" 
}
blue_bold_msg(){
  echo "${blue_b_c}$1${end_color}" 
}
green_msg(){
  echo "${green_c}$1${end_color}" 
}
api_validation() {
  if [[ $1 == *"\"success\":false"* ]]; then
    echo $1
    error_msg "Error! Can't get ${end_color}${load_c}$2${end_color}${done_c} $3 record information from Cloudflare API"
  else
    done_msg "Loaded ${end_color}${load_c}$2${end_color}${done_c} $3 record information from Cloudflare API"
  fi
}
push_validation() {
  if [[ $1 == *"\"success\":false"* ]]; then
    echo $1
    error_msg "Error! Update $2 Failed"
  else
    done_msg "Pushed new $2"
  fi
}
external_validation(){
  if [ -z "$1" ]; then
    error_msg "Error! Can't get external $2 from $get_ip_from"
  else
    blue_bold_msg "Current External $2 is: $1"
  fi
}
internal_validation(){
  if [ -z "$1" ]; then
    error_msg "Error! Can't read $2 from $3"
  else
    done_msg "Internal $3 $2 is: $1"
  fi
}
read_record(){
  echo $(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$1/dns_records?type=$2&name=$3" \
      -H "Authorization: Bearer $cloudflare_zone_api_token" \
      -H "Content-Type: application/json")
}
write_record(){
  echo $(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$1/dns_records/$2" \
         -H "Authorization: Bearer $cloudflare_zone_api_token" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"$3\",\"name\":\"$4\",\"content\":\"$5\",\"ttl\":$6,\"proxied\":$7}")
}




##################################################################
# SCRIPT

###  Create update-cloudflare-records.log file of the last run for debug
parent_path="$(dirname "${BASH_SOURCE[0]}")"
FILE=${parent_path}/update-cloudflare-records.log
if ! [ -x "$FILE" ]; then
  touch "$FILE"
fi

LOG_FILE=${parent_path}'/update-cloudflare-records.log'

### Write last run of STDOUT & STDERR as log file and prints to screen
exec > >(tee $LOG_FILE) 2>&1
printf "\n"
echo "DATE: $(date "+%Y-%m-%d %H:%M:%S")"
printf "\n"

#################################
# VALIDATE CONFIG FILE SETTINGS

if [[ -z "$1" ]]; then # If not set explicit config file and no exist default config
  if ! source ${parent_path}/update-cloudflare-records.conf; then
    error_msg "Error! Missing configuration file update-cloudflare-records.conf or invalid syntax!"
    exit 0
  fi
else
  if ! source ${parent_path}/"$1"; then
    error_msg "Error! Missing configuration file '$1' or invalid syntax!"
    exit 0
  fi
fi

# Check validity of "ttl" parameter
if [ "${ttl}" -lt 120 ] || [ "${ttl}" -gt 7200 ] && [ "${ttl}" -ne 1 ]; then
  error_msg "Error! ttl out of range (120-7200) or not set to 1"
  exit 0
fi

# Check validity of "proxied" parameter
if [ "${proxied}" != "false" ] && [ "${proxied}" != "true" ]; then
  error_msg "Error! Incorrect "proxied" parameter choose 'true' or 'false'"
  exit 0
fi

# Check validity of "what_ip" parameter
if [ "${what_ip}" != "external" ] && [ "${what_ip}" != "internal" ]; then
  error_msg "Error! Incorrect 'what_ip' parameter choose 'external' or 'internal'"
  exit 0
fi

# Check if set to internal ip and proxy
if [ "${what_ip}" == "internal" ] && [ "${proxied}" == "true" ]; then
  error_msg "Error! Internal IP cannot be Proxied"
  exit 0
fi

# Get External ip from '$get_ip_from'
if [ "${what_ip}" == "external" ]; then
  ip4=$(curl -4 -s -X GET $get_ip_from --max-time 20 )
  ip6=$(curl -6 -s -X GET $get_ip_from --max-time 20 )
  external_validation "$ip4" "IPv4"
  external_validation "$ip6" "IPv6"
  printf "\n"
fi

### Get Internal IPv4 from primary interface
if [ "${what_ip}" == "internal" ]; then
  ### Check if "IP" command is present, get the ip from interface
  if which ip >/dev/null; then
    ### "ip route get" (linux)
    interface=$(ip route get 1.1.1.1 | awk '/dev/ { print $5 }')
    ip4=$(ip -o -4 addr show ${interface} scope global | awk '{print $4;}' | cut -d/ -f 1)
  ### if no "IP" command use "ifconfig", get the ip from interface
  else
    ### "route get" (macOS, Freebsd)
    interface=$(route get 1.1.1.1 | awk '/interface:/ { print $2 }')
    ip4=$(ifconfig ${interface} | grep 'inet ' | awk '{print $2}')
  fi
  internal_validation "$ip4" "IPv4" "$interface"
fi

### Get Internal IPv6 from primary interface
if [ "${what_ip}" == "internal" ]; then
  ### Check if "IP" command is present, get the ip from interface
  if which ip >/dev/null; then
    ### "ip route get" (linux)
    interface=$(ip route get 1.1.1.1 | awk '/dev/ { print $5 }')
    ip6=$(ip -o -6 addr show ${interface} scope global | awk '{print $4;}' | cut -d/ -f 1)
  ### if no "IP" command use "ifconfig", get the ip from interface
  else
    ### "route get" (macOS, Freebsd)
    interface=$(route get 1.1.1.1 | awk '/interface:/ { print $2 }')
    ip6=$(ifconfig ${interface} | grep 'inet6 ' | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80)
  fi
  internal_validation "$ip4" "IPv4" "$interface"
fi

### Build coma separated array fron dns_record parameter to update multiple A records
IFS=',' read -d '' -ra dns_records <<<"$dns_record,"
unset 'dns_records[${#dns_records[@]}-1]'
declare dns_records ip4_done ip6_done

for record in "${dns_records[@]}"; do

  ### Get IP address of DNS record from 1.1.1.1 DNS server when proxied is "false"
  if [ "${proxied}" == "false" ]; then
    ### Check if "nsloopup" command is present
    if which nslookup >/dev/null; then
      dns_record_ip=$(nslookup -query=A ${record} 1.1.1.1 | awk '/Address/ { print $2 }' | sed -n '2p')
      dns_record_ip6=$(nslookup -query=AAAA ${record} 1.1.1.1 | awk '/Address/ { print $2 }' | sed -n '2p')
    else
      ### if no "nslookup" command use "host" command
      dns_record_ip=$(host -t A ${record} 1.1.1.1 | awk '/has address/ { print $4 }' | sed -n '1p')
      dns_record_ip6=$(host -t AAAA ${record} 1.1.1.1 | awk '/has address/ { print $4 }' | sed -n '1p')
    fi

    if [ -z "$dns_record_ip" ]; then
      echo "Error! Can't resolve the ${record} IPv4 via 1.1.1.1 DNS server"
      exit 0
    fi
    if [ -z "$dns_record_ip6" ]; then
      echo "Error! Can't resolve the ${record} IPv6 via 1.1.1.1 DNS server"
      exit 0
    fi
    is_proxied4="${proxied}"
    is_proxied6="${proxied}"
  fi

  ### Get the dns record id and current proxy status from cloudflare's api when proxied is "true"
  if [ "${proxied}" == "true" ]; then
    dns_record_info4=$(read_record "$zoneid" "A" "$record")
    api_validation "$dns_record_info4" "$record" "IPv4"
    is_proxied4=$(echo ${dns_record_info4} | grep -o '"proxied":[^,]*' | grep -o '[^:]*$')
    dns_record_ip4=$(echo ${dns_record_info4} | grep -o '"content":"[^"]*' | cut -d'"' -f 4)
  fi

  if [ "${proxied}" == "true" ]; then
    dns_record_info6=$(read_record "$zoneid" "AAAA" "$record")
    api_validation "$dns_record_info6" "$record" "IPv6"
    is_proxied6=$(echo ${dns_record_info6} | grep -o '"proxied":[^,]*' | grep -o '[^:]*$')
    dns_record_ip6=$(echo ${dns_record_info6} | grep -o '"content":"[^"]*' | cut -d'"' -f 4)
  fi

  ### Check if ip or proxy have changed
  if [[ ${dns_record_ip4} == ${ip4} ]] && [[ ${is_proxied4} == ${proxied} ]]; then
    echo "${done_c}Current DNS record IPv4 of ${end_color}${load_c}${record}${end_color}${done_c} is ${dns_record_ip4} and proxy status is ${is_proxied4}, no changes needed${end_color}."
    #continue
    ip4_done=true
  else
    ip4_done=false
  fi

  if [[ ${dns_record_ip6} == ${ip6} ]] && [[ ${is_proxied6} == ${proxied} ]]; then
    echo "${done_c}Current DNS record IPv6 of ${end_color}${load_c}${record}${end_color}${done_c} is ${dns_record_ip6} and proxy status is ${is_proxied6}, no changes needed${end_color}."
    ip6_done=true
  else
    ip6_done=false
  fi

  
  if [ "$ip4_done" = false ]; then
    echo "$load_c New DNS record IPv4 of ${record} is: ${dns_record_ip4}. Trying to update...$end_color"

    ### Get the IPv4 dns record id from response
    cloudflare_dns_record_id_4=$(echo ${dns_record_info4} | grep -o '"id":"[^"]*' | cut -d'"' -f4)

    ### Push new dns record information to cloudflare's api
    update_dns_record_4=$(write_record "$zoneid" "$cloudflare_dns_record_id_4" "A" "$record" "$ip4" "$ttl" "$proxied")
    push_validation "$update_dns_record_4" "IPv4"
  fi

  if [ "$ip6_done" = false ]; then
    echo "$load_c New DNS record IPv6 of ${record} is: ${dns_record_ip6}. Trying to update...$end_color"

    ### Get the IPv6 dns record id from response
    cloudflare_dns_record_id_6=$(echo ${dns_record_info6} | grep -o '"id":"[^"]*' | cut -d'"' -f4)

    ### Push new dns record information to cloudflare's api
    update_dns_record_6=$(write_record "$zoneid" "$cloudflare_dns_record_id_6" "AAAA" "$record" "$ip6" "$ttl" "$proxied")
    push_validation "$update_dns_record_6" "IPv6"
  fi

  # Show results
  if [ "$ttl" = 1 ]; then
    ttl_info="Automatic"
  else
    ttl_info="$ttl secods"
  fi

  printf "\n"
  green_msg "----------------------------------------"
  done_fb_msg "DOMAIN: $record"
  green_msg "----------------------------------------"
  green_msg "Current IPv4 Address: $ip4"
  green_msg "Current IPv6 Address: $ip6"
  green_msg "Cloudflare proxy    : $proxied"
  green_msg "TTL                 : $ttl_info"
  green_msg "----------------------------------------"
  printf "\n"

  ### Telegram notification
  if [ ${notify_me_telegram} == "yes" ]; then
    telegram_notification=$(
      curl -s -X GET "https://api.telegram.org/bot${telegram_bot_API_Token}/sendMessage?chat_id=${telegram_chat_id}" --data-urlencode "text=${record} DNS record updated to: ${ip4} / ${ip6}"
    )
    if [[ ${telegram_notification=} == *"\"ok\":false"* ]]; then
      echo ${telegram_notification=}
      echo "Error! Telegram notification failed"
    fi
  fi
done
