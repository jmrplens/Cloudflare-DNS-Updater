#!/usr/bin/env bash

# This function parses the YAML config file using awk and exports variables.
# It is designed to handle the specific structure of the cloudflare-dns.yaml file.
# It creates arrays for domains:
# domains__name[], domains__proxied[], domains__ipv4[], etc.

parse_config() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        log_error "Config file not found: $yaml_file"
        return 1
    fi

    # Check for syntax errors (basic)
    if grep -q $'\t' "$yaml_file"; then
        log_warn "Config file contains tabs. YAML forbids tabs. Proceeding, but parsing might fail."
    fi

    # Parse Global Settings
    CF_ZONE_ID=$(grep "zone_id:" "$yaml_file" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')
    CF_API_TOKEN=$(grep "zone_api_token:" "$yaml_file" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')
    
    TG_ENABLED=$(grep -A 5 "telegram:" "$yaml_file" | grep "enabled:" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')
    TG_BOT_TOKEN=$(grep -A 5 "telegram:" "$yaml_file" | grep "bot_token:" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')
    TG_CHAT_ID=$(grep -A 5 "telegram:" "$yaml_file" | grep "chat_id:" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')

    DISCORD_ENABLED=$(grep -A 5 "discord:" "$yaml_file" | grep "enabled:" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')
    DISCORD_WEBHOOK=$(grep -A 5 "discord:" "$yaml_file" | grep "webhook_url:" | head -n1 | awk -F': ' '{print $2}' | tr -d ' "')

    export CF_ZONE_ID CF_API_TOKEN TG_ENABLED TG_BOT_TOKEN TG_CHAT_ID DISCORD_ENABLED DISCORD_WEBHOOK

    # Parse Domains Block using a state machine in bash loop
    # We read line by line. If we see "- name:", we start a new logic block.
    
    domains_names=()
    domains_proxied=()
    domains_ipv4=()
    domains_ipv6=()
    domains_ttl=()

    local current_idx=-1
    local in_domains_block=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Clean leading/trailing whitespace
        clean_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # skip comments and empty lines
        if [[ "$clean_line" =~ ^# ]] || [[ -z "$clean_line" ]]; then
            continue
        fi

        # Detect start of domains block
        if [[ "$clean_line" == "domains:" ]]; then
            in_domains_block=true
            continue
        fi
        
        # If we hit another top-level block (like settings:), stop parsing domains
        if [[ "$clean_line" == "settings:" ]]; then
            in_domains_block=false
        fi

        if [[ "$in_domains_block" == "true" ]]; then
            # New domain entry
            if [[ "$line" =~ -[[:space:]]name:[[:space:]]*(.*) ]]; then
                current_idx=$((current_idx + 1))
                val="${BASH_REMATCH[1]}"
                domains_names[current_idx]="${val//\"/}" # remove quotes
                
                # Set defaults
                domains_proxied[current_idx]="true"
                domains_ipv4[current_idx]="true"
                domains_ipv6[current_idx]="false"
                domains_ttl[current_idx]="auto"
            fi
            
            # Use raw line to match indentation if needed, but simple grep matches work for properties
            # logic: if we are inside a domain block (current_idx > -1), parse properties
            if [[ $current_idx -ge 0 ]]; then
                if [[ "$clean_line" =~ ^proxied:[[:space:]]*(.*) ]]; then
                    domains_proxied[current_idx]="${BASH_REMATCH[1]}"
                elif [[ "$clean_line" =~ ^ipv4:[[:space:]]*(.*) ]]; then
                    domains_ipv4[current_idx]="${BASH_REMATCH[1]}"
                elif [[ "$clean_line" =~ ^ipv6:[[:space:]]*(.*) ]]; then
                    domains_ipv6[current_idx]="${BASH_REMATCH[1]}"
                elif [[ "$clean_line" =~ ^ttl:[[:space:]]*(.*) ]]; then
                    domains_ttl[current_idx]="${BASH_REMATCH[1]}"
                fi
            fi
        fi

    done < "$yaml_file"

    export domains_names domains_proxied domains_ipv4 domains_ipv6 domains_ttl
    export DOMAIN_COUNT=${#domains_names[@]}
}
