#!/usr/bin/env bash

# Network Helper Module
#
# Every HTTP request the program makes goes through http_send: the
# Cloudflare API calls and the notifications through http_request, the
# public IP lookups through http_get. http_send speaks to the first client
# this host has, in this order:
#
#   curl, or curl.exe (Windows' own curl, reachable from WSL)
#   GNU Wget 1.15 or later (the first release with --method and
#     --body-data), or GNU Wget2, which takes the same options
#   PowerShell: pwsh, pwsh.exe, or Windows PowerShell's powershell.exe
#     under Git Bash, MSYS2 or WSL
#
# Any other wget is never used. BusyBox wget, the default wget of Alpine,
# BusyBox images and many routers, cannot force IPv4 or IPv6, drops the
# body of an HTTP error response (where Cloudflare says what went wrong),
# and several of its builds do not check TLS certificates at all, which
# would hand the API token to anyone on the path.

# The version line of the wget on PATH, or nothing when there is none.
_http_wget_version() {
	command -v wget >/dev/null 2>&1 || return 1
	local line
	line=$(wget --version 2>&1)
	printf '%s\n' "${line%%$'\n'*}"
}

# True when the wget on PATH is GNU Wget 1.15 or later, or GNU Wget2.
_http_is_gnu_wget() {
	local version
	version=$(_http_wget_version) || return 1
	if [[ "$version" =~ ^GNU\ Wget\ ([0-9]+)\.([0-9]+) ]]; then
		local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}"
		((major > 1 || (major == 1 && minor >= 15)))
		return
	fi
	[[ "$version" == "GNU Wget2 "* ]]
}

# Sets HTTP_CLIENT to the command http_send will run, or to nothing (and
# returns 1) when this host has none it can use.
http_detect_client() {
	HTTP_CLIENT=""
	local candidate
	for candidate in curl curl.exe; do
		if command -v "$candidate" >/dev/null 2>&1; then
			HTTP_CLIENT="$candidate"
			return 0
		fi
	done
	if _http_is_gnu_wget; then
		HTTP_CLIENT="wget"
		return 0
	fi
	for candidate in pwsh pwsh.exe powershell.exe; do
		if command -v "$candidate" >/dev/null 2>&1; then
			HTTP_CLIENT="$candidate"
			return 0
		fi
	done
	return 1
}

# Explains, on stdout, why no usable client was found and how to get one.
# The launchers print it and stop before anything else runs.
http_client_problem() {
	echo "Error: no HTTP client this program can use was found in PATH."
	echo "It needs one of: curl, GNU Wget 1.15 or later (or GNU Wget2), or"
	echo "PowerShell (pwsh, or powershell.exe under Git Bash, MSYS2 or WSL)."

	local version
	if version=$(_http_wget_version); then
		if [[ "$version" == *BusyBox* ]] || [[ "$(wget --help 2>&1)" == *BusyBox* ]]; then
			echo "The wget found here is BusyBox wget, which this program does not use:"
			echo "it cannot force IPv4 or IPv6, it drops the body of an API error response,"
			echo "and several of its builds do not check TLS certificates."
		elif [[ "$version" == "GNU Wget "* ]]; then
			echo "The wget found here is ${version%% built*}, older than 1.15."
		else
			echo "The wget found here is not GNU Wget, so this program does not use it."
		fi
	fi

	echo "Install curl, for example: apt install curl, dnf install curl,"
	echo "apk add curl, pacman -S curl or brew install curl."
}

# PowerShell has no option to pick IPv4 or IPv6 for a request. The IP
# services this program asks publish host names that only have records of
# one family, so a lookup goes to those. A service without them (ifconfig.co)
# is skipped: its answer could be the other family.
_http_family_url() {
	local url="$1" family="$2"
	case "$family $url" in
	"any $url") echo "$url" ;;
	"4 https://icanhazip.com") echo "https://ipv4.icanhazip.com" ;;
	"6 https://icanhazip.com") echo "https://ipv6.icanhazip.com" ;;
	"4 https://api.ipify.org") echo "https://api.ipify.org" ;; # IPv4 only
	*) return 1 ;;
	esac
}

# The PowerShell side of http_send. It reads the request from stdin: the
# method, the URL, the time limit in seconds and one header per line, then
# an empty line, then the body exactly as it is to be sent. It writes the
# response body to stdout byte for byte, and exits 0 whenever a response
# arrived, whatever its status, like curl -s; 1, silently, when none did.
#
# Nothing it is given goes on the command line, so neither the API token
# nor the body need quoting and neither shows up in a process listing. It
# is one line of single-quoted code (no comments, no double quotes, no
# slashes) so that Git Bash, MSYS2 and WSL hand it to powershell.exe as is.
# Windows PowerShell 5.1 has no -SkipHttpErrorCheck and throws on an error
# status instead: the body is then in the error details.
IFS= read -r -d '' _HTTP_PS_SCRIPT <<'PS' || true
$ErrorActionPreference = 'Stop';
$ProgressPreference = 'SilentlyContinue';
if ($PSVersionTable.PSVersion.Major -lt 6) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 };
$buffer = New-Object IO.MemoryStream;
[Console]::OpenStandardInput().CopyTo($buffer);
$raw = $buffer.ToArray();
$text = [Text.Encoding]::GetEncoding(28591).GetString($raw);
$cut = $text.IndexOf([string][char]10 + [char]10);
$head = $text.Substring(0, $cut).Split([char]10);
$body = New-Object byte[] ($raw.Length - $cut - 2);
[Array]::Copy($raw, $cut + 2, $body, 0, $body.Length);
$request = @{ Method = $head[0]; Uri = $head[1]; TimeoutSec = [int]$head[2]; UseBasicParsing = $true; Headers = @{} };
for ($i = 3; $i -lt $head.Length; $i++) {
$colon = $head[$i].IndexOf(':');
$name = $head[$i].Substring(0, $colon).Trim();
$value = $head[$i].Substring($colon + 1).Trim();
if ($name -eq 'Content-Type') { $request.ContentType = $value } else { $request.Headers[$name] = $value }
};
if ($body.Length -gt 0) { $request.Body = $body };
if ($PSVersionTable.PSVersion.Major -ge 7) { $request.SkipHttpErrorCheck = $true };
try { $bytes = (Invoke-WebRequest @request).RawContentStream.ToArray() }
catch {
if ($null -eq $_.Exception.Response) { exit 1 };
$bytes = [Text.Encoding]::UTF8.GetBytes([string]$_.ErrorDetails.Message)
};
$out = [Console]::OpenStandardOutput();
$out.Write($bytes, 0, $bytes.Length);
$out.Flush();
exit 0
PS
_HTTP_PS_SCRIPT="${_HTTP_PS_SCRIPT//$'\n'/ }"

# Send one request with whichever client http_detect_client chose.
# Usage: http_send PROFILE FAMILY METHOD URL BODY [HEADER...]
#   PROFILE  api: 10 s to connect, 30 s for the whole exchange
#            probe: 10 s for the whole exchange
#   FAMILY   4, 6 or any
# Output: the response body, also for an HTTP error status (curl -s does
# the same), so callers can show what the server said.
# Returns: 0 when a response arrived, non-zero when none did.
http_send() {
	local profile="$1" family="$2" method="$3" url="$4" body="$5"
	shift 5
	local headers=("$@")
	local h status
	local -a cmd

	case "$HTTP_CLIENT" in
	curl | curl.exe)
		# The exact command lines the program has always run. Timeouts
		# keep a hung API from blocking the whole run (this script
		# usually runs unattended via cron).
		cmd=("$HTTP_CLIENT" "-s")
		if [[ "$profile" == "probe" ]]; then
			[[ "$family" != "any" ]] && cmd+=("-$family")
			cmd+=("--max-time" "10")
		else
			cmd+=("--connect-timeout" "10" "--max-time" "30" "-X" "$method")
			for h in "${headers[@]}"; do
				cmd+=("-H" "$h")
			done
			[[ -n "$body" ]] && cmd+=("-d" "$body")
		fi
		cmd+=("$url")
		"${cmd[@]}"
		;;

	wget)
		# --content-on-error keeps the body of an error status, which wget
		# otherwise drops; --tries=1 because wget retries up to 20 times
		# by default, and curl never does. wget has no cap on the whole
		# exchange, so the read time limit takes curl's 30 s instead.
		cmd=("wget" "-q" "-O" "-")
		if [[ "$profile" == "probe" ]]; then
			[[ "$family" != "any" ]] && cmd+=("-$family")
			cmd+=("--timeout=10" "--tries=1")
		else
			cmd+=("--content-on-error" "--method=$method")
			for h in "${headers[@]}"; do
				cmd+=("--header=$h")
			done
			[[ -n "$body" ]] && cmd+=("--body-data=$body")
			cmd+=("--dns-timeout=10" "--connect-timeout=10" "--read-timeout=30" "--tries=1")
		fi
		cmd+=("$url")
		"${cmd[@]}"
		status=$?
		# 8 is "the server issued an error response": a response did
		# arrive, which curl -s reports as success.
		((status == 8)) && status=0
		return "$status"
		;;

	pwsh | pwsh.exe | powershell.exe)
		local max_time=30
		if [[ "$profile" == "probe" ]]; then
			max_time=10
			url=$(_http_family_url "$url" "$family") || return 1
		fi
		{
			printf '%s\n%s\n%s\n' "$method" "$url" "$max_time"
			for h in "${headers[@]}"; do
				printf '%s\n' "$h"
			done
			printf '\n%s' "$body"
		} | "$HTTP_CLIENT" -NoProfile -NonInteractive -Command "$_HTTP_PS_SCRIPT"
		;;

	*)
		echo "Error: No compatible HTTP client found (curl, GNU Wget or PowerShell)." >&2
		return 1
		;;
	esac
}

# Universal HTTP Request function (Cloudflare API, notifications)
# Usage: http_request "METHOD" "URL" "BODY" "HEADER1" "HEADER2" ...
# Returns: Response body on stdout, Status code 0 on success, 1 on failure.
# Note: For simple GET, BODY can be empty string "".
http_request() {
	local method="$1"
	local url="$2"
	local body="$3"
	shift 3
	http_send api any "$method" "$url" "$body" "$@"
}

# GET for the public IP lookups
# Usage: http_get "URL" [ipv4|ipv6|any]
http_get() {
	local url="$1"
	local family
	case "${2:-any}" in
	4 | ipv4) family=4 ;;
	6 | ipv6) family=6 ;;
	*) family=any ;;
	esac
	http_send probe "$family" GET "$url" ""
}

http_detect_client
