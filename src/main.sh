#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154,SC2034

# Global state for static analysis
domains_names=()
domains_proxied=()
domains_ipv4=()
domains_ipv6=()
domains_ttl=()
DOMAIN_COUNT=0
CF_ZONE_ID=""
CF_API_TOKEN=""
DEBUG="false"
FORCE="false"
SILENT="false"

# Load Modules
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/logger.sh"
source "$DIR/network.sh"
source "$DIR/config.sh"
source "$DIR/ip.sh"
source "$DIR/cloudflare.sh"
source "$DIR/notifications.sh"

# Initialize Logger
LOG_PATH="$DIR/../logs/updater.log"
logger_init "$LOG_PATH"

# shellcheck source=src/config.sh
# shellcheck source=src/ip.sh
# shellcheck source=src/cloudflare.sh

# Project metadata
VERSION="1.1.1"
updates_json_list=""
update_count=0
verification_list=()

show_help() {
	local cmd_name
	cmd_name=$(basename "$0")
	[[ "$cmd_name" == "main.sh" ]] && cmd_name="cf-updater"

	cat <<EOF
Cloudflare DNS Updater v$VERSION - Automate your Dynamic DNS updates.

Usage:
  $cmd_name [options] [config_file.yaml]

Options:
  -h, --help     Show this help message
  -s, --silent   No console output (errors only)
  -d, --debug    Enable verbose output and API confirmation
  -f, --force    Update records even if they match current IP

Config:
  By default, it looks for 'cloudflare-dns.yaml' in the current directory.

Project:
  https://github.com/jmrplens/Cloudflare-DNS-Updater
EOF
}

# Helper to check and queue updates
queue_if_changed() {
	local type="$1"
	local domain="$2"
	local target_ip="$3"
	local target_proxied="$4"
	local ttl="$5"

	if [[ -z "$target_ip" ]]; then
		log_debug "  - IPv$([[ "$type" == "A" ]] && echo 4 || echo 6) Check skipped: No Public IP detected."
		return
	fi

	local match
	match=$(cf_get_record_from_cache "$parsed_records" "$domain" "$type")

	if [[ -z "$match" ]]; then
		log_warn "Record $type for $domain not found. Creation not implemented."
		return
	fi

	IFS='|' read -r r_id _ _ r_content r_proxied <<<"$match"

	if is_force || cf_needs_update "$r_content" "$target_ip" "$r_proxied" "$target_proxied"; then
		if is_force && ! cf_needs_update "$r_content" "$target_ip" "$r_proxied" "$target_proxied"; then
			log_info "Force update: $domain ($type) [Matches current: $target_ip]"
		else
			log_info "Change detected for $domain ($type): $r_content -> $target_ip"
		fi

		local obj
		obj=$(cf_build_put_object "$r_id" "$type" "$domain" "$target_ip" "$target_proxied" "$ttl")

		if [[ -n "$updates_json_list" ]]; then updates_json_list+=","; fi
		updates_json_list+="$obj"
		((update_count++))

		if [[ "$target_proxied" == "false" ]]; then
			verification_list+=("$domain|$([[ "$type" == "A" ]] && echo 4 || echo 6)|$target_ip")
		fi
	else
		log_debug "  - $type record OK ($r_content)"
	fi
}

main() {
	local config="$1"

	if [[ "$config" == "--help" ]] || [[ "$config" == "-h" ]]; then
		show_help
		return 0
	fi

	log_info "Starting Cloudflare DNS Updater..."

	# 1. Parse Config
	log_info "Loading configuration from $config..."
	if ! parse_config "$config"; then
		exit 1
	fi

	# Calculate task summary
	local total_v4=0
	local total_v6=0
	for ((i = 0; i < DOMAIN_COUNT; i++)); do
		[[ "${domains_ipv4[i]}" == "true" ]] && ((total_v4++))
		[[ "${domains_ipv6[i]}" == "true" ]] && ((total_v6++))
	done
	log_success "Loaded $DOMAIN_COUNT domains (Tasks: $total_v4 IPv4, $total_v6 IPv6)."

	# 2. Get Current Public IPs	log_info "Detecting Public IPs..."
	CURRENT_IPV4=$(get_public_ipv4)
	CURRENT_IPV6=$(get_public_ipv6)

	if [[ -n "$CURRENT_IPV4" ]]; then log_success "Detected IPv4: $CURRENT_IPV4"; else log_warn "Could not detect Public IPv4."; fi
	if [[ -n "$CURRENT_IPV6" ]]; then log_success "Detected IPv6: $CURRENT_IPV6"; else log_info "Could not detect Public IPv6."; fi

	if [[ -z "$CURRENT_IPV4" && -z "$CURRENT_IPV6" ]]; then
		log_error "No connectivity or unable to detect any IP. Exiting."
		exit 1
	fi

	# 3. Fetch Cloudflare Records (Single Request)
	log_info "Fetching DNS records from Cloudflare..."
	local fetch_type=""

	# Logic: If we only need one type, filter at API level.
	# If we need both, fetch all in 1 call to minimize RTT.
	if [[ $total_v4 -gt 0 && $total_v6 -eq 0 ]]; then
		fetch_type="A"
	elif [[ $total_v4 -eq 0 && $total_v6 -gt 0 ]]; then
		fetch_type="AAAA"
	fi

	if ! raw_records=$(cf_get_all_records "$fetch_type"); then
		log_error "Critical: Unable to fetch DNS records."
		exit 1
	fi

	parsed_records=$(cf_parse_records_to_lines "$raw_records")
	local record_lines
	record_lines=$(echo "$parsed_records" | grep -c "^" || echo 0)
	log_info "Parsed $record_lines records from Cloudflare (processing $DOMAIN_COUNT domains)." # 4. Analyze Records
	log_info "Analyzing records..."

	for ((i = 0; i < DOMAIN_COUNT; i++)); do
		local domain="${domains_names[i]}"
		local proxied="${domains_proxied[i]}"
		local ttl="${domains_ttl[i]}"

		log_debug "Checking domain: $domain (Proxy: $proxied)"

		# Check IPv4 if enabled
		if [[ "${domains_ipv4[i]}" == "true" ]]; then
			queue_if_changed "A" "$domain" "$CURRENT_IPV4" "$proxied" "$ttl"
		fi

		# Check IPv6 if enabled
		if [[ "${domains_ipv6[i]}" == "true" ]]; then
			queue_if_changed "AAAA" "$domain" "$CURRENT_IPV6" "$proxied" "$ttl"
		fi
	done

	# 5. Execute Batch Update
	if [[ $update_count -gt 0 ]]; then
		log_info "Pushing $update_count updates to Cloudflare..."

		local final_payload="{\"puts\":[$updates_json_list]}"
		local batch_response

		if batch_response=$(cf_batch_update "$final_payload"); then
			log_success "Successfully updated $update_count records!"
			send_notification "Cloudflare DNS: Updated $update_count records to IP(s) $CURRENT_IPV4 $CURRENT_IPV6"

			# --- Verification ---
			if is_debug; then
				log_info "Debug: Verifying updates via API response..."
				for item in "${verification_list[@]}"; do
					IFS='|' read -r v_domain v_proto v_expected <<<"$item"
					if echo "$batch_response" | grep -Fq "\"name\":\"$v_domain\"" && echo "$batch_response" | grep -Fq "\"content\":\"$v_expected\""; then
						log_success "API Verified: $v_domain (IPv$v_proto) confirmed updated to $v_expected"
					else
						log_warn "API Verification Warning: Could not confirm update for $v_domain in response."
					fi
				done
			fi
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
