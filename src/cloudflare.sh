#!/usr/bin/env bash

CF_API_URL="https://api.cloudflare.com/client/v4"

# Headers
cf_headers() {
    echo "-H \"Authorization: Bearer $CF_API_TOKEN\" -H \"Content-Type: application/json\""
}

# Fetch ALL records (limit 500 for safety, usually enough for personal zones)
cf_get_all_records() {
    # Get all A and AAAA records
    # We filter by type to reduce noise, or just get all.
    # Cloudflare allows filtering by type, but only one type at a time usually? 
    # Actually, we can just get everything and filter locally.
    
    response=$(curl -s -X GET "$CF_API_URL/zones/$CF_ZONE_ID/dns_records?per_page=500" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    if [[ "$response" != *"\"success\":true"* ]]; then
        log_error "Failed to fetch records"
        log_debug "$response"
        return 1
    fi
    
    echo "$response"
}

# Parse JSON response into flat readable lines:
# ID|NAME|TYPE|CONTENT|PROXIED
cf_parse_records_to_lines() {
    local json="$1"
    
    # If jq is available, use it (robust)
    if command -v jq &> /dev/null; then
        echo "$json" | jq -r '.result[] | "\(.id)|\(.name)|\(.type)|\(.content)|\(.proxied)"'
    else
        # Fallback pure bash/sed/awk (fragile but functional for standard CF output)
        # We assume standard formatting. 
        # Strategy: split by "}," to separate objects (roughly)
        # This is a bit "hacky" but works for simple flat lists without nested arrays in fields.
        
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
# Expects a JSON payload string: { "puts": [ ... ] }
cf_batch_update() {
    local payload="$1"
    
    response=$(curl -s -X POST "$CF_API_URL/zones/$CF_ZONE_ID/dns_records/batch" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$payload")

    # Cloudflare Batch API returns 200 OK even on partial failures sometimes, 
    # but usually "success": true/false
    if [[ "$response" == *"\"success\":true"* ]]; then
        return 0
    else
        log_error "Batch update failed!"
        log_debug "$response"
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
