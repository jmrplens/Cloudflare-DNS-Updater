#!/usr/bin/env bash
# shellcheck disable=SC1091

# Load Modules
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/logger.sh"
source "$DIR/config.sh"
source "$DIR/ip.sh"
source "$DIR/cloudflare.sh"
source "$DIR/notifications.sh"

# Initialize Logger
LOG_PATH="$DIR/../logs/updater.log"
logger_init "$LOG_PATH"

# shellcheck disable=SC2154

main() {
    local config="$1"
    
    log_info "Starting Cloudflare DNS Updater..."
    
    # 1. Parse Config
    log_info "Loading configuration from $config..."
    if ! parse_config "$config"; then
        exit 1
    fi
    log_success "Loaded $DOMAIN_COUNT domains."

    # 2. Get Current Public IPs
    log_info "Detecting Public IPs..."
    CURRENT_IPV4=$(get_public_ipv4)
    CURRENT_IPV6=$(get_public_ipv6)

    if [[ -n "$CURRENT_IPV4" ]]; then
        log_success "Detected IPv4: $CURRENT_IPV4"
    else
        log_warn "Could not detect Public IPv4."
    fi

    if [[ -n "$CURRENT_IPV6" ]]; then
        log_success "Detected IPv6: $CURRENT_IPV6"
    else
        log_info "Could not detect Public IPv6 (or not available)."
    fi

    if [[ -z "$CURRENT_IPV4" && -z "$CURRENT_IPV6" ]]; then
        log_error "No connectivity or unable to detect any IP. Exiting."
        exit 1
    fi

    # 3. Fetch All Cloudflare Records (Bulk Read)
    log_info "Fetching all DNS records from Cloudflare..."
    if ! raw_records=$(cf_get_all_records); then
        log_error "Critical: Unable to fetch DNS records."
        exit 1
    fi
    
    # Parse into temporary file or memory
    # We use a temp file for safely reading lines multiple times if needed, or just memory
    # Format: ID|NAME|TYPE|CONTENT|PROXIED
    parsed_records=$(cf_parse_records_to_lines "$raw_records")
    local record_lines
    record_lines=$(echo "$parsed_records" | wc -l)
    log_info "Parsed $record_lines records from Cloudflare."
    
    # 4. Local Diff Engine
    log_info "Analyzing records..."
    
    updates_json_list=""
    update_count=0
    
    # Create associative array-like simulation is hard in bash 3 (macOS default/old bash). 
    # We will just grep the parsed_records variable. It's fast enough for <5000 lines.

    for (( i=0; i<DOMAIN_COUNT; i++ )); do
        domain="${domains_names[i]}"
        target_proxied="${domains_proxied[i]}"
        do_ipv4="${domains_ipv4[i]}"
        do_ipv6="${domains_ipv6[i]}"
        ttl="${domains_ttl[i]}"
        
        # --- IPv4 Check ---
        if [[ "$do_ipv4" == "true" && -n "$CURRENT_IPV4" ]]; then
            # Find in cache
            # Grep for exact domain and type set 'A'
            # Format: ID|NAME|TYPE|CONTENT|PROXIED
            match=$(echo "$parsed_records" | grep -F "|$domain|A|")
            
            if [[ -z "$match" ]]; then
                log_warn "Record A for $domain not found. (Batch Create not fully implemented, skipping)"
                # To implement create, we'd need to add to a separate 'creates' list for a POST batch or individual creates.
                # For this optimization task, we focus on updates as per request "PUT de multiple records".
            else
                IFS='|' read -r r_id _ _ r_content r_proxied <<< "$match"
                
                if [[ "$r_content" != "$CURRENT_IPV4" || "$r_proxied" != "$target_proxied" ]]; then
                    log_info "Change detected for $domain (A): $r_content -> $CURRENT_IPV4"
                    
                    obj=$(cf_build_put_object "$r_id" "A" "$domain" "$CURRENT_IPV4" "$target_proxied" "$ttl")
                    if [[ -n "$updates_json_list" ]]; then updates_json_list+=","; fi
                    updates_json_list+="$obj"
                    ((update_count++))
                fi
            fi
        fi

        # --- IPv6 Check ---
        if [[ "$do_ipv6" == "true" && -n "$CURRENT_IPV6" ]]; then
            match=$(echo "$parsed_records" | grep -F "|$domain|AAAA|")
            
            if [[ -z "$match" ]]; then
                log_warn "Record AAAA for $domain not found. (Skipping)"
            else
                IFS='|' read -r r_id _ _ r_content r_proxied <<< "$match"
                
                if [[ "$r_content" != "$CURRENT_IPV6" || "$r_proxied" != "$target_proxied" ]]; then
                     log_info "Change detected for $domain (AAAA): $r_content -> $CURRENT_IPV6"
                    
                    obj=$(cf_build_put_object "$r_id" "AAAA" "$domain" "$CURRENT_IPV6" "$target_proxied" "$ttl")
                    if [[ -n "$updates_json_list" ]]; then updates_json_list+=","; fi
                    updates_json_list+="$obj"
                    ((update_count++))
                fi
            fi
        fi
        
    done

    # 5. Execute Batch Update
    if [[ $update_count -gt 0 ]]; then
        log_info "Pushing $update_count updates to Cloudflare..."
        
        # Construct Payload: { "puts": [ ... ] }
        final_payload="{\"puts\":[$updates_json_list]}"
        
        if cf_batch_update "$final_payload"; then
            log_success "Successfully updated $update_count records!"
            send_notification "Cloudflare DNS: Updated $update_count records to IP(s) $CURRENT_IPV4 $CURRENT_IPV6"
        else
            log_error "Batch update failed."
            send_notification "Cloudflare DNS: Batch update failed."
        fi
    else
        log_success "No changes needed. All records are up to date."
    fi
}

# Run
main "$@"
