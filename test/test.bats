setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'


    # PATH to files to test
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../:$PATH"

    # STUBS

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
@test "script run without arguments" {

    # Act
    run bash cloudflare-dns.sh dyndns-update

}

# bats test_tags=run_script
@test "script run with arguments" {

    # Act
    run bash cloudflare-dns.sh dyndns-update cloudflare-dns.yaml

    # Assert
    assert_success
}

# bats test_tags=read_files
@test "config file is loaded" {

    # Act
    run bash cloudflare-dns.sh dyndns-update

    # Assert
    assert [ -n '$config_file' ]
}

# bats test_tags=config_vars
@test "settings are loaded" {

    # Act
    run bash cloudflare-dns.sh

    # Assert
    assert [ -n '$settings_cloudflare__zone_id' ]
    assert [ -n '$settings_cloudflare__zone_api_token' ]
    assert [ -n '$settings_misc__create_if_no_exist' ]
}

# bats test_tags=config_vars
@test "domains settings are loaded" {

    # Act
    run bash cloudflare-dns.sh

    # Assert
    assert [ -n '$domains__name' ]
    assert [ -n '$domains__ttl' ]
    assert [ -n '$domains__proxied' ]
    assert [ -n '$domains__ip_type' ]
    assert [ -n '$domains__ipv4' ]
    assert [ -n '$domains__ipv6' ]
}

# bats test_tags=get_ip
@test "get ip internal" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="internal"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    run get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_success
    assert [ -n '$ip4' ]
    assert [ -n '$ip6' ]
}

# bats test_tags=get_ip
@test "get ip external" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="external"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    run get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_success
    assert [ -n '$ip4' ]
    assert [ -n '$ip6' ]
}

# @test "full run with fake data" {

#     # Stub the function
#     function  get_dns_record_ip() {
#         error_dom=false
#         is_proxied6=true
#         is_proxiable6=true
#         dns_record_ip6="2a0c:5a84:3203:cf00:5fdd:214f:bff5:a1e0"
#         dns_record_id_6="NULL"
#         is_proxied4=true
#         is_proxiable4=true
#         dns_record_ip4="0.0.0.0"
#         dns_record_id_4="NULL"
#      }
#     function  settings_validation() { echo "OK"; }
#     function  settings_domains_validation() { echo "OK"; }
#     function  get_api_settings() { echo "OK" "OK"; }
#     function  get_ip() { echo "OK"; }
#     export -f get_dns_record_ip
#     export -f settings_validation
#     export -f settings_domains_validation
#     export -f get_api_settings
#     export -f get_ip

#     # Arrange
#     readonly error_dom=false
#     readonly ip4="0.0.0.0"
#     readonly ip6="2a0c:5a84:3203:cf00:5fdd:214f:bff5:a1e0"

#     # Act
#     ./cloudflare-dns.sh dyndns-update cloudflare-dns.yaml

#     # Assert
# }