#!/usr/bin/env bash

# Network Helper Module
# Provides a unified http_request function wrapping curl, wget, or other tools.

# Check availability
if command -v curl >/dev/null 2>&1; then
	HTTP_CLIENT="curl"
elif command -v wget >/dev/null 2>&1; then
	HTTP_CLIENT="wget"
elif command -v powershell.exe >/dev/null 2>&1; then
	HTTP_CLIENT="powershell"
else
	# Try finding windows curl if in WSL/Git Bash
	if command -v curl.exe >/dev/null 2>&1; then
		HTTP_CLIENT="curl.exe"
	else
		HTTP_CLIENT=""
	fi
fi

# Universal HTTP Request function
# Usage: http_request "METHOD" "URL" "BODY" "HEADER1" "HEADER2" ...
# Returns: Response body on stdout, Status code 0 on success, 1 on failure.
# Note: For simple GET, BODY can be empty string "".
http_request() {
	local method="$1"
	local url="$2"
	local body="$3"
	shift 3
	local headers=("$@")

	if [[ -z "$HTTP_CLIENT" ]]; then
		echo "Error: No compatible HTTP client found (curl, wget or powershell)." >&2
		return 1
	fi

	if [[ "$HTTP_CLIENT" == "curl" || "$HTTP_CLIENT" == "curl.exe" ]]; then
		# Build curl command array
		local cmd=("$HTTP_CLIENT" "-s" "-X" "$method")

		# Add headers
		for h in "${headers[@]}"; do
			cmd+=("-H" "$h")
		done

		# Add body if present
		if [[ -n "$body" ]]; then
			cmd+=("-d" "$body")
		fi

		# Add URL
		cmd+=("$url")

		# Execute
		"${cmd[@]}"
		return $?

	elif [[ "$HTTP_CLIENT" == "wget" ]]; then
		# wget usage
		local cmd=("wget" "-q" "-O" "-")
		cmd+=("--method=$method")

		# Headers
		for h in "${headers[@]}"; do
			cmd+=("--header=$h")
		done

		# Body
		if [[ -n "$body" ]]; then
			cmd+=("--body-data=$body")
		fi

		cmd+=("--timeout=10")
		cmd+=("$url")

		"${cmd[@]}"
		return $?

	elif [[ "$HTTP_CLIENT" == "powershell" ]]; then
		# Windows PowerShell fallback
		local h_json="@{"
		for h in "${headers[@]}"; do
			local key="${h%%:*}"
			local val="${h#*: }"
			h_json+="'$key'='$val';"
		done
		h_json+="}"

		local ps_cmd="Invoke-RestMethod -Uri '$url' -Method $method -Headers $h_json"
		if [[ -n "$body" ]]; then
			# Escape single quotes in body for PS
			local escaped_body="${body//\'/''}"
			ps_cmd+=" -Body '$escaped_body'"
		fi

		powershell.exe -Command "$ps_cmd"
		return $?
	fi
}

# Simple helper for GET requests (wrapper)
# Usage: http_get "URL" [ipv4|ipv6|any]
# This replaces the old http_get in ip.sh
http_get() {
	local url="$1"
	local proto="${2:-any}"

	local ip_flag=""
	if [[ "$proto" == "4" || "$proto" == "ipv4" ]]; then
		if [[ "$HTTP_CLIENT" == "curl" || "$HTTP_CLIENT" == "curl.exe" ]]; then
			ip_flag="-4"
		elif [[ "$HTTP_CLIENT" == "wget" ]]; then ip_flag="-4"; fi
	elif [[ "$proto" == "6" || "$proto" == "ipv6" ]]; then
		if [[ "$HTTP_CLIENT" == "curl" || "$HTTP_CLIENT" == "curl.exe" ]]; then
			ip_flag="-6"
		elif [[ "$HTTP_CLIENT" == "wget" ]]; then ip_flag="-6"; fi
	fi

	if [[ "$HTTP_CLIENT" == "curl" || "$HTTP_CLIENT" == "curl.exe" ]]; then
		$HTTP_CLIENT -s "$ip_flag" --max-time 10 "$url"
	elif [[ "$HTTP_CLIENT" == "wget" ]]; then
		wget -q -O - "$ip_flag" --timeout=10 --tries=1 "$url"
	elif [[ "$HTTP_CLIENT" == "powershell" ]]; then
		# PowerShell doesn't have a simple flag for -4/-6 in Invoke-RestMethod easily for all versions
		# but usually it respects the OS preference.
		powershell.exe -Command "Invoke-RestMethod -Uri '$url'"
	fi
}
