setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'
    #load 'stubs'


    # PATH to files to test
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../:$PATH"

    # STUBS
    #stub_get_ip

    # Utils
    regexp_ipv4="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
    regexp_ipv6="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

}



# bats test_tags=files
@test 'script exists' {

    # Assert
    assert_file_exist cloudflare-dns.sh
}

# bats test_tags=files
@test 'script is executable' {

    # Assert
    assert_file_executable cloudflare-dns.sh
}

# bats test_tags=files
@test "config file exists" {

    # Assert
    assert_file_exist cloudflare-dns.yaml
}

# bats test_tags=run_script
@test "script run with arguments" {

    # Act
    run cloudflare-dns.sh dyndns-update cloudflare-dns.yaml

    # Assert
    assert_success
}

# bats test_tags=parser
@test "settings are loaded" {

    # Arrange
    source cloudflare-dns.sh

    # Act
    create_variables cloudflare-dns.yaml

    # Assert
    assert_equal $settings_cloudflare__zone_id '<your_id>'
    assert_equal $settings_cloudflare__zone_api_token '<your_token>'
    assert_equal $settings_misc__create_if_no_exist 'false'
}

# bats test_tags=parser
@test "domains settings are parsed" {

    # Arrange
    source cloudflare-dns.sh

    # Act
    create_variables cloudflare-dns.yaml

    # Assert
    assert_equal ${domains__name[0]} 'sub.example.com'
    assert_equal ${domains__name[1]} 'example.com'
    assert_equal ${domains__name[2]} 'other.example.com'
    assert_equal ${domains__ip_type[0]} 'external'
    assert_equal ${domains__ip_type[1]} 'external'
    assert_equal ${domains__ip_type[2]} 'internal'
    assert_equal ${domains__ipv4[0]} 'true'
    assert_equal ${domains__ipv4[1]} 'true'
    assert_equal ${domains__ipv4[2]} 'false'
    assert_equal ${domains__ipv6[0]} 'true'
    assert_equal ${domains__ipv6[1]} 'true'
    assert_equal ${domains__ipv6[2]} 'true'
    assert_equal ${domains__proxied[0]} 'true'
    assert_equal ${domains__proxied[1]} 'true'
    assert_equal ${domains__proxied[2]} 'false'
    assert_equal ${domains__ttl[0]} 'auto'
    assert_equal ${domains__ttl[1]} '3600'
    assert_equal ${domains__ttl[2]} 'auto'
}

# bats test_tags=get_ip
@test "get ip internal and print" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="internal"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    run get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_line --index 0 --regexp "Internal IPv4 is: $regexp_ipv4"
    assert_line --index 1 --regexp "Internal IPv6 is: $regexp_ipv6"
}

# bats test_tags=get_ip
@test "get ip external and print" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="external"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    run get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_line --index 0 --regexp "Current External IPv4 is: $regexp_ipv4"
    assert_line --index 1 --regexp "Current External IPv6 is: $regexp_ipv6"
}

# bats test_tags=get_ip
@test "return ip internal" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="internal"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_regex $ip4 $regexp_ipv4
    assert_regex $ip6 $regexp_ipv6
}

# bats test_tags=get_ip
@test "return ip external" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="external"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_regex $ip4 $regexp_ipv4
    assert_regex $ip6 $regexp_ipv6
}