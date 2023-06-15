#!/usr/bin/env bash

# Default settings
def_ip_type="external"
def_ip_type_enabled=false
def_ttl="auto"
def_ttl_enabled=false
def_proxied=true
def_proxied_enabled=false
def_ipv4=true
def_ipv4_enabled=false
def_ipv6=false
def_ipv6_enabled=false

# Globals
error_dom=false
ip4=""
ip6=""
dns_record_ip4=""
dns_record_id_4=""
dns_record_ip6=""
dns_record_id_6=""
is_proxied4=""
is_proxied6=""

# Colors
end_color=$(tput sgr0)
done_fb=$(tput setab 2 && tput setaf 0 && tput bold)
done_c=$(tput setaf 2 && tput bold)
err_c=$(tput setaf 1)
load_c=$(tput setaf 3 && tput bold)
warn_c=$(tput setaf 3)
blue_b_c=$(tput setaf 4 && tput bold)
green_c=$(tput setaf 2)

# Server to check external IP
get_ip_from="https://icanhazip.com"

##################################################################
# GENERIC FUNCTIONS
done_fb_msg() {
  echo "${done_fb}${1}${end_color}"
  return 1
}
done_msg() {
  echo "${done_c}${1}${end_color}"
  return 1
}
error_msg() {
  echo "${err_c}${1}${end_color}"
  return 1
}
warn_msg() {
  echo "${warn_c}${1}${end_color}"
  return 1
}
blue_bold_msg() {
  echo "${blue_b_c}${1}${end_color}"
  return 1
}
green_msg() {
  echo "${green_c}${1}${end_color}"
  return 1
}
# shellcheck disable=SC2154
get_domain_settings() {
  domain_name=${domains__name[$i]}
  if [ $def_ip_type_enabled == false ]; then
    domain_ip_type=${domains__ip_type[$i]}
  else
    domain_ip_type=${def_ip_type}
  fi
  if [ $def_ipv4_enabled == false ]; then
    domain_ipv4=${domains__ipv4[$i]}
  else
    domain_ipv4=${def_ipv4}
  fi
  if [ $def_ipv6_enabled == false ]; then
    domain_ipv6=${domains__ipv6[$i]}
  else
    domain_ipv6=${def_ipv6}
  fi
  if [ $def_proxied_enabled == false ]; then
    domain_proxied=${domains__proxied[$i]}
  else
    domain_proxied=${def_proxied}
  fi
  if [ $def_ttl_enabled == false ]; then
    domain_ttl=${domains__ttl[$i]}
  else
    domain_ttl=${def_ttl}
  fi
  echo "$domain_name $domain_ip_type $domain_ipv4 $domain_ipv6 $domain_proxied $domain_ttl"
}
##################################################################
# CLOUDFLARE API FUNCTIONS
api_validation() {
  if [[ "$1" == *"\"success\":false"* ]]; then
    error_msg "Error! Can't get ${end_color}${load_c}$2${end_color}${done_c} $3 record information from Cloudflare API"
    error_dom=true
  else
    done_msg "Loaded ${end_color}${load_c}$2${end_color}${done_c} $3 record information from Cloudflare API"
    error_dom=false
  fi
}
push_validation() {
  if [[ $1 == *"\"success\":false"* ]]; then
    error_msg "Error! Update $2 Failed"
    error_dom=true
  else
    done_msg "Pushed new $2"
    error_dom=false
  fi
}
external_validation() {
  if [ -z "$1" ]; then
    error_msg "Error! Can't get external $2 from $get_ip_from"
    exit 0
  else
    blue_bold_msg "Current External $2 is: $1"
    return 1
  fi
}
internal_validation() {
  if [ -z "$1" ]; then
    error_msg "Error! Can't read $2 from $3"
    exit 0
  else
    done_msg "Internal $3 $2 is: $1"
    return 1
  fi
}
read_record() {
  curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$1/dns_records?type=$3&name=$4" \
    -H "Authorization: Bearer $2" \
    -H "Content-Type: application/json"
}
write_record() {
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$1/dns_records/$2" \
    -H "Authorization: Bearer $3" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"$4\",\"name\":\"$5\",\"content\":\"$6\",\"ttl\":$7,\"proxied\":$8}"
}

##################################################################
# NETWORK FUNCTIONS
get_ip_external() {
  if [ "$1" == true ]; then
    ip4=$(curl -4 -s -X GET $get_ip_from --max-time 20)
  else
    ip4=""
  fi
  if [ "$2" == true ]; then
    ip6=$(curl -6 -s -X GET $get_ip_from --max-time 20)
  else
    ip6=""
  fi
  echo "$ip4" "$ip6"
}

get_ip_internal() {
  ### Check if "IP" command is present, get the ip from interface
  if which ip >/dev/null; then
    ### "ip route get" (linux)
    interface=$(ip route get 1.1.1.1 | awk '/dev/ { print $5 }')
    if [ "${1}" == true ]; then
      ip4=$(ip -o -4 addr show "${interface}" scope global | awk '{print $4;}' | cut -d/ -f 1)
    else
      ip4=""
    fi
    if [ "${2}" == true ]; then
      ip6=$(ip -o -6 addr show "${interface}" scope global | awk '{print $4;}' | cut -d/ -f 1)
    else
      ip6=""
    fi
  ### if no "IP" command use "ifconfig", get the ip from interface
  else
    ### "route get" (macOS, Freebsd)
    interface=$(route get 1.1.1.1 | awk '/interface:/ { print $2 }')
    if [ "${1}" == true ]; then
      ip4=$(ifconfig "${interface}" | grep 'inet ' | awk '{print $2}')
    else
      ip4=""
    fi
    if [ "${2}" == true ]; then
      ip6=$(ifconfig "${interface}" | grep 'inet6 ' | awk -F '[ \t]+|/' '{print $3}' | grep -v ^::1 | grep -v ^fe80)
    else
      ip6=""
    fi
  fi
  echo "$ip4" "$ip6" "$interface"
}

get_ip() {
  # Get External ip from '$get_ip_from'
  if [ "$1" == "external" ]; then
    read -r ip4 ip6 < <(get_ip_external "$2" "$3")
    external_validation "$ip4" "IPv4"
    external_validation "$ip6" "IPv6"
    printf "\n"
  fi

  ### Get Internal IP from primary interface
  if [ "$1" == "internal" ]; then
    read -r ip4 ip6 interface < <(get_ip_internal "$2" "$3")
    internal_validation "$ip4" "IPv4" "$interface"
    internal_validation "$ip6" "IPv6" "$interface"
    printf "\n"
  fi
}

get_dns_record_ip() {
  local record=$1
  local proxied=$2
  local zone_id=$3
  local zone_token=$4

  ### Get IP address of DNS record from 1.1.1.1 DNS server when proxied is "false"
  if [ "${proxied}" == "false" ]; then
    ### Check if "nslookup" command is present
    if which nslookup >/dev/null; then
      if [ "${domain_ipv4}" == true ]; then
        dns_record_ip4=$(nslookup -query=A "${record}" 1.1.1.1 | awk '/Address/ { print $2 }' | sed -n '2p')
      fi
      if [ "${domain_ipv6}" == true ]; then
        dns_record_ip6=$(nslookup -query=AAAA "${record}" 1.1.1.1 | awk '/Address/ { print $2 }' | sed -n '2p')
      fi
    else
      ### if no "nslookup" command use "host" command
      if [ "${domain_ipv4}" == true ]; then
        dns_record_ip4=$(host -t A "${record}" 1.1.1.1 | awk '/has address/ { print $4 }' | sed -n '1p')
      fi
      if [ "${domain_ipv6}" == true ]; then
        dns_record_ip6=$(host -t AAAA "${record}" 1.1.1.1 | awk '/has address/ { print $4 }' | sed -n '1p')
      fi
    fi

    if [ "${domain_ipv4}" == true ]; then
      if [ -z "${dns_record_ip4}" ]; then
        echo "Error! Can't resolve the ${record} IPv4 via 1.1.1.1 DNS server"
        error_dom=true
      fi
    fi
    if [ "${domain_ipv6}" == true ]; then
      if [ -z "${dns_record_ip6}" ]; then
        echo "Error! Can't resolve the ${record} IPv6 via 1.1.1.1 DNS server"
        error_dom=true
      fi
    fi
    is_proxied4="${proxied}"
    is_proxied6="${proxied}"
  fi

  ### Get the dns record id and current proxy status from cloudflare's api when proxied is "true"
  if [ "${proxied}" == "true" ]; then
    if [ "${domain_ipv4}" == true ]; then
      dns_record_info4=$(read_record "$zone_id" "$zone_token" "A" "$record")
      is_proxied4=$(echo "${dns_record_info4}" | grep -o '"proxied":[^,]*' | grep -o '[^:]*$')
      dns_record_ip4=$(echo "${dns_record_info4}" | grep -o '"content":"[^"]*' | cut -d'"' -f 4)
      dns_record_id_4=$(echo "${dns_record_info4}" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
      api_validation "$dns_record_info4" "$record" "IPv4"
    fi
    if [ "${domain_ipv6}" == true ]; then
      dns_record_info6=$(read_record "$zone_id" "$zone_token" "AAAA" "$record")
      is_proxied6=$(echo "${dns_record_info6}" | grep -o '"proxied":[^,]*' | grep -o '[^:]*$')
      dns_record_ip6=$(echo "${dns_record_info6}" | grep -o '"content":"[^"]*' | cut -d'"' -f 4)
      dns_record_id_6=$(echo "${dns_record_info6}" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
      api_validation "$dns_record_info6" "$record" "IPv6"
    fi
  fi
}

##################################################################
# Input settings validation
settings_validation() {
  # Check if "cloudflare_zone_id" is set
  if [ -z "$settings_cloudflare__zone_id" ]; then
    error_msg "Error! Cloudflare Zone ID not set"
    exit 0
  fi
  # Check if "cloudflare_zone_api_token" is set
  if [ -z "$settings_cloudflare__zone_api_token" ]; then
    error_msg "Error! Cloudflare API Token not set"
    exit 0
  fi
}

settings_domains_validation() {
  # Domains quantity
  n_doms=${#domains__name[@]}

  for ((i = 0; i < n_doms; i++)); do
    # Check if "name" parameter is set
    if [ -z "${domains__name[$i]}" ]; then
      error_msg "Error! Domain name not set"
      exit 0
    fi

    # Check validity of "ttl" parameter
    if [ "${domains__ttl[$i]}" -lt 120 ] 2>/dev/null ||
      [ "${domains__ttl[$i]}" -gt 7200 ] 2>/dev/null ||
      [ "${domains__ttl[$i]}" != "auto" ]; then
      warn_msg "Error! 'ttl' out of range (120-7200) or not set to 'auto'. Force set to '$def_ttl'"
      def_ttl_enabled=true
    fi

    # Check validity of "proxied" parameter
    if [ "${domains__proxied[$i]}" != "false" ] &&
      [ "${domains__proxied[$i]}" != "true" ]; then
      warn_msg "Error! Incorrect 'proxied' parameter, choose 'true' or 'false'. Force set to '$def_proxied''"
      def_proxied_enabled=true
    fi

    # Check validity of "what_ip" parameter
    if [ "${domains__ip_type[$i]}" != "external" ] &&
      [ "${domains__ip_type[$i]}" != "internal" ]; then
      warn_msg "Error! Incorrect 'ip_type' parameter choose 'external' or 'internal'. Force set to '$def_ip_type''"
      def_ip_type_enabled=true
    fi

    # Check if set to internal ip and proxy
    if [ "${domains__ip_type[$i]}" == "internal" ] &&
      [ "${domains__proxied[$i]}" == "true" ]; then
      error_msg "Error! Internal IP cannot be Proxied"
      exit 0
    fi
  done
}

settings_file_validation() {
  if [[ -z "$1" ]]; then # If not set explicit config file and no exist default config
    if [ ! -f "${parent_path}"/update-cloudflare-records.yaml ]; then
      error_msg "Error! Missing configuration file update-cloudflare-records.yaml or invalid syntax!"
      exit 0
    else
      config_file=${parent_path}/update-cloudflare-records.yaml
    fi
  else
    if [ ! -f "${parent_path}"/"$1" ]; then
      error_msg "Error! Missing configuration file '$1' or invalid syntax!"
      exit 0
    else
      config_file=${parent_path}/"$1"
    fi
  fi
  echo "$config_file"
}

##################################################################
# YAML PARSER (from: https://github.com/jasperes/bash-yaml)
# shellcheck disable=SC1003
parse_yaml() {
  local yaml_file=$1
  local prefix=$2
  local s
  local w
  local fs

  s='[[:space:]]*'
  w='[a-zA-Z0-9_.-]*'
  fs="$(echo @ | tr @ '\034')"

  (
    sed -e '/- [^\“]'"[^\']"'.*: /s|\([ ]*\)- \([[:space:]]*\)|\1-\'$'\n''  \1\2|g' |
      sed -ne '/^--/s|--||g; s|\"|\\\"|g; s/[[:space:]]*$//g;' \
        -e 's/\$/\\\$/g' \
        -e "/#.*[\"\']/!s| #.*||g; /^#/s|#.*||g;" \
        -e "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)${s}[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
      awk -F"$fs" '{
            indent = length($1)/2;
            if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
            vname[indent] = $2;
            for (i in vname) {if (i > indent) {delete vname[i]}}
                if (length($3) > 0) {
                    vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
                    printf("%s%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, conj[indent-1], $3);
                }
            }' |
      sed -e 's/_=/+=/g' |
      awk 'BEGIN {
                FS="=";
                OFS="="
            }
            /(-|\.).*=/ {
                gsub("-|\\.", "_", $1)
            }
            { print }'
  ) <"$yaml_file"
}

unset_variables() {
  # Pulls out the variable names and unsets them.
  local variable_string="($*)"
  unset variables
  variables=()
  for variable in "${variable_string[@]}"; do
    tmpvar=$(echo "$variable" | grep '=' | sed 's/=.*//' | sed 's/+.*//')
    variables+=("$tmpvar")
  done
  for variable in "${variables[@]}"; do
    if [ -n "$variable" ]; then
      unset "$variable"
    fi
  done
}

create_variables() {
  local yaml_file="$1"
  local prefix="$2"
  local yaml_string
  yaml_string="$(parse_yaml "$yaml_file" "$prefix")"
  unset_variables "${yaml_string}"
  eval "${yaml_string}"
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
exec > >(tee "$LOG_FILE") 2>&1
printf "\n"
echo "DATE: $(date "+%Y-%m-%d %H:%M:%S")"
printf "\n"

#################################
# Locate .yaml config file or set custom config file
read -r config_file < <(settings_file_validation "$1")

#################################
# Create variables from .yaml config file
create_variables "$config_file"

#################################
# VALIDATE CONFIG FILE SETTINGS (.yaml)
settings_validation
settings_domains_validation

#################################
# Cloudflare API
api_zone_id=$settings_cloudflare__zone_id
api_zone_token=$settings_cloudflare__zone_api_token

#################################
# Iterate over domains array
n_doms=${#domains__name[@]}
for ((i = 0; i < n_doms; i++)); do

  ### Get ith-domain settings
  read -r domain_name domain_ip_type domain_ipv4 domain_ipv6 domain_proxied domain_ttl < <(get_domain_settings "$i")
  [[ "${domain_ttl}" == "auto" ]] && ttl=1 || ttl=${domain_ttl}

  ### Get Host IP (external or internal)
  get_ip "$domain_ip_type" "$domain_ipv4" "$domain_ipv6"

  ### Get IP Domain from DNS (proxied=false) or from Cloudflare API (proxied=true)
  get_dns_record_ip "$domain_name" "$domain_proxied" "$api_zone_id" "$api_zone_token"
  [ $error_dom == true ] && continue

  ### Check if ip or proxy have changed
  if [ "$domain_ipv4" == true ] && [ "${dns_record_ip4}" == "${ip4}" ] && [ "${is_proxied4}" == "${domain_proxied}" ]; then
    echo "${done_c}Current DNS record IPv4 of ${end_color}${load_c}${record}${end_color}${done_c} is ${dns_record_ip4} and proxy status is ${is_proxied4}, no changes needed${end_color}."
    ip4_updatable=false
  else
    ip4_updatable=true
  fi
  if [ "$domain_ipv6" == true ] && [ "${dns_record_ip6}" == "${ip6}" ] && [ "${is_proxied6}" == "${domain_proxied}" ]; then
    echo "${done_c}Current DNS record IPv6 of ${end_color}${load_c}${domain_name}${end_color}${done_c} is ${dns_record_ip6} and proxy status is ${is_proxied6}, no changes needed${end_color}."
    ip6_updatable=false
  else
    ip6_updatable=true
  fi

  if [ $ip4_updatable = true ] && [ "$domain_ipv4" = true ]; then
    echo "$load_c New DNS record IPv4 of ${domain_name} is: ${dns_record_ip4}. Trying to update...$end_color"

    ### Push new dns record information to cloudflare's api
    update_dns_record_4=$(write_record "$api_zone_id" "$dns_record_id_4" "$settings_cloudflare__zone_api_token" "A" "$domain_name" "$ip4" "$ttl" "$domain_proxied")
    push_validation "$update_dns_record_4" "IPv4"
  fi

  if [ $ip6_updatable = true ] && [ "$domain_ipv6" == true ]; then
    echo "$load_c New DNS record IPv6 of ${domain_name} is: ${dns_record_ip6}. Trying to update...$end_color"

    ### Push new dns record information to cloudflare's api
    update_dns_record_6=$(write_record "$api_zone_id" "$dns_record_id_6" "$settings_cloudflare__zone_api_token" "AAAA" "$domain_name" "$ip6" "$ttl" "$domain_proxied")
    push_validation "$update_dns_record_6" "IPv6"
  fi

  # Show results
  if [ "$domain_ttl" == "auto" ]; then
    ttl_info="Automatic"
  else
    ttl_info="$ttl secods"
  fi

  printf "\n"
  green_msg "----------------------------------------"
  done_fb_msg "DOMAIN: $domain_name"
  green_msg "----------------------------------------"
  green_msg "Current IPv4 Address: $ip4"
  green_msg "Current IPv6 Address: $ip6"
  green_msg "Cloudflare proxy    : $domain_proxied"
  green_msg "TTL                 : $ttl_info"
  green_msg "----------------------------------------"
  printf "\n"

  ### Telegram notification
  # shellcheck disable=SC2154
  if [ "${notifications_telegram_enabled}" == true ]; then
    telegram_notification=$(
      curl -s -X GET "https://api.telegram.org/bot${notifications_telegram_bot_token}/sendMessage?chat_id=${notifications_telegram_chat_id}" --data-urlencode "text=${domain_name} DNS record updated to: ${ip4} / ${ip6}"
    )
    if [[ ${telegram_notification} == *"\"ok\":false"* ]]; then
      echo "${telegram_notification}"
      echo "Error! Telegram notification failed"
    fi
  fi

done
