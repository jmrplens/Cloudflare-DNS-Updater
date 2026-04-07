#!/usr/bin/env bash

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
		# Linux: Get global scope addresses, exclude ULA (fc00::/7 = fc/fd prefix).
		# Filter out deprecated addresses — they should not be published in DNS.
		ip=$(ip -6 addr show dev "$iface" scope global | grep -v deprecated | awk '/inet6 / { split($2, a, "/"); if (a[1] !~ /^[Ff][CcDd]/) { print a[1]; exit } }')
		if [[ -z "$ip" ]]; then
			echo "[WARNING] No valid (non-deprecated) IPv6 address found on interface '$iface'. AAAA records will not be updated." >&2
		fi

	elif command -v ifconfig >/dev/null 2>&1; then
		# macOS / BSD: exclude link-local (fe80) and ULA (fc/fd prefix)
		ip=$(ifconfig "$iface" | awk '/inet6 / && $2 !~ /^fe80/ && $2 !~ /^[Ff][CcDd]/ { split($2, a, "/"); print a[1]; exit }')
	fi

	# Windows (via ipconfig in git bash/wsl? hard to parse reliable without powershell)
	# If standard tools fail, return empty.

	echo "$ip"
}

# IP Validation Helpers
is_valid_ipv4() {
	[[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

is_valid_ipv6() {
	[[ "$1" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$1" == *":"* ]]
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
	if is_valid_ipv4 "$ip"; then
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

	# Validate IP format
	if is_valid_ipv6 "$ip"; then
		echo "$ip"
		return 0
	else
		echo ""
		return 1
	fi
}
