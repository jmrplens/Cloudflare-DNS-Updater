#!/usr/bin/env bash
# Tests for local IPv6 interface detection in src/ip.sh (mocked `ip` command)

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
	NET_INTERFACE=""
}

# Realistic `ip` command replies: default route on eth0, global prefix
# 2a01:e0a:2c0:1230::/64, one temporary + one stable (mngtmpaddr) address
# and one ULA that must all be filtered correctly.
function fake_ip_healthy() {
	case "$*" in
	"route show default")
		echo "default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.10 metric 100"
		;;
	"-6 route show default")
		echo "default via fe80::1 dev eth0 proto ra metric 1024 expires 1500sec hoplimit 64 pref medium"
		;;
	"-6 route show ::/0")
		echo ""
		;;
	"-6 route get "*)
		echo "2001:4860:4860::8888 from :: via fe80::1 dev eth0 proto ra src 2a01:e0a:2c0:1230:5054:ff:fe12:3456 metric 1024 hoplimit 64 pref medium"
		;;
	"-6 addr show dev eth0 scope global")
		cat <<'EOF'
    inet6 2a01:e0a:2c0:1230:abcd:ef01:2345:6789/64 scope global temporary dynamic
       valid_lft 86399sec preferred_lft 14399sec
    inet6 2a01:e0a:2c0:1230:5054:ff:fe12:3456/64 scope global dynamic mngtmpaddr noprefixroute
       valid_lft 86399sec preferred_lft 14399sec
    inet6 fd00::5054:ff:fe12:3456/64 scope global
       valid_lft forever preferred_lft forever
EOF
		;;
	*) : ;;
	esac
}

# Same interface but the only usable address is deprecated (preferred_lft 0)
function fake_ip_deprecated_only() {
	case "$*" in
	"route show default")
		echo "default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.10 metric 100"
		;;
	"-6 route show default" | "-6 route show ::/0")
		echo ""
		;;
	"-6 route get "*)
		echo ""
		;;
	"-6 addr show dev eth0 scope global")
		cat <<'EOF'
    inet6 2a01:e0a:2c0:1230:5054:ff:fe12:3456/64 scope global dynamic mngtmpaddr
       valid_lft 86399sec preferred_lft 0sec
EOF
		;;
	*) : ;;
	esac
}

# No global IPv6 at all on the interface
function fake_ip_no_global_v6() {
	case "$*" in
	"route show default")
		echo "default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.10 metric 100"
		;;
	*)
		echo ""
		;;
	esac
}

function test_default_interface_detected_from_route() {
	bashunit::mock ip fake_ip_healthy
	assert_same "eth0" "$(get_default_interface)"
}

function test_route_prefix_from_route_get_fallback() {
	bashunit::mock ip fake_ip_healthy
	assert_same "2a01:e0a:2c0:1230" "$(get_ipv6_route_prefix)"
}

function test_interface_prefers_stable_address_on_preferred_prefix() {
	bashunit::mock ip fake_ip_healthy
	assert_same "2a01:e0a:2c0:1230:5054:ff:fe12:3456" "$(get_ipv6_from_interface "eth0")"
}

function test_interface_skips_temporary_and_ula_addresses() {
	bashunit::mock ip fake_ip_healthy
	local selected
	selected=$(get_ipv6_from_interface "eth0")
	assert_not_contains "abcd:ef01" "$selected"
	assert_not_contains "fd00" "$selected"
}

function test_interface_uses_deprecated_address_as_last_resort() {
	bashunit::mock ip fake_ip_deprecated_only
	assert_same "2a01:e0a:2c0:1230:5054:ff:fe12:3456" "$(get_ipv6_from_interface "eth0" 2>/dev/null)"
}

function test_interface_returns_empty_without_global_v6() {
	bashunit::mock ip fake_ip_no_global_v6
	assert_empty "$(get_ipv6_from_interface "eth0" 2>/dev/null)"
}

function test_public_ipv6_uses_local_interface_address() {
	bashunit::mock ip fake_ip_healthy
	assert_same "2a01:e0a:2c0:1230:5054:ff:fe12:3456" "$(get_public_ipv6)"
}

function test_public_ipv6_falls_back_to_external_when_no_local() {
	bashunit::mock ip fake_ip_no_global_v6
	bashunit::mock http_get fake_external_v6
	assert_same "2001:db8::ee" "$(get_public_ipv6 2>/dev/null)"
}

function fake_external_v6() {
	echo "2001:db8::ee"
}
