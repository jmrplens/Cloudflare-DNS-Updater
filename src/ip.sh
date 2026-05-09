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

get_ipv6_prefix64() {
	local addr="${1%%/*}"

	printf '%s\n' "$addr" | awk '
		function count_parts(value, parts) {
			return value == "" ? 0 : split(value, parts, ":")
		}
		function normalize(part) {
			part = tolower(part)
			sub(/^0+/, "", part)
			return part == "" ? "0" : part
		}

		{
			addr = tolower($0)
			sub(/%.*/, "", addr)
			if (addr == "") next

			split(addr, halves, "::")
			left_count = count_parts(halves[1], left)
			right_count = index(addr, "::") ? count_parts(halves[2], right) : 0
			missing = index(addr, "::") ? 8 - left_count - right_count : 0

			idx = 0
			for (i = 1; i <= left_count; i++) hextets[++idx] = normalize(left[i])
			for (i = 1; i <= missing; i++) hextets[++idx] = "0"
			for (i = 1; i <= right_count; i++) hextets[++idx] = normalize(right[i])

			if (idx >= 4) print hextets[1] ":" hextets[2] ":" hextets[3] ":" hextets[4]
		}'
}

get_ipv6_route_prefix() {
	local route_src
	local route_target

	route_src=$(ip -6 route show default 2>/dev/null | sed -n 's/.* src \([^ ]*\).*/\1/p' | head -n1)
	if [[ -z "$route_src" ]]; then
		route_src=$(ip -6 route show ::/0 2>/dev/null | sed -n 's/.* src \([^ ]*\).*/\1/p' | head -n1)
	fi
	if [[ -z "$route_src" ]]; then
		route_target="${IPV6_ROUTE_TARGET:-2001:4860:4860::8888}"
		if [[ -n "$route_target" ]]; then
			route_src=$(ip -6 route get "$route_target" 2>/dev/null | sed -n 's/.* src \([^ ]*\).*/\1/p' | head -n1)
		fi
	fi
	if [[ -n "$route_src" ]]; then
		get_ipv6_prefix64 "$route_src"
	fi
}

# Get IPv6 from specific interface
get_ipv6_from_interface() {
	local iface="$1"
	local ip=""

	if [[ -z "$iface" ]]; then return 1; fi

	if command -v ip >/dev/null 2>&1; then
		# Linux: prefer the stable address on the default IPv6 prefix.
		# If the router advertises preferred_lft 0, still use the local
		# server address instead of falling back to the router's public IPv6.
		local preferred_prefix selected deprecated
		preferred_prefix=$(get_ipv6_route_prefix)
		selected=$(ip -6 addr show dev "$iface" scope global | awk -v preferred_prefix="$preferred_prefix" '
			function count_parts(value, parts) {
				return value == "" ? 0 : split(value, parts, ":")
			}
			function normalize(part) {
				part = tolower(part)
				sub(/^0+/, "", part)
				return part == "" ? "0" : part
			}
			function prefix64(addr, halves, left, right, hextets, left_count, right_count, missing, i, idx) {
				addr = tolower(addr)
				sub(/%.*/, "", addr)
				split(addr, halves, "::")
				left_count = count_parts(halves[1], left)
				right_count = index(addr, "::") ? count_parts(halves[2], right) : 0
				missing = index(addr, "::") ? 8 - left_count - right_count : 0

				idx = 0
				for (i = 1; i <= left_count; i++) hextets[++idx] = normalize(left[i])
				for (i = 1; i <= missing; i++) hextets[++idx] = "0"
				for (i = 1; i <= right_count; i++) hextets[++idx] = normalize(right[i])

				return idx >= 4 ? hextets[1] ":" hextets[2] ":" hextets[3] ":" hextets[4] : ""
			}
			function has_flag(text, name) {
				return text ~ "(^|[[:space:]])" name "([[:space:]]|$)"
			}
			function lifetime_value(name, fallback, i, value) {
				for (i = 1; i <= NF; i++) {
					if ($i == name) {
						value = $(i + 1)
						gsub(/sec$/, "", value)
						return value == "forever" ? 999999999 : value + 0
					}
				}
				return fallback
			}

			/inet6 / {
				split($2, a, "/")
				addr = tolower(a[1])
				flags = $0
				if ((getline lifetime) <= 0) next

				if (addr ~ /^f[cd]/ || has_flag(flags, "tentative") || has_flag(flags, "dadfailed") || has_flag(flags, "temporary")) {
					next
				}

				$0 = lifetime
				valid_lft = lifetime_value("valid_lft", 0)
				preferred_lft = lifetime_value("preferred_lft", 0)
				deprecated = (has_flag(flags, "deprecated") || preferred_lft == 0)
				stable = (has_flag(flags, "mngtmpaddr") || has_flag(flags, "dynamic") || flags ~ /(^|[[:space:]])proto[[:space:]]+(kernel|ra)([[:space:]]|$)/)
				score = valid_lft

				if (stable) score += 1000
				if (preferred_prefix != "" && prefix64(addr) == preferred_prefix) score += 2000000000
				if (!deprecated) score += 4000000000

				if (!found || score > best_score) {
					found = 1
					best_score = score
					best_addr = addr
					best_deprecated = deprecated
				}
			}

			END {
				if (found) print best_deprecated "|" best_addr
			}')
		if [[ -n "$selected" ]]; then
			IFS='|' read -r deprecated ip <<<"$selected"
			if [[ "$deprecated" == "1" ]]; then
				log_warn "Using deprecated local IPv6 from '$iface' because no preferred stable IPv6 is available: $ip"
			fi
		fi
		if [[ -z "$ip" ]]; then
			log_warn "No usable global IPv6 found on '$iface'. AAAA records will not be updated."
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
