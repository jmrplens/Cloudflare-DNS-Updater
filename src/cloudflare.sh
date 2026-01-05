#!/usr/bin/env bash

CF_API_URL="https://api.cloudflare.com/client/v4"

# Fetch all records (limit 500)
cf_get_all_records() {
    log_debug "API: GET $CF_API_URL/zones/$CF_ZONE_ID/dns_records?per_page=500"
    
    response=$(http_request "GET" \
        "$CF_API_URL/zones/$CF_ZONE_ID/dns_records?per_page=500" \
        "" \
        "Authorization: Bearer $CF_API_TOKEN" \
        "Content-Type: application/json")

    log_debug_redacted "API Response: $response"

    if [[ "$response" != *"\"success\":true"* ]]; then
        log_error "Failed to fetch records"
        log_debug_redacted "$response"
        return 1
    fi
    
    echo "$response"
}

# Parse JSON response into flat readable lines:
# ID|NAME|TYPE|CONTENT|PROXIED
cf_parse_records_to_lines() {
    local json="$1"
    
    # Determine JSON parser
    local jq_cmd="jq"
    if command -v jq &> /dev/null; then
        jq_cmd="jq"
    elif command -v jq.exe &> /dev/null; then
        jq_cmd="jq.exe"
    elif [[ -f "/mnt/c/msys64/mingw64/bin/jq.exe" ]]; then
        jq_cmd="/mnt/c/msys64/mingw64/bin/jq.exe"
    elif [[ -f "/c/msys64/mingw64/bin/jq.exe" ]]; then
        jq_cmd="/c/msys64/mingw64/bin/jq.exe"
    else
        jq_cmd=""
    fi

    # Parse
    if [[ -n "$jq_cmd" ]]; then
        log_debug "Using JSON parser: $jq_cmd"
        echo "$json" | "$jq_cmd" -r '.result[] | "\(.id)|\(.name)|\(.type)|\(.content)|\(.proxied)"'
    else
        log_warn "jq not found. Using sed parser fallback."
        
        echo "$json" | \
        sed -e 's/},{"/}\n{/g' | \
        sed -e 's/\[{/{/g' | \
        sed -e 's/}\]//g' | \
        while read -r line; do
            id=$(echo "$line" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4)
            name=$(echo "$line" | grep -o '"name":"[^"]*"' | head -n1 | cut -d'"' -f4)
            type=$(echo "$line" | grep -o '"type":"[^"]*"' | head -n1 | cut -d'"' -f4)
            content=$(echo "$line" | grep -o '"content":"[^"]*"' | head -n1 | cut -d'"' -f4)
            proxied=$(echo "$line" | grep -o '"proxied":[^,}]*' | head -n1 | cut -d':' -f2 | tr -d ' ')
            
            if [[ -n "$id" && -n "$name" ]]; then
                echo "$id|$name|$type|$content|$proxied"
            fi
        done
    fi
}

# Batch Update
cf_batch_update() {
    local payload="$1"
    
    log_debug "API: POST batch update..."
    log_debug_redacted "API Payload: $payload"
    
    response=$(http_request "POST" \
        "$CF_API_URL/zones/$CF_ZONE_ID/dns_records/batch" \
        "$payload" \
        "Authorization: Bearer $CF_API_TOKEN" \
        "Content-Type: application/json")
        
    log_debug_redacted "API Response: $response"

    # Echo response for caller to capture
    echo "$response"

    if [[ "$response" == *"\"success\":true"* ]]; then
        return 0
    else
        log_error "Batch update failed!"
        log_debug_redacted "$response"
        return 1
    fi
}

# Cache Helper
# Args: parsed_records domain type
cf_get_record_from_cache() {
    local cache="$1"
    local domain="$2"
    local type="$3"
    echo "$cache" | grep -F "|$domain|$type|" | head -n1
}

# Comparison Helper
# Args: current_ip target_ip current_proxied target_proxied
cf_needs_update() {
    local cur_ip="$1"
    local tar_ip="$2"
    local cur_proxied="$3"
    local tar_proxied="$4"
    
    [[ "$cur_ip" != "$tar_ip" ]] || [[ "$cur_proxied" != "$tar_proxied" ]]
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
