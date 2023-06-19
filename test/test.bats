setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'
    load 'test_helper/bats-mock/load'

    # PATH to files to test
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../:$PATH"
}

@test 'assert_file_executable' {
  assert_file_executable update-cloudflare-records.sh
}

@test "config file exists" {
    assert_file_exist update-cloudflare-records.yaml
}

# @test "script run without arguments" {
#     update-cloudflare-records.sh
# }

# @test "script run with arguments" {
#     bash update-cloudflare-records.sh update-cloudflare-records.yaml
# }

@test "config file is loaded" {
    update-cloudflare-records.sh
    assert [ -n '$config_file' ]
}

@test "settings are loaded" {
    update-cloudflare-records.sh
    assert [ -n '$settings_cloudflare__zone_id' ]
    assert [ -n '$settings_cloudflare__zone_api_token' ]
    assert [ -n '$settings_misc__create_if_no_exist' ]
}

@test "domains settings are loaded" {
    update-cloudflare-records.sh
    assert [ -n '$domains__name' ]
    assert [ -n '$domains__ttl' ]
    assert [ -n '$domains__proxied' ]
    assert [ -n '$domains__ip_type' ]
    assert [ -n '$domains__ipv4' ]
    assert [ -n '$domains__ipv6' ]
}

