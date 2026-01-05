#!/usr/bin/env bash

CF_API_URL="https://api.cloudflare.com/client/v4"

# Headers
cf_headers() {
    echo "-H \"Authorization: Bearer $CF_API_TOKEN\" -H \"Content-Type: application/json\""
}

# Fetch all records (limit 500)
cf_get_all_records() {
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
    
    response=$(curl -s -X POST "$CF_API_URL/zones/$CF_ZONE_ID/dns_records/batch" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$payload")

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
