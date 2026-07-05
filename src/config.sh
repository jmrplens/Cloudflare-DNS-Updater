#!/usr/bin/env bash

# Global configuration variables
CF_ZONE_ID=""
CF_API_TOKEN=""
NET_INTERFACE=""
TG_ENABLED="false"
TG_BOT_TOKEN=""
TG_CHAT_ID=""
DISCORD_ENABLED="false"
DISCORD_WEBHOOK=""

# Global domain defaults (options: block)
DEFAULT_PROXIED="true"
DEFAULT_TTL="auto"

# Domain arrays
domains_names=()
domains_proxied=()
domains_ipv4=()
domains_ipv6=()
domains_ttl=()
DOMAIN_COUNT=0

# Normalize a raw YAML scalar: strip trailing CR (CRLF configs), inline
# comments, surrounding whitespace and quotes.
clean_value() {
	local val="$1"
	val="${val%%$'\r'*}"
	val=$(echo "$val" | sed 's/[[:space:]]#.*$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
	val="${val%\"}"
	val="${val#\"}"
	val="${val%\'}"
	val="${val#\'}"
	echo "$val"
}

# Extract "key: value" from a block of lines (first match)
_yaml_get() {
	local block="$1"
	local key="$2"
	clean_value "$(echo "$block" | grep "$key:" | head -n1 | awk -F': ' '{print $2}')"
}

# Parse YAML config file
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
	CF_ZONE_ID=$(_yaml_get "$(cat "$yaml_file")" "zone_id")
	CF_API_TOKEN=$(_yaml_get "$(cat "$yaml_file")" "api_token")

	# Parse Options (global domain defaults)
	local options_block
	options_block=$(grep -A 5 "^options:" "$yaml_file")
	NET_INTERFACE=$(_yaml_get "$options_block" "interface")
	DEFAULT_PROXIED=$(_yaml_get "$options_block" "proxied")
	DEFAULT_PROXIED=${DEFAULT_PROXIED:-true}
	DEFAULT_TTL=$(_yaml_get "$options_block" "ttl")
	DEFAULT_TTL=${DEFAULT_TTL:-auto}
	# Cloudflare uses ttl=1 for "auto"
	[[ "$DEFAULT_TTL" == "1" ]] && DEFAULT_TTL="auto"

	# Parse Notifications
	local tg_block discord_block
	tg_block=$(grep -A 5 "telegram:" "$yaml_file")
	TG_ENABLED=$(_yaml_get "$tg_block" "enabled")
	TG_BOT_TOKEN=$(_yaml_get "$tg_block" "bot_token")
	TG_CHAT_ID=$(_yaml_get "$tg_block" "chat_id")

	discord_block=$(grep -A 5 "discord:" "$yaml_file")
	DISCORD_ENABLED=$(_yaml_get "$discord_block" "enabled")
	DISCORD_WEBHOOK=$(_yaml_get "$discord_block" "webhook_url")

	export CF_ZONE_ID CF_API_TOKEN NET_INTERFACE TG_ENABLED TG_BOT_TOKEN TG_CHAT_ID DISCORD_ENABLED DISCORD_WEBHOOK

	# Parse Domains Block
	domains_names=()
	domains_proxied=()
	domains_ipv4=()
	domains_ipv6=()
	domains_ttl=()

	local current_idx=-1
	local in_domains_block=false

	while IFS= read -r line || [[ -n "$line" ]]; do
		clean_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		clean_line="${clean_line%$'\r'}"

		# skip comments and empty lines
		if [[ "$clean_line" =~ ^# ]] || [[ -z "$clean_line" ]]; then
			continue
		fi

		if [[ "$clean_line" == "domains:" ]]; then
			in_domains_block=true
			continue
		fi

		# Any other top-level key (unindented, ends with ':') closes the
		# domains block, not just a specific hardcoded section name.
		if [[ "$in_domains_block" == "true" && "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*$ ]]; then
			in_domains_block=false
		fi

		if [[ "$in_domains_block" == "true" ]]; then
			# New domain entry
			if [[ "$line" =~ -[[:space:]]name:[[:space:]]*(.*) ]]; then
				current_idx=$((current_idx + 1))
				domains_names[current_idx]=$(clean_value "${BASH_REMATCH[1]}")

				# Set defaults (inherited from the options: block)
				domains_proxied[current_idx]="$DEFAULT_PROXIED"
				domains_ipv4[current_idx]="true"
				domains_ipv6[current_idx]="true"
				domains_ttl[current_idx]="$DEFAULT_TTL"
			fi

			# Parse properties
			if [[ $current_idx -ge 0 ]]; then
				if [[ "$clean_line" =~ ^proxied:[[:space:]]*(.*) ]]; then
					domains_proxied[current_idx]=$(clean_value "${BASH_REMATCH[1]}")
				elif [[ "$clean_line" =~ ^ipv4:[[:space:]]*(.*) ]]; then
					domains_ipv4[current_idx]=$(clean_value "${BASH_REMATCH[1]}")
				elif [[ "$clean_line" =~ ^ipv6:[[:space:]]*(.*) ]]; then
					domains_ipv6[current_idx]=$(clean_value "${BASH_REMATCH[1]}")
				elif [[ "$clean_line" =~ ^ip_type:[[:space:]]*(.*) ]]; then
					val=$(clean_value "${BASH_REMATCH[1]}")
					if [[ "$val" == "ipv4" ]]; then
						domains_ipv4[current_idx]="true"
						domains_ipv6[current_idx]="false"
					elif [[ "$val" == "ipv6" ]]; then
						domains_ipv4[current_idx]="false"
						domains_ipv6[current_idx]="true"
					elif [[ "$val" == "both" ]]; then
						domains_ipv4[current_idx]="true"
						domains_ipv6[current_idx]="true"
					fi
				elif [[ "$clean_line" =~ ^ttl:[[:space:]]*(.*) ]]; then
					domains_ttl[current_idx]=$(clean_value "${BASH_REMATCH[1]}")
				fi
			fi
		fi

	done <"$yaml_file"

	export domains_names domains_proxied domains_ipv4 domains_ipv6 domains_ttl
	export DOMAIN_COUNT=${#domains_names[@]}
}
