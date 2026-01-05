#!/usr/bin/env bash

CF_API_URL="https://api.cloudflare.com/client/v4"

# Headers
cf_headers() {
    echo "-H \"Authorization: Bearer $CF_API_TOKEN\" -H \"Content-Type: application/json\""
}

# Fetch all records (limit 500)
cf_get_all_records() {
    log_debug "API: GET $CF_API_URL/zones/$CF_ZONE_ID/dns_records?per_page=500"
    
    response=$(curl -s -X GET "$CF_API_URL/zones/$CF_ZONE_ID/dns_records?per_page=500" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    log_debug_redacted "API Response: $response"

    if [[ "$response" != *"\"success\":true"* ]]; then
        log_error "Failed to fetch records"
        log_debug_redacted "$response"
        return 1
    fi
    
    echo "$response"
}

# ... (skip to cf_batch_update) ...

# Batch Update
cf_batch_update() {
    local payload="$1"
    
    log_debug "API: POST batch update..."
    log_debug_redacted "API Payload: $payload"
    
    response=$(curl -s -X POST "$CF_API_URL/zones/$CF_ZONE_ID/dns_records/batch" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$payload")
        
    log_debug_redacted "API Response: $response"

    if [[ "$response" == *"\"success\":true"* ]]; then
        return 0
    else
        log_error "Batch update failed!"
        log_debug_redacted "$response"
        return 1
    fi
}

# Helper to build a single update object JSON
cf_build_put_object() {
    local id="$1"
    local type="$2"
    local name="$3"
    local content="$4"
    local proxied="$5"
    local ttl="$6"
    
    if [[ "$ttl" == "auto" ]]; then ttl=1; fi
    
    # Returns: {"id":"...","type":"...","name":"...","content":"...","ttl":...,"proxied":...}
    echo "{\"id\":\"$id\",\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
}
