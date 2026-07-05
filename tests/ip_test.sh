#!/usr/bin/env bash
# Unit tests for src/ip.sh (IP detection and validation)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$TESTS_DIR/.."

function set_up() {
	export DEBUG="false" SILENT="true" FORCE="false"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/logger.sh"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/network.sh"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/src/ip.sh"
}

# --- get_ipv6_prefix64 ---

function test_prefix64_of_full_address() {
	assert_same "2a0c:5a84:b60e:8c00" \
		"$(get_ipv6_prefix64 "2a0c:5a84:b60e:8c00:7a55:36ff:fe04:bb9a")"
}

function test_prefix64_normalizes_leading_zeros() {
	assert_same "2001:db8:1:2" "$(get_ipv6_prefix64 "2001:0db8:0001:0002:0000:0000:0000:0001")"
}

function test_prefix64_expands_compressed_address() {
	assert_same "2001:db8:0:0" "$(get_ipv6_prefix64 "2001:db8::1")"
}

function test_prefix64_strips_cidr_suffix() {
	assert_same "2001:db8:0:0" "$(get_ipv6_prefix64 "2001:db8::1/64")"
}

function test_prefix64_strips_zone_id() {
	assert_same "fe80:0:0:0" "$(get_ipv6_prefix64 "fe80::1%eth0")"
}

# --- IP validation ---

function test_valid_ipv4_accepted() {
	assert_successful_code "$(is_valid_ipv4 "192.0.2.1")"
}

function test_ipv4_rejects_words() {
	assert_general_error "$(is_valid_ipv4 "not-an-ip")"
}

function test_ipv4_rejects_missing_octet() {
	assert_general_error "$(is_valid_ipv4 "192.0.2")"
}

function test_ipv4_rejects_ipv6() {
	assert_general_error "$(is_valid_ipv4 "2001:db8::1")"
}

function test_valid_ipv6_accepted() {
	assert_successful_code "$(is_valid_ipv6 "2001:db8::1")"
}

function test_ipv6_rejects_ipv4() {
	assert_general_error "$(is_valid_ipv6 "192.0.2.1")"
}

function test_ipv6_rejects_words() {
	assert_general_error "$(is_valid_ipv6 "not-an-ip")"
}

function test_ipv4_rejects_octets_over_255() {
	assert_general_error "$(is_valid_ipv4 "999.999.999.999")"
	assert_general_error "$(is_valid_ipv4 "256.0.0.1")"
}

function test_ipv4_accepts_leading_zero_octets() {
	assert_successful_code "$(is_valid_ipv4 "010.001.002.099")"
}

function test_ipv6_accepts_full_eight_groups() {
	assert_successful_code "$(is_valid_ipv6 "2a0c:5a84:b60e:8c00:7a55:36ff:fe04:bb9a")"
}

function test_ipv6_rejects_double_compression() {
	assert_general_error "$(is_valid_ipv6 "2001::db8::1")"
}

function test_ipv6_rejects_oversized_hextet() {
	assert_general_error "$(is_valid_ipv6 "12345::1")"
}

function test_ipv6_rejects_incomplete_address_without_compression() {
	assert_general_error "$(is_valid_ipv6 "1:2:3:4:5:6:7")"
}

function test_ipv6_rejects_full_address_with_trailing_compression() {
	assert_general_error "$(is_valid_ipv6 "1:2:3:4:5:6:7:8::")"
}

function test_ipv6_accepts_trailing_compression() {
	assert_successful_code "$(is_valid_ipv6 "1:2:3:4:5:6:7::")"
	assert_successful_code "$(is_valid_ipv6 "::1")"
}

# --- get_public_ipv4 fallback cascade ---

function fake_http_get_first_service_ok() {
	case "$1" in
	*icanhazip*) echo "192.0.2.55" ;;
	*) echo "" ;;
	esac
}

function fake_http_get_second_service_ok() {
	case "$1" in
	*icanhazip*) echo "" ;;
	*ifconfig.co*) echo "192.0.2.66" ;;
	*) echo "" ;;
	esac
}

function fake_http_get_third_service_ok() {
	case "$1" in
	*ipify*) echo "192.0.2.77" ;;
	*) echo "" ;;
	esac
}

function fake_http_get_garbage() {
	echo "<html>service error</html>"
}

function test_public_ipv4_from_first_service() {
	bashunit::mock http_get fake_http_get_first_service_ok
	assert_same "192.0.2.55" "$(get_public_ipv4)"
}

function test_public_ipv4_falls_back_to_second_service() {
	bashunit::mock http_get fake_http_get_second_service_ok
	assert_same "192.0.2.66" "$(get_public_ipv4)"
}

function test_public_ipv4_falls_back_to_third_service() {
	bashunit::mock http_get fake_http_get_third_service_ok
	assert_same "192.0.2.77" "$(get_public_ipv4)"
}

function test_public_ipv4_rejects_garbage_response() {
	bashunit::mock http_get fake_http_get_garbage
	assert_general_error "$(get_public_ipv4)"
	assert_empty "$(get_public_ipv4)"
}

# --- get_public_ipv6 external fallback ---

function fake_http_get_ipv6_ok() {
	echo "2001:db8::abcd"
}

function test_public_ipv6_external_fallback() {
	# Force the external path: no interface configured, no auto-detection
	NET_INTERFACE=""
	bashunit::mock get_default_interface true
	bashunit::mock http_get fake_http_get_ipv6_ok
	assert_same "2001:db8::abcd" "$(get_public_ipv6)"
}
