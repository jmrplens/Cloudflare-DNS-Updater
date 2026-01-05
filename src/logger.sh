#!/usr/bin/env bash

# Logger Module
# Supports Console (Colored) and File Logging (Plain)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
dGRAY='\033[1;30m'
NC='\033[0m' # No Color

LOG_FILE=""

# Initialize Logger
# Usage: logger_init "/path/to/logfile.log"
logger_init() {
    local log_path="$1"
    local log_dir
    log_dir=$(dirname "$log_path")
    
    # Create directory if needed
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null
    fi
    
    LOG_FILE="$log_path"
    
    # Rotation (Max 1MB)
    local max_size=$((1024 * 1024))
    if [[ -f "$LOG_FILE" ]]; then
        local size
        # Compatible size check using wc -c for portability
        size=$(wc -c < "$LOG_FILE" 2>/dev/null)
        size=${size//[[:space:]]/} # trim whitespace
        
        if [[ $size -gt $max_size ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            # simple header
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated." > "$LOG_FILE"
        fi
    else
        touch "$LOG_FILE" 2>/dev/null
    fi
}

# Generic Log Function
# Args: level_color level_label message is_error
_log() {
    local color="$1"
    local label="$2"
    local msg="$3"
    local is_error="$4"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Console Output (Colored)
    # Output to stderr (always, to avoid corrupting stdout when used in subshells)
    if ! is_silent || [[ "$is_error" == "true" ]]; then
        echo -e "${color}[${label}]${NC} ${msg}" >&2
    fi
    
    # File Output (Plain, if init)
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        echo "[${timestamp}] [${label}] ${msg}" >> "$LOG_FILE"
    fi
}

log_info() {
    _log "$BLUE" "INFO" "$1" "false"
}

log_success() {
    _log "$GREEN" "OK" "$1" "false"
}

log_warn() {
    _log "$YELLOW" "WARN" "$1" "false"
}

log_error() {
    _log "$RED" "ERROR" "$1" "true"
}

log_debug() {
    if is_debug; then
        _log "$dGRAY" "DEBUG" "$1" "false"
    fi
}

# Boolean Helpers
is_debug() {
    [[ "${DEBUG:-false}" == "true" ]]
}

is_silent() {
    [[ "${SILENT:-false}" == "true" ]]
}

# Helper to sanitize logs
sanitize_log() {
    local msg="$1"
    # Redact API Token
    if [[ -n "$CF_API_TOKEN" ]]; then
        msg="${msg//$CF_API_TOKEN/********}"
    fi
    # Redact Zone ID (optional, but good practice if requested)
    if [[ -n "$CF_ZONE_ID" ]]; then
        msg="${msg//$CF_ZONE_ID/********}"
    fi
    echo "$msg"
}

log_debug_redacted() {
    if is_debug; then
        local clean_msg
        clean_msg=$(sanitize_log "$1")
        _log "$dGRAY" "DEBUG" "$clean_msg" "false"
    fi
}
