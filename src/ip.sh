#!/usr/bin/env bash

# Helper: Generic HTTP Get with IPv4/IPv6 forcing
http_get() {
    local url="$1"
    local proto="$2" # 4 or 6
    local timeout="5"

    if command -v curl >/dev/null 2>&1; then
        curl "-${proto}" -s --max-time "$timeout" "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        # wget uses -4 or -6. -q=quiet, -O-=output to stdout, --tries=1
        wget "-${proto}" -qO- --timeout="$timeout" --tries=1 "$url" 2>/dev/null
    else
        return 1
    fi
}

# Get Public IPv4
get_public_ipv4() {
    local ip=""
    # Try icanhazip
    ip=$(http_get "https://icanhazip.com" 4)
    
    if [[ -z "$ip" ]]; then
        # Try ifconfig.co
        ip=$(http_get "https://ifconfig.co" 4)
    fi
     if [[ -z "$ip" ]]; then
        # Try ipify
        ip=$(http_get "https://api.ipify.org" 4)
    fi

    # Validate IP format
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    else
        echo ""
        return 1
    fi
}

# Get Public IPv6
get_public_ipv6() {
    local ip=""
    # Try icanhazip
    ip=$(http_get "https://icanhazip.com" 6)
    
    if [[ -z "$ip" ]]; then
        # Try ifconfig.co
        ip=$(http_get "https://ifconfig.co" 6)
    fi
    # api6.ipify.org is also an option but often same as icanhazip backend

    # Validate IP format (simple regex for IPv6)
    if [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo "$ip"
        return 0
    else
        echo ""
        return 1
    fi
}
