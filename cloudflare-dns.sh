#!/bin/bash

# Cloudflare DNS Management Script (cloudflareDNS.sh)
# Copyright (c) 2023 Your Name/Organization
# License: MIT

set -euo pipefail

VERSION="1.7.0"

#==============================================================================
# CONFIGURATION
#==============================================================================

# Default configuration values
CONFIG_FILE="cloudflare-dns.yaml"
LOG_FILE="cloudflare-dns.log"
LOG_TO_TERMINAL=true
RETRY_ATTEMPTS=3
RETRY_INTERVAL=5
VERBOSITY="error"
MAX_PARALLEL_JOBS=1

# Default global settings
DEFAULT_GLOBAL_IPV4=true
DEFAULT_GLOBAL_IPV6=true
DEFAULT_GLOBAL_PROXIED=true
DEFAULT_GLOBAL_TTL="auto"
DEFAULT_ENABLE_CREATE_RECORD=false

# Cloudflare API settings
ZONE_ID=""
ZONE_API_TOKEN=""

# Command-line override for record creation
CLI_ENABLE_CREATE_RECORD=""

# Notification plugins
declare -A NOTIFICATION_PLUGINS

# Colors for terminal output
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[0;33m'
    [BLUE]='\033[0;34m'
    [MAGENTA]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [GRAY]='\033[0;37m'
    [RESET]='\033[0m'
    [BOLD]='\033[1m'
)

#==============================================================================
# UTILITY FUNCTIONS
#==============================================================================

# Enhanced logging function with support for different verbosity levels
log() {
    local message="$1"
    local level="${2:-info}"
    local timestamp
    local color="${COLORS[RESET]}"
    local caller_func="${FUNCNAME[2]:-${FUNCNAME[1]:-main}}"
    timestamp=$(gdate +"%Y-%m-%d %H:%M:%S")

    case "$level" in
        error) color="${COLORS[RED]}" ;;
        success) color="${COLORS[GREEN]}" ;;
        warning) color="${COLORS[YELLOW]}" ;;
        info) color="${COLORS[BLUE]}" ;;
        debug) color="${COLORS[MAGENTA]}" ;;
    esac

    # Check if the current log level should be displayed based on verbosity
    case "$VERBOSITY" in
        debug) ;;
        info) [[ "$level" == "debug" ]] && return ;;
        warning) [[ "$level" == "debug" || "$level" == "info" ]] && return ;;
        error) [[ "$level" != "error" ]] && return ;;
        success) [[ "$level" != "success" && "$level" != "error" ]] && return ;;
    esac

    local log_message="[${caller_func}] ${message}"

    if [[ "$LOG_TO_TERMINAL" == true ]]; then
        echo -e "${color}${timestamp} - ${level^^}: ${log_message}${COLORS[RESET]}" >&2
    fi

    echo "$timestamp - ${level^^}: $log_message" >> "$LOG_FILE"
}

# Shorthand logging functions
log_success() { log "$1" "success"; }
log_error() { log "$1" "error"; }
log_warning() { log "$1" "warning"; }
log_info() { log "$1" "info"; }
log_debug() { log "$1" "debug"; }

# Ensure the log file exists and is writable
ensure_log_file() {
    if [[ ! -f $LOG_FILE ]]; then
        touch "$LOG_FILE" 2>/dev/null || {
            log_error "Error: Unable to create log file at $LOG_FILE."
            log_error "Please check permissions or specify a different path."
            exit 1
        }
    elif [[ ! -w $LOG_FILE ]]; then
        log_error "Error: Log file $LOG_FILE exists but is not writable."
        log_error "Please check file permissions."
        exit 1
    fi
}

# Retry mechanism for running commands with retries upon failure
retry_command() {
    local attempts=0
    local max_attempts="$RETRY_ATTEMPTS"
    local delay="$RETRY_INTERVAL"
    local command="$*"

    log_debug "Executing command: $command"

    until [[ $attempts -ge $max_attempts ]]; do
        if output=$("$@" 2>&1); then
            log_debug "Command succeeded"
            echo "$output"
            return 0
        fi
        attempts=$((attempts + 1))
        log_debug "Command failed: attempt $attempts of $max_attempts. Retrying in $delay seconds..."
        log_debug "Command output: $output"
        sleep "$delay"
    done

    log_debug "Command failed after $max_attempts attempts."
    log_debug "Final command output: $output"
    #return 1
}

# Check API connectivity and get ping time
check_api_connectivity() {
    local start_time
    local end_time
    local duration
    local response

    start_time=$(gdate +%s%N)
    response=$(curl -s -o /dev/null -w "%{http_code}" -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer ${ZONE_API_TOKEN}" \
        -H "Content-Type: application/json")
    end_time=$(gdate +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))

    if [[ "$response" == "200" ]]; then
        echo "${COLORS[GREEN]}${COLORS[BOLD]}OK${COLORS[RESET]} (ping ${duration} ms)"
        log_debug
    else
        echo "Failed"
        log_error
    fi
}

# Get current IPv4 and IPv6 addresses
get_current_ips() {
    local ipv4
    local ipv6
    ipv4=$(curl -s https://ipv4.icanhazip.com)
    ipv6=$(curl -s https://ipv6.icanhazip.com)
    echo "Current IPv4: ${ipv4:-Not available}"
    echo "Current IPv6: ${ipv6:-Not available}"
}

#==============================================================================
# YAML PARSING
#==============================================================================

# Load and parse the YAML configuration file
load_yaml() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    if ! command -v yq &> /dev/null; then
        log_error "yq is not installed. Please install yq to parse YAML files."
        exit 1
    fi

    # Helper function to remove quotes from yq output
    remove_quotes() {
        echo "$1" | sed -e 's/^"//' -e 's/"$//'
    }

    # Load main configuration settings
    ZONE_ID=$(remove_quotes "$(yq .cloudflare.zone_id "$config_file")")
    ZONE_API_TOKEN=$(remove_quotes "$(yq .cloudflare.zone_api_token "$config_file")")
    ENABLE_CREATE_RECORD=$(yq '.globals.enable_create_record // false' "$config_file")
    RETRY_ATTEMPTS=$(yq .advanced.retry_attempts "$config_file")
    RETRY_INTERVAL=$(yq .advanced.retry_interval "$config_file")
    MAX_PARALLEL_JOBS=$(yq .advanced.max_parallel_jobs "$config_file")
    LOG_FILE=$(remove_quotes "$(yq .logging.file "$config_file")")
    LOG_TO_TERMINAL=$(yq .logging.terminal_output "$config_file")
    VERBOSITY=$(yq .logging.verbosity "$config_file")

    # Load global settings
    GLOBAL_IPV4=$(yq '.globals.ipv4 // true' "$config_file")
    GLOBAL_IPV6=$(yq '.globals.ipv6 // true' "$config_file")
    GLOBAL_PROXIED=$(yq '.globals.proxied // true' "$config_file")
    GLOBAL_TTL=$(yq '.globals.ttl // 1' "$config_file")

    log_debug "Global settings: IPv4=$GLOBAL_IPV4, IPv6=$GLOBAL_IPV6, Proxied=$GLOBAL_PROXIED, TTL=$GLOBAL_TTL"

    # Load domains
    DOMAINS=$(yq '.domains[].name' "$config_file" | tr '\n' ',' | sed 's/,$//' | sed -e 's/"//g')

    # Load notification settings
    load_notification_settings "$config_file"

    log_debug "Configuration loaded from $config_file"
    log_debug "ENABLE_CREATE_RECORD set to: $ENABLE_CREATE_RECORD"
}

# Load notification settings from the configuration file
load_notification_settings() {
    local config_file="$1"

    if [[ $(yq .notifications.telegram.enabled "$config_file") == "true" ]]; then
        NOTIFICATION_PLUGINS["telegram"]=true
        TELEGRAM_BOT_TOKEN=$(remove_quotes "$(yq .notifications.telegram.bot_token "$config_file")")
        TELEGRAM_CHAT_ID=$(remove_quotes "$(yq .notifications.telegram.chat_id "$config_file")")
    fi

    if [[ $(yq .notifications.email.enabled "$config_file") == "true" ]]; then
        NOTIFICATION_PLUGINS["email"]=true
        notifications_email_smtp_server=$(remove_quotes "$(yq .notifications.email.smtp_server "$config_file")")
        notifications_email_smtp_port=$(remove_quotes "$(yq .notifications.email.smtp_port "$config_file")")
        notifications_email_use_ssl=$(yq .notifications.email.use_ssl "$config_file")
        notifications_email_username=$(remove_quotes "$(yq .notifications.email.username "$config_file")")
        notifications_email_password=$(remove_quotes "$(yq .notifications.email.password "$config_file")")
        notifications_email_from_address=$(remove_quotes "$(yq .notifications.email.from_address "$config_file")")
        notifications_email_to_address=$(remove_quotes "$(yq .notifications.email.to_address "$config_file")")
    fi

    if [[ $(yq .notifications.slack.enabled "$config_file") == "true" ]]; then
        NOTIFICATION_PLUGINS["slack"]=true
        notifications_slack_webhook_url=$(remove_quotes "$(yq .notifications.slack.webhook_url "$config_file")")
    fi

    if [[ $(yq .notifications.discord.enabled "$config_file") == "true" ]]; then
        NOTIFICATION_PLUGINS["discord"]=true
        notifications_discord_webhook_url=$(remove_quotes "$(yq .notifications.discord.webhook_url "$config_file")")
    fi
}

#==============================================================================
# DNS MANAGEMENT
#==============================================================================

# Get IP address (IPv4 or IPv6)
get_ip() {
    local ip_type="$1"
    local url="https://${ip_type}.icanhazip.com"

    local ip
    ip=$(curl -s "$url") || { log_error "Failed to get $ip_type"; return 1; }
    echo "$ip"
}

# Get DNS record information from Cloudflare
get_record_info() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"

    local api_url="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}&type=${record_type}"
    log_debug "API URL for get_record_info: $api_url"
    
    local response
    response=$(curl -s -X GET "$api_url" \
        -H "Authorization: Bearer ${ZONE_API_TOKEN}" \
        -H "Content-Type: application/json")

    if [[ "$(echo "$response" | jq -r '.success')" != "true" ]]; then
        local error_message
        error_message=$(echo "$response" | jq -r '.errors[0].message')
        log_error "Failed to get record info for ${record_name} (${record_type}): $error_message"
        return 1
    fi

    echo -e "$response" | jq -r '.result[0]'
}

# Delete a DNS record
delete_dns_record() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"
    local record_info
    local record_id

    record_info=$(get_record_info "$zone_id" "$record_name" "$record_type")
    record_id=$(echo "$record_info" | jq -r '.id')

    if [[ -n "$record_id" && "$record_id" != "null" ]]; then
        local response
        response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            -H "Authorization: Bearer $ZONE_API_TOKEN" \
            -H "Content-Type: application/json")

        if [[ "$(echo "$response" | jq -r '.success')" == "true" ]]; then
            echo "${record_type} record deleted"
        else
            echo "Failed to delete ${record_type} record"
        fi
    else
        echo "No ${record_type} record found"
    fi
}

# Check if a DNS record exists
check_record_exists() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"

    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${record_type}&name=${record_name}" \
        -H "Authorization: Bearer ${ZONE_API_TOKEN}" \
        -H "Content-Type: application/json")

    if [[ "$(echo "$response" | jq -r '.success')" != "true" ]]; then
        log_error "Failed to check record existence for ${record_name} (${record_type}): $(echo "$response" | jq -r '.errors[0].message')"
        return 1
    fi

    local record_count
    record_count=$(echo "$response" | jq '.result | length')
    [[ "$record_count" -gt 0 ]]
}

# Update or create a DNS record
update_dns_record() {
    local zone_id="$1"
    local record_name="$2"
    local ip="$3"
    local record_type="$4"
    local proxied="$5"
    local ttl="$6"

    if [[ "$ttl" == "auto" || "$ttl" == "1" ]]; then
        ttl="auto"
    fi

    log_debug "Input parameters: zone_id=$zone_id, record_name=$record_name, ip=$ip, record_type=$record_type, proxied=$proxied, ttl=$ttl"
    log_debug "ENABLE_CREATE_RECORD: $ENABLE_CREATE_RECORD"

    if ! check_record_exists "$zone_id" "$record_name" "$record_type"; then
        if [[ "$ENABLE_CREATE_RECORD" != "true" ]]; then
            log_error "No ${record_type} record found for ${record_name} and record creation is disabled."
            echo "error_not_found"
            return 1
        fi

        log_info "Creating new ${record_type} record for ${record_name}"
        create_dns_record "$zone_id" "$record_name" "$ip" "$record_type" "$proxied" "$ttl"
        return
    fi

    local current_record
    current_record=$(get_record_info "$zone_id" "$record_name" "$record_type")
    log_debug "Current record info: ${current_record}"

    local record_id
    local current_ip
    local current_proxied
    local current_ttl
    record_id=$(echo "$current_record" | jq -r '.id')
    current_ip=$(echo "$current_record" | jq -r '.content')
    current_proxied=$(echo "$current_record" | jq -r '.proxied')
    current_ttl=$(echo "$current_record" | jq -r '.ttl')

    if [[ "$current_ttl" == "auto" || "$current_ttl" == "1" ]]; then
        current_ttl="auto"  # Cloudflare uses 1 to represent "auto"
    fi

    local changes=""
    [[ "$ip" != "$current_ip" ]] && changes+="IP:[$current_ip->$ip] "
    [[ "$proxied" != "$current_proxied" ]] && changes+="Proxied:[$current_proxied->$proxied] "
    [[ "$ttl" != "$current_ttl" ]] && changes+="TTL:[$current_ttl->$ttl] "

    if [[ -z "$changes" ]]; then
        log_info "No changes needed for $record_name ($record_type)"
        echo "no_change"
        return 0
    fi

    log_info "Updating $record_name ($record_type): $changes"

    if [[ "$ttl" == "auto" || "$ttl" == "1" ]]; then
        ttl=1  # Cloudflare uses 1 to represent "auto"
    fi

    local payload
    payload=$(jq -n \
        --arg type "$record_type" \
        --arg name "$record_name" \
        --arg content "$ip" \
        --argjson ttl "${ttl}" \
        --argjson proxied "$proxied" \
        '{
            "type": $type,
            "name": $name,
            "content": $content,
            "ttl": $ttl,
            "proxied": $proxied,
        }')

    log_debug "Payload for update_dns_record: $payload"

    local url="https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id"
    log_debug "API URL: $url"

    local response
    response=$(retry_command curl -s -X PUT "$url" \
        -H "Authorization: Bearer $ZONE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$payload")

    log_debug "API Response: $response"

    if [[ "$(echo "$response" | jq -r '.success')" != "true" ]]; then
        local error_message
        error_message=$(jq -r '.errors[0].message // "Unknown error"' <<<"$response")
        log_error "Failed to update DNS record for $record_name: $error_message"
        echo "error"
        return 1
    fi

    log_info "DNS record for ${record_name} updated successfully with changes: ${changes}"

    echo "${changes%,}"
    return 0
}

# Create a new DNS record
create_dns_record() {
    local zone_id="$1"
    local record_name="$2"
    local ip="$3"
    local record_type="$4"
    local proxied="$5"
    local ttl="$6"

    if [[ "$ttl" == "auto" || "$ttl" == "1" ]]; then
        ttl=1  # Cloudflare uses 1 to represent "auto"
    fi

    local create_payload
    create_payload=$(jq -n \
        --arg type "$record_type" \
        --arg name "$record_name" \
        --arg content "$ip" \
        --argjson ttl "$ttl" \
        --argjson proxied "$proxied" \
        '{
            "type": $type,
            "name": $name,
            "content": $content,
            "ttl": $ttl,
            "proxied": $proxied,
        }')

    log_debug "Payload for create_dns_record: $create_payload"

    local url="https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records"
    log_debug "API URL (create new record): $url"

    local create_response
    create_response=$(retry_command curl -s -X POST "$url" \
        -H "Authorization: Bearer $ZONE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$create_payload")

    log_debug "API Response: $create_response"

    if [[ "$(echo "$create_response" | jq -r '.success')" != "true" ]]; then
        log_error "Failed to create ${record_type} record for ${record_name}: $(echo "$create_response" | jq -r '.errors[0].message')"
        echo "error_create"
        return 1
    fi

    log_success "${record_type} record for ${record_name} created successfully."
    echo "created"
    return 0
}

#==============================================================================
# NOTIFICATION SYSTEM
#==============================================================================

# Send notifications through configured channels
send_notification() {
    local message="$1"
    local plugin

    for plugin in "${!NOTIFICATION_PLUGINS[@]}"; do
        if [[ "${NOTIFICATION_PLUGINS[$plugin]}" == "true" ]]; then
            "notify_${plugin}" "$message"
        fi
    done
}

# Telegram notification
notify_telegram() {
    local message="$1"
    local bot_token="$TELEGRAM_BOT_TOKEN"
    local chat_id="$TELEGRAM_CHAT_ID"

    if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        log_error "Telegram notification failed: Missing bot token or chat ID"
        return 1
    fi

    local response
    response=$(curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
        -d "chat_id=$chat_id&text=$message")

    if [[ "$(echo "$response" | jq -r '.ok')" != "true" ]]; then
        log_error "Failed to send Telegram notification: $(echo "$response" | jq -r '.description')"
    else
        log_success "Telegram notification sent successfully."
    fi
}

# Email notification
notify_email() {
    local message="$1"
    local smtp_server="${notifications_email_smtp_server}"
    local smtp_port="${notifications_email_smtp_port}"
    local use_ssl="${notifications_email_use_ssl}"
    local username="${notifications_email_username}"
    local password="${notifications_email_password}"
    local from_address="${notifications_email_from_address}"
    local to_address="${notifications_email_to_address}"
    local subject="${notifications_email_subject:-Cloudflare DNS Update Notification}"

    if [[ -z "$smtp_server" || -z "$smtp_port" || -z "$username" || -z "$password" || -z "$from_address" || -z "$to_address" ]]; then
        log_error "Email notification failed: Missing required email configuration"
        return 1
    fi

    # Construct the email message
    local email_content="Subject: $subject
From: $from_address
To: $to_address

$message"

    # Send email using netcat
    if [[ "$use_ssl" == "true" ]]; then
        echo -e "$email_content" | openssl s_client -quiet -connect "$smtp_server:$smtp_port" -ign_eof
    else
        (
            echo "EHLO localhost"
            echo "AUTH LOGIN"
            echo -n "$username" | base64
            echo -n "$password" | base64
            echo "MAIL FROM: <$from_address>"
            echo "RCPT TO: <$to_address>"
            echo "DATA"
            echo "$email_content"
            echo "."
            echo "QUIT"
        ) | nc "$smtp_server" "$smtp_port"
    fi

    if mycmd; then
        log_success "Email notification sent successfully."
    else
        log_error "Failed to send email notification."
    fi
}

# Slack notification
notify_slack() {
    local message="$1"
    local webhook_url="${notifications_slack_webhook_url}"

    if [[ -z "$webhook_url" ]]; then
        log_error "Slack notification failed: Missing webhook URL"
        return 1
    fi

    local payload
    payload=$(jq -n \
        --arg text "$message" \
        '{"text": $text}')

    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url")

    if [[ "$response" == "ok" ]]; then
        log_success "Slack notification sent successfully."
    else
        log_error "Failed to send Slack notification: $response"
    fi
}

# Discord notification
notify_discord() {
    local message="$1"
    local webhook_url="${notifications_discord_webhook_url}"

    if [[ -z "$webhook_url" ]]; then
        log_error "Discord notification failed: Missing webhook URL"
        return 1
    fi

    local payload
    payload=$(jq -n \
        --arg content "$message" \
        '{"content": $content}')

    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url")

    if [[ -z "$response" ]]; then
        log_success "Discord notification sent successfully."
    else
        log_error "Failed to send Discord notification: $response"
    fi
}

#==============================================================================
# DOMAIN PROCESSING
#==============================================================================

# Process a single domain
process_domain() {
    local domain_name="$1"
    local zone_id="$2"
    local ipv4_enabled="$3"
    local ipv6_enabled="$4"
    local proxied="$5"
    local ttl="$6"

    local start_time
    start_time=$(gdate +%s%N)
    local ipv4_changes=""
    local ipv6_changes=""
    local proxied_changes=""
    local ttl_changes=""

    if [[ "$ipv4_enabled" == "true" ]]; then
        ipv4_changes=$(update_dns_record "$zone_id" "$domain_name" "$(get_ip ipv4)" "A" "$proxied" "$ttl")
        log_debug "IPv4 changes: $ipv4_changes"
    else
        ipv4_changes="Disabled"
        delete_dns_record "$zone_id" "$domain_name" "A"
    fi

    if [[ "$ipv6_enabled" == "true" ]]; then
        ipv6_changes=$(update_dns_record "$zone_id" "$domain_name" "$(get_ip ipv6)" "AAAA" "$proxied" "$ttl")
        log_debug "IPv6 changes: $ipv6_changes"
    else
        ipv6_changes="Disabled"
        delete_dns_record "$zone_id" "$domain_name" "AAAA"
    fi

    # Extraer cambios de Proxied y TTL
    if [[ "$ipv4_changes" != "no_change" && "$ipv4_changes" != "Disabled" ]]; then
        proxied_changes=$(echo "$ipv4_changes" | grep -o "Proxied:[^,]*" | cut -d':' -f2 || echo "")
        ttl_changes=$(echo "$ipv4_changes" | grep -o "TTL:[^,]*" | cut -d':' -f2 || echo "")
    elif [[ "$ipv6_changes" != "no_change" && "$ipv6_changes" != "Disabled" ]]; then
        proxied_changes=$(echo "$ipv6_changes" | grep -o "Proxied:[^,]*" | cut -d':' -f2 || echo "")
        ttl_changes=$(echo "$ipv6_changes" | grep -o "TTL:[^,]*" | cut -d':' -f2 || echo "")
    fi

    log_debug "Proxied changes: $proxied_changes"
    log_debug "TTL changes: $ttl_changes"

    local end_time=
    end_time=$(gdate +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    # Registrar los cambios en el archivo temporal
    echo "$domain_name:$ipv4_changes:$ipv6_changes:$proxied_changes:$ttl_changes:$ipv4_enabled:$ipv6_enabled:$duration" >> "$TEMP_CHANGES_FILE"

    log_debug "Current content of changes temporal file:
    $(awk '{print "\t\t" $0}' "$TEMP_CHANGES_FILE")"

    print_domain_status "$domain_name" "$ipv4_changes" "$ipv6_changes" "$proxied_changes" "$ttl_changes" "$duration"
}

# Process domains sequentially
process_domains_sequential() {
    local domains=("$@")
    local domain_config=""
    local ipv4_enabled=""
    local ipv6_enabled=""
    local proxied=""
    local ttl=""

    for domain in "${domains[@]}"; do
        domain_config=$(yq ".domains[] | select(.name == \"$domain\")" "$CONFIG_FILE")
        ipv4_enabled=$(echo "$domain_config" | yq ".ipv4 // \"$GLOBAL_IPV4\"")
        ipv6_enabled=$(echo "$domain_config" | yq ".ipv6 // \"$GLOBAL_IPV6\"")
        proxied=$(echo "$domain_config" | yq ".proxied // \"$GLOBAL_PROXIED\"")
        ttl=$(echo "$domain_config" | yq ".ttl // \"$GLOBAL_TTL\"")

        # Convert empty strings and "null" to global values
        [[ -z "$ipv4_enabled" || "$ipv4_enabled" == "null" ]] && ipv4_enabled="$GLOBAL_IPV4"
        [[ -z "$ipv6_enabled" || "$ipv6_enabled" == "null" ]] && ipv6_enabled="$GLOBAL_IPV6"
        [[ -z "$proxied" || "$proxied" == "null" ]] && proxied="$GLOBAL_PROXIED"
        [[ -z "$ttl" || "$ttl" == "null" ]] && ttl="$GLOBAL_TTL"

        # Remove quotes if present
        ipv4_enabled=$(echo "$ipv4_enabled" | tr -d '"')
        ipv6_enabled=$(echo "$ipv6_enabled" | tr -d '"')
        proxied=$(echo "$proxied" | tr -d '"')
        ttl=$(echo "$ttl" | tr -d '"')

        log_debug "Processing ${domain}: IPv4=$ipv4_enabled, IPv6=$ipv6_enabled, Proxied=$proxied, TTL=$ttl"

        process_domain "$domain" "$ZONE_ID" "$ipv4_enabled" "$ipv6_enabled" "$proxied" "$ttl"
    done
}

# Print formatted status for a domain
print_domain_status() {
    local domain="$1"
    local ipv4_changes="$2"
    local ipv6_changes="$3"
    local proxied_changes="$4"
    local ttl_changes="$5"
    local duration="$6"

    local ipv4_status="·"
    local ipv6_status="·"
    local proxied_status="·"
    local ttl_status="·"

    [[ "$ipv4_changes" != "no_change" && "$ipv4_changes" != "Disabled" ]] && ipv4_status="+"
    [[ "$ipv6_changes" != "no_change" && "$ipv6_changes" != "Disabled" ]] && ipv6_status="+"
    [[ "$ipv4_changes" == "Disabled" ]] && ipv4_status="-"
    [[ "$ipv6_changes" == "Disabled" ]] && ipv6_status="-"
    [[ -n "$proxied_changes" ]] && proxied_status="+"
    [[ -n "$ttl_changes" ]] && ttl_status="+"

    # Function to get color for status
    get_color() {
        case "$1" in
            "·") echo -n "${COLORS[GRAY]}${COLORS[BOLD]}" ;;
            "+") echo -n "${COLORS[GREEN]}${COLORS[BOLD]}" ;;
            "-") echo -n "${COLORS[RED]}${COLORS[BOLD]}" ;;
            *) echo -n "${COLORS[RESET]}${COLORS[BOLD]}" ;;
        esac
    }

    local formatted_output
    formatted_output=$(printf "%-30s %sIPv4%s %sIPv6%s %sProxied%s %sTTL%s | Time elapsed: %d ms\n" \
        "$domain:" \
        "$(get_color "$ipv4_status")$ipv4_status" "${COLORS[RESET]}" \
        "$(get_color "$ipv6_status")$ipv6_status" "${COLORS[RESET]}" \
        "$(get_color "$proxied_status")$proxied_status" "${COLORS[RESET]}" \
        "$(get_color "$ttl_status")$ttl_status" "${COLORS[RESET]}" \
        "$duration")

    echo -e "$formatted_output"
}

# Process domains in parallel
process_domains_parallel() {
    local domains=("$@")
    local temp_dir
    temp_dir=$(mktemp -d)
    local pid
    local pids=()
    local domain_config=""
    local ipv4_enabled=""
    local ipv6_enabled=""
    local proxied=""
    local ttl=""

    for domain in "${domains[@]}"; do
        domain_config=$(yq ".domains[] | select(.name == \"$domain\")" "$CONFIG_FILE")
        ipv4_enabled=$(echo "$domain_config" | yq ".ipv4 // \"$GLOBAL_IPV4\"")
        ipv6_enabled=$(echo "$domain_config" | yq ".ipv6 // \"$GLOBAL_IPV6\"")
        proxied=$(echo "$domain_config" | yq ".proxied // \"$GLOBAL_PROXIED\"")
        ttl=$(echo "$domain_config" | yq ".ttl // \"$GLOBAL_TTL\"")

        # Convert empty strings and "null" to global values
        [[ -z "$ipv4_enabled" || "$ipv4_enabled" == "null" ]] && ipv4_enabled="$GLOBAL_IPV4"
        [[ -z "$ipv6_enabled" || "$ipv6_enabled" == "null" ]] && ipv6_enabled="$GLOBAL_IPV6"
        [[ -z "$proxied" || "$proxied" == "null" ]] && proxied="$GLOBAL_PROXIED"
        [[ -z "$ttl" || "$ttl" == "null" ]] && ttl="$GLOBAL_TTL"

        # Remove quotes if present
        ipv4_enabled=$(echo "$ipv4_enabled" | tr -d '"')
        ipv6_enabled=$(echo "$ipv6_enabled" | tr -d '"')
        proxied=$(echo "$proxied" | tr -d '"')
        ttl=$(echo "$ttl" | tr -d '"')

        log_debug "Processing ${domain}: IPv4=$ipv4_enabled, IPv6=$ipv6_enabled, Proxied=$proxied, TTL=$ttl"

        process_domain "$domain" "$ZONE_ID" "$ipv4_enabled" "$ipv6_enabled" "$proxied" "$ttl" > "$temp_dir/$domain" &
        pids+=($!)

        # Wait if we've reached the maximum number of parallel jobs
        while [[ ${#pids[@]} -ge $MAX_PARALLEL_JOBS ]]; do
            for pid in "${pids[@]}"; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    wait "$pid"
                    pids=("${pids[@]/$pid}")
                    break
                fi
            done
            sleep 0.1
        done
    done

    # Wait for remaining processes to finish
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # Print results in order
    for domain in "${domains[@]}"; do
        cat "$temp_dir/$domain"
    done

    rm -rf "$temp_dir"
}

# Run in test mode (dry run)
test_mode() {
    local ipv4
    local ipv6
    log_info "Running in test mode (dry run)"
    for domain in ${DOMAINS//,/ }; do
        log_info "Would update DNS records for domain: $domain"
        if [[ "$UPDATE_IPV4" == "true" ]]; then
            ipv4=$(get_ip "ipv4")
            log_info "Would update A record for $domain with IP: $ipv4"
        fi
        if [[ "$UPDATE_IPV6" == "true" ]]; then
            ipv6=$(get_ip "ipv6")
            log_info "Would update AAAA record for $domain with IP: $ipv6"
        fi
    done
    log_info "Test mode completed. No changes were made."
}

#==============================================================================
# HELP AND USAGE
#==============================================================================

# Display version information
show_version() {
    echo "Cloudflare DNS Updater v$VERSION"
}

# Display brief help information
show_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  update                  Update DNS records for specified domains
  test                    Run in test mode (dry run) without making changes
  help                    Show this help message and exit

Options:
  -h, --help              Show this help message and exit
  -c, --config FILE       Specify the configuration file (default: $CONFIG_FILE)
  -q, --quiet             Disable terminal output
  -vv, --verbosity        Set terminal log verbosity level
  -p, --parallel NUM      Set the maximum number of parallel jobs (default: $MAX_PARALLEL_JOBS)
  --version               Show version information and exit

Update command options:
  --zone-id ID            Cloudflare Zone ID
  --token TOKEN           Cloudflare API Token
  --domains D1,D2,...     Comma-separated list of domains to update
  --ipv4 BOOL             Update IPv4 records (default: $DEFAULT_GLOBAL_IPV4)
  --ipv6 BOOL             Update IPv6 records (default: $DEFAULT_GLOBAL_IPV6)
  --proxied BOOL          Enable Cloudflare proxying (default: $DEFAULT_GLOBAL_PROXIED)
  --ttl NUM               Set TTL for DNS records (default: $DEFAULT_GLOBAL_TTL)
  --create-record BOOL    Enable creation of missing records (default: $DEFAULT_ENABLE_CREATE_RECORD)

Environment variables:
  CF_API_TOKEN            Cloudflare API Token (overrides config file and --token)
  CF_ZONE_ID              Cloudflare Zone ID (overrides config file and --zone-id)

For more detailed information, use '$0 help'.
EOF
}

# Display extended help information
show_extended_help() {
    cat << EOF
Cloudflare DNS Updater v$VERSION

DESCRIPTION
    This script updates DNS records for specified domains using the Cloudflare API.
    It supports both IPv4 and IPv6 records and can be configured using a YAML file.

USAGE
    $0 [COMMAND] [OPTIONS]

COMMANDS
    update              Update DNS records for specified domains
    test                Run in test mode (dry run) without making changes
    help                Show this help message and exit

OPTIONS
    -h, --help          Show this help message and exit
    -c, --config FILE   Specify the configuration file (default: $CONFIG_FILE)
    -q, --quiet         Disable terminal output
    -vv, --verbosity    Set terminal log verbosity level
    -p, --parallel NUM  Set the maximum number of parallel jobs (default: $MAX_PARALLEL_JOBS)
    --version           Show version information and exit

    Update command options:
    --zone-id ID        Cloudflare Zone ID
    --token TOKEN       Cloudflare API Token
    --domains D1,D2,... Comma-separated list of domains to update
    --ipv4 BOOL         Update IPv4 records (default: $DEFAULT_GLOBAL_IPV4)
    --ipv6 BOOL         Update IPv6 records (default: $DEFAULT_GLOBAL_IPV6)
    --proxied BOOL      Enable Cloudflare proxying (default: $DEFAULT_GLOBAL_PROXIED)
    --ttl NUM           Set TTL for DNS records (default: $DEFAULT_GLOBAL_TTL)
    --create-record BOOL Enable creation of missing records (default: $DEFAULT_ENABLE_CREATE_RECORD)

ENVIRONMENT VARIABLES
    CF_API_TOKEN        Cloudflare API Token (overrides config file and --token)
    CF_ZONE_ID          Cloudflare Zone ID (overrides config file and --zone-id)

CONFIGURATION
    The script can be configured using a YAML file (default: $CONFIG_FILE).
    See the example configuration file for details on available options.

WORKFLOW
    ┌─────────────────┐
    │  Start Script   │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  Parse Config   │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │ Validate Input  │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │ Process Domains │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  Update DNS     │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │   Notify        │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │    Finish       │
    └─────────────────┘

EXAMPLES
    Update DNS records using a custom config file:
    $0 update -c my_config.yaml

    Run in test mode:
    $0 test

    Update specific domains:
    $0 update --domains example.com,subdomain.example.com

    Use environment variables for sensitive data:
    CF_API_TOKEN=your_token CF_ZONE_ID=your_zone_id $0 update

For more information about the Cloudflare API, visit: https://api.cloudflare.com/
EOF
}

#==============================================================================
# INPUT VALIDATION
#==============================================================================

# Validate configuration settings
validate_config() {
    if [[ -z "$ZONE_ID" ]]; then
        log_error "Cloudflare Zone ID is missing. Use --zone-id option, set it in the config file, or use CF_ZONE_ID environment variable."
        exit 1
    fi

    if [[ -z "$ZONE_API_TOKEN" ]]; then
        log_error "Cloudflare API Token is missing. Use --token option, set it in the config file, or use CF_API_TOKEN environment variable."
        exit 1
    fi

    if [[ -z "$DOMAINS" ]]; then
        log_error "No domains specified. Use --domains option or set them in the config file."
        exit 1
    fi

    # Validate boolean values
    local var
    for var in UPDATE_IPV4 UPDATE_IPV6 GLOBAL_PROXIED ENABLE_CREATE_RECORD; do
        if [[ "${!var}" != "true" && "${!var}" != "false" ]]; then
            log_error "Invalid value for $var. Must be 'true' or 'false'."
            exit 1
        fi
    done

    # Validate TTL
    if [[ "$TTL" == "auto" || "$TTL" == "1" ]]; then
        TTL=1  # Cloudflare uses 1 to represent "auto"
    elif ! [[ "$TTL" =~ ^[0-9]+$ ]] || [[ "$TTL" -lt 120 || "$TTL" -gt 7200 ]]; then
        log_error "Invalid TTL value. Must be 'auto', 1, or an integer between 120 and 7200."
        exit 1
    fi

    log_debug "Configuration validated successfully"
}

#==============================================================================
# MAIN FUNCTION
#==============================================================================

main() {
    local command=""

    # Set default values
    UPDATE_IPV4="$DEFAULT_GLOBAL_IPV4"
    UPDATE_IPV6="$DEFAULT_GLOBAL_IPV6"
    GLOBAL_PROXIED="$DEFAULT_GLOBAL_PROXIED"
    TTL="$DEFAULT_GLOBAL_TTL"
    ENABLE_CREATE_RECORD="$DEFAULT_ENABLE_CREATE_RECORD"
    DOMAINS=""
    
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            update|test|help)
                command="$1"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -q|--quiet)
                LOG_TO_TERMINAL=false
                shift
                ;;
            -vv|--verbosity)
                VERBOSITY="$2"
                shift 2
                ;;
            -p|--parallel)
                MAX_PARALLEL_JOBS="$2"
                shift 2
                ;;
            --version)
                show_version
                exit 0
                ;;
            --zone-id)
                ZONE_ID="$2"
                shift 2
                ;;
            --token)
                ZONE_API_TOKEN="$2"
                shift 2
                ;;
            --domains)
                DOMAINS="$2"
                shift 2
                ;;
            --ipv4)
                UPDATE_IPV4="$2"
                shift 2
                ;;
            --ipv6)
                UPDATE_IPV6="$2"
                shift 2
                ;;
            --proxied)
                GLOBAL_PROXIED="$2"
                shift 2
                ;;
            --ttl)
                TTL="$2"
                shift 2
                ;;
            --create-record)
                CLI_ENABLE_CREATE_RECORD="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Handle help command immediately
    if [[ "$command" == "help" ]]; then
        show_extended_help
        exit 0
    fi

    # Load configuration from YAML file if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        load_yaml "$CONFIG_FILE"
    fi

    # Remove any quotes from the log file path
    LOG_FILE=${LOG_FILE//\"}

    # Ensure log file exists
    ensure_log_file

    # Override with environment variables if set
    ZONE_ID="${CF_ZONE_ID:-$ZONE_ID}"
    ZONE_API_TOKEN="${CF_API_TOKEN:-$ZONE_API_TOKEN}"

    # Override ENABLE_CREATE_RECORD if specified in command line
    if [[ -n "$CLI_ENABLE_CREATE_RECORD" ]]; then
        ENABLE_CREATE_RECORD="$CLI_ENABLE_CREATE_RECORD"
    fi

    # Ensure ENABLE_CREATE_RECORD is either "true" or "false"
    ENABLE_CREATE_RECORD=$(echo "$ENABLE_CREATE_RECORD" | tr '[:upper:]' '[:lower:]')
    if [[ "$ENABLE_CREATE_RECORD" != "true" && "$ENABLE_CREATE_RECORD" != "false" ]]; then
        ENABLE_CREATE_RECORD="false"
    fi

    log_debug "Final ENABLE_CREATE_RECORD value: $ENABLE_CREATE_RECORD"

    # Validate configuration
    validate_config

    # Create a temporary file to store changes
    TEMP_CHANGES_FILE=$(mktemp)

    # Execute the appropriate command
    case "$command" in
        update)
            # Display status
            echo "=== Status ==="
            get_current_ips
            echo -n "Connection with API: "
            check_api_connectivity
            echo

            # Display domains to be processed
            echo "=== Domains to be processed ==="
            display_domains_to_process

            # Process domains
            echo "=== Running ==="
            echo -e "Legend: ${COLORS[GREEN]}${COLORS[BOLD]}[+]${COLORS[RESET]} Updated | ${COLORS[GRAY]}${COLORS[BOLD]}[·]${COLORS[RESET]} No changes needed | ${COLORS[RED]}${COLORS[BOLD]}[-]${COLORS[RESET]} Disabled"
            echo

            # Process one by one. Parallel generate problems to log.
            process_domains_sequential "${DOMAIN_ARRAY[@]}"

            #send_notification "DNS records have been updated."
            log_info "DNS update process completed successfully"

            # Display detailed summary
            display_summary

            # Clean up temporary file
            #rm -f "$TEMP_CHANGES_FILE"
            echo "$TEMP_CHANGES_FILE"
            ;;
        test)
            test_mode
            ;;
        "")
            log_error "No command specified. Use 'update', 'test', or 'help'."
            show_help
            exit 1
            ;;
        *)
            log_error "Invalid command. Use 'update', 'test', or 'help'."
            show_help
            exit 1
            ;;
    esac
}

# Display domains to be processed
display_domains_to_process() {
    local domain_config
    local ipv4_enabled
    local ipv6_enabled
    local proxied
    local ttl

    local index=1
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        domain_config=$(yq ".domains[] | select(.name == \"$domain\")" "$CONFIG_FILE")
        ipv4_enabled=$(echo "$domain_config" | yq ".ipv4 // \"$GLOBAL_IPV4\"")
        ipv6_enabled=$(echo "$domain_config" | yq ".ipv6 // \"$GLOBAL_IPV6\"")
        proxied=$(echo "$domain_config" | yq ".proxied // \"$GLOBAL_PROXIED\"")
        ttl=$(echo "$domain_config" | yq ".ttl // \"$GLOBAL_TTL\"")

        # Remove quotes if present
        ipv4_enabled=$(echo "$ipv4_enabled" | tr -d '"')
        ipv6_enabled=$(echo "$ipv6_enabled" | tr -d '"')
        proxied=$(echo "$proxied" | tr -d '"')
        ttl=$(echo "$ttl" | tr -d '"')

        # Construct the settings string
        local settings=""
        [[ "$ipv4_enabled" == "true" ]] && settings+="IPv4, "
        [[ "$ipv6_enabled" == "true" ]] && settings+="IPv6, "
        [[ "$proxied" == "true" ]] && settings+="Proxied, "
        settings+="TTL: $ttl"

        # Check if using global settings
        local global_indicator=""
        if [[ -z "$(echo "$domain_config" | yq '.ipv4')" && \
              -z "$(echo "$domain_config" | yq '.ipv6')" && \
              -z "$(echo "$domain_config" | yq '.proxied')" && \
              -z "$(echo "$domain_config" | yq '.ttl')" ]]; then
            global_indicator=" (using global settings)"
        fi

        printf "%d. %-30s -> %s%s\n" \
            "$index" "$domain" \
            "$settings" \
            "$global_indicator"
        ((index++))
    done
}

# Display detailed summary of changes
display_summary() {
    echo -e "\n${COLORS[CYAN]}==== Summary ====${COLORS[RESET]}"
    echo "Total domains processed: ${#DOMAIN_ARRAY[@]}"
    echo "Create missing records: $ENABLE_CREATE_RECORD"
    echo "Details:"

    if [[ ! -f "$TEMP_CHANGES_FILE" ]]; then
        echo "Error: Temporary changes file not found."
        return 1
    fi

    if [[ ! -s "$TEMP_CHANGES_FILE" ]]; then
        echo "No changes were recorded."
        return 0
    fi

    while IFS=: read -r domain ipv4_changes ipv6_changes proxied_changes ttl_changes ipv4_enabled ipv6_enabled duration || [[ -n "$domain" ]]; do
        log_debug "Processing domain: $domain"

        if [[ -z "$domain" ]]; then
            echo "Error: Empty domain name encountered." >&2
            continue
        fi

        echo -n "  $domain: "
        if [[ "$ipv4_changes" == "no_change" && "$ipv6_changes" == "no_change" && -z "$proxied_changes" && -z "$ttl_changes" ]]; then
            echo "👍 No changes needed."
        else
            echo "👍 Updated!"
            if [[ "$ipv4_enabled" == "true" && "$ipv4_changes" != "no_change" ]]; then
                echo "      - IPv4: $ipv4_changes"
            elif [[ "$ipv4_enabled" == "false" ]]; then
                echo "      - IPv4: Disabled"
            fi
            if [[ "$ipv6_enabled" == "true" && "$ipv6_changes" != "no_change" ]]; then
                echo "      - IPv6: $ipv6_changes"
            elif [[ "$ipv6_enabled" == "false" ]]; then
                echo "      - IPv6: Disabled"
            fi
            if [[ -n "$proxied_changes" ]]; then
                echo "      - Proxied: $proxied_changes"
            fi
            if [[ -n "$ttl_changes" ]]; then
                echo "      - TTL: $ttl_changes"
            fi
        fi
    done < "$TEMP_CHANGES_FILE"

    echo "Summary display completed." >&2  # Debug output
}

# Start the script with the main function
main "$@"