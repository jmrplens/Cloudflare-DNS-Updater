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

# Detect Default Interface (Linux/macOS)
get_default_interface() {
    if command -v ip >/dev/null 2>&1; then
        # Linux
        ip route show default | head -n1 | sed -n 's/.*dev \([^ ]*\).*/\1/p'
    elif command -v route >/dev/null 2>&1; then
        # macOS / BSD
        route -n get default | grep 'interface:' | awk '{print $2}'
    fi
}

# Get IPv6 from specific interface
get_ipv6_from_interface() {
    local iface="$1"
    local ip=""
    
    if [[ -z "$iface" ]]; then return 1; fi

    if command -v ip >/dev/null 2>&1; then
        # Linux: Prefer 'global' scope, exclude 'deprecated' or 'temporary' if possible, 
        # but Cloudflare usually wants the permanent global address.
        # We take the first 'scope global' address.
        # 'ip -6 addr show dev eth0 scope global'
        # Output format: "inet6 2001:db8::1/64 scope global ..."
        
        # Try to find one that is NOT temporary (mngtmpaddr/dynamic) if possible, 
        # or just the first global one. 
        # User example: 2a0c:5a84:b906:6300:7a55:36ff:fe04:bb9a (looks like EUI-64 or random privacy, but global)
        
        ip=$(ip -6 addr show dev "$iface" scope global | grep "inet6" | head -n1 | awk '{print $2}' | cut -d'/' -f1)
        
    elif command -v ifconfig >/dev/null 2>&1; then
        # macOS / BSD
        # Look for 'inet6', exclude 'fe80', take first.
        ip=$(ifconfig "$iface" | grep "inet6 " | grep -v "fe80::" | head -n1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    
    # Windows (via ipconfig in git bash/wsl? hard to parse reliable without powershell)
    # If standard tools fail, return empty.

    echo "$ip"
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
    
    # 1. Try Local Interface (Preferred)
    local iface="${NET_INTERFACE}"
    
    # If no interface config, try to auto-detect default
    if [[ -z "$iface" ]]; then
        iface=$(get_default_interface)
    fi
    
    if [[ -n "$iface" ]]; then
        log_debug "Checking interface '$iface' for IPv6..."
        local local_ip
        local_ip=$(get_ipv6_from_interface "$iface")
        
        if [[ -n "$local_ip" ]]; then
            log_debug "Found Local IPv6: $local_ip"
            echo "$local_ip"
            return 0
        else
            log_debug "No Global IPv6 found on interface '$iface'."
        fi
    fi

    # 2. Fallback to External Services
    log_debug "Fallback to external IPv6 detection..."
    
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
