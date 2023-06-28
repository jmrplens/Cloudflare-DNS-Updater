##################################
# Common
##################################
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    # PATH to files to test
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../:$PATH"

    # Utils
    regexp_ipv4="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
    regexp_ipv6="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

    api_bad_response='{"result":null,"success":false,"errors":[{}],"messages":[]}'
    api_got_response='{"result":null,"success":true,"errors":[{}],"messages":[]}'

    api_read_response_ip4='
    {
        "result":[
            {
            "id":"a5d2j439be8b8a926a1a8544d0f33005",
            "zone_id":"6db5464bff8cf4bd6279331dcf13626d",
            "zone_name":"example.com",
            "name":"sub.example.com",
            "type":"A",
            "content":"1.2.3.4",
            "proxiable":true,
            "proxied":true,
            "ttl":1,
            "locked":false,
            "meta":{
                "auto_added":false,
                "managed_by_apps":false,
                "managed_by_argo_tunnel":false,
                "source":"primary"
                },
            "comment":null,
            "tags":[],
            "created_on":"2023-02-14T00:14:09.091759Z",
            "modified_on":"2023-02-14T00:14:09.091759Z"
            }
        ],
        "success":true,
        "errors":[],
        "messages":[],
        "result_info":{
            "page":1,
            "per_page":100,
            "count":1,
            "total_count":1,
            "total_pages":1
            }
    }'

    api_read_response_ip6='
    {
        "result":[
            {
            "id":"a5d2j439be8b8a926a1a8544d0f33005",
            "zone_id":"6db5464bff8cf4bd6279331dcf13626d",
            "zone_name":"example.com",
            "name":"sub.example.com",
            "type":"AAAA",
            "content":"1111:2222:3333:4444:5555:6666:7777:8888",
            "proxiable":true,
            "proxied":true,
            "ttl":1,
            "locked":false,
            "meta":{
                "auto_added":false,
                "managed_by_apps":false,
                "managed_by_argo_tunnel":false,
                "source":"primary"
                },
            "comment":null,
            "tags":[],
            "created_on":"2023-02-14T00:14:09.091759Z",
            "modified_on":"2023-02-14T00:14:09.091759Z"
            }
        ],
        "success":true,
        "errors":[],
        "messages":[],
        "result_info":{
            "page":1,
            "per_page":100,
            "count":1,
            "total_count":1,
            "total_pages":1
            }
    }'
}

function teardown() {
    rm -f cloudflare-dns.log
}


####################################################################################################
# FILES
####################################################################################################

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

####################################################################################################
# Run script
####################################################################################################

# bats test_tags=run_script
@test "script run with arguments" {

    # Act
    run cloudflare-dns.sh dyndns-update cloudflare-dns.yaml

    # Assert
    assert_success
}

# bats test_tags=run_script
@test "script run without arguments" {

    # Act
    run cloudflare-dns.sh dyndns-update

}

####################################################################################################
# Parser
####################################################################################################

# bats test_tags=parser
@test "settings are parsed" {

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
@test "API settings are parsed" {

    # Arrange
    source cloudflare-dns.sh

    # Act
    create_variables cloudflare-dns.yaml
    get_api_settings

    # Assert
    assert_equal $api_zone_id '<your_id>'
    assert_equal $api_zone_token '<your_token>'
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

# bats test_tags=parser
@test "extract domain settings from array \ a" {

    # Arrange
    source cloudflare-dns.sh
    domains__name[0]='sub.example.com'
    domains__name[1]='example.com'
    domains__name[2]='other.example.com'
    domains__ip_type[0]='external'
    domains__ip_type[1]='external'
    domains__ip_type[2]='internal'
    domains__ipv4[0]='true'
    domains__ipv4[1]='true'
    domains__ipv4[2]='false'
    domains__ipv6[0]='true'
    domains__ipv6[1]='true'
    domains__ipv6[2]='true'
    domains__proxied[0]='true'
    domains__proxied[1]='true'
    domains__proxied[2]='false'
    domains__ttl[0]='auto'
    domains__ttl[1]='3600'
    domains__ttl[2]='auto'
    def_ip_type_enabled=false
    def_ipv4_enabled=false
    def_ipv6_enabled=false
    def_proxied_enabled=false
    def_ttl_enabled=false

    # Act
    get_domain_settings 0

    # Assert
    assert_equal $domain_name 'sub.example.com'
    assert_equal $domain_ip_type 'external'
    assert_equal $enable_ipv4 'true'
    assert_equal $enable_ipv6 'true'
    assert_equal $domain_proxied 'true'
    assert_equal $domain_ttl 'auto'

}

# bats test_tags=parser
@test "extract domain settings from array \ b" {

    # Arrange
    source cloudflare-dns.sh
    domains__name[0]='sub.example.com'
    domains__name[1]='example.com'
    domains__name[2]='other.example.com'
    domains__ip_type[0]='external'
    domains__ip_type[1]='external'
    domains__ip_type[2]='internal'
    domains__ipv4[0]='true'
    domains__ipv4[1]='true'
    domains__ipv4[2]='false'
    domains__ipv6[0]='true'
    domains__ipv6[1]='true'
    domains__ipv6[2]='true'
    domains__proxied[0]='true'
    domains__proxied[1]='true'
    domains__proxied[2]='false'
    domains__ttl[0]='auto'
    domains__ttl[1]='3600'
    domains__ttl[2]='auto'
    def_ip_type_enabled=true
    def_ipv4_enabled=true
    def_ipv6_enabled=true
    def_proxied_enabled=true
    def_ttl_enabled=true

    # Act
    get_domain_settings 0

    # Assert
    assert_equal $domain_name 'sub.example.com'
    assert_equal $domain_ip_type 'external'
    assert_equal $enable_ipv4 'true'
    assert_equal $enable_ipv6 'false'
    assert_equal $domain_proxied 'true'
    assert_equal $domain_ttl 'auto'

}
####################################################################################################
# NETWORK
####################################################################################################

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
    if [ -v CI ] && [ $CI == true ]; then
        echo "Skipping IPv6 test on CI"
    else
        assert_line --index 1 --regexp "Internal IPv6 is: $regexp_ipv6"
    fi
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
    if [ -v CI ] && [ $CI == true ]; then
        echo "Skipping IPv6 test on CI"
    else
        assert_line --index 1 --regexp "Current External IPv6 is: $regexp_ipv6"
    fi
}

# bats test_tags=get_ip
@test "return ip internal \ a" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="internal"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_regex $ip4 $regexp_ipv4
    if [ -v CI ] && [ $CI == true ]; then
        echo "Skipping IPv6 test on CI"
    else
        assert_regex $ip6 $regexp_ipv6
    fi
}

# bats test_tags=get_ip
@test "return ip internal \ b" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="internal"
    local enable_ipv4=false
    local enable_ipv6=false

    # Act
    get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_equal $ip4 "NULL"
    if [ -v CI ] && [ $CI == true ]; then
        echo "Skipping IPv6 test on CI"
    else
        assert_equal $ip6 "NULL"
    fi
}

# bats test_tags=get_ip
@test "return ip external \ a" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="external"
    local enable_ipv4=true
    local enable_ipv6=true

    # Act
    get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_regex $ip4 $regexp_ipv4
    if [ -v CI ] && [ $CI == true ]; then
        echo "Skipping IPv6 test on CI"
    else
        assert_regex $ip6 $regexp_ipv6
    fi
}

# bats test_tags=get_ip
@test "return ip external \ b" {

    # Arrange
    source cloudflare-dns.sh
    local ip_type="external"
    local enable_ipv4=false
    local enable_ipv6=false

    # Act
    get_ip "$ip_type" "$enable_ipv4" "$enable_ipv6"

    # Assert
    assert_equal $ip4 "NULL"
    if [ -v CI ] && [ $CI == true ]; then
        echo "Skipping IPv6 test on CI"
    else
        assert_equal $ip6 "NULL"
    fi
}

@test "get DNS record IPv4" {

    # Arrange
    source cloudflare-dns.sh
    domain_name="test.me"
    zone_id="zone_id"
    zone_token="zone_token"
    enable_ipv4=true
    enable_ipv6=false

    # Stub functions
    function read_record() { echo "${api_read_response_ip4}"; }
    function api_validation() { return 0;}
    export -f read_record
    export -f api_validation

    # Act
    get_dns_record_ip $domain_name $zone_id $zone_token

    # Assert
    assert_equal $is_proxied4 "true"
    assert_equal $is_proxiable4 "true"
    assert_equal $dns_record_ip4 "1.2.3.4"
    assert_equal $dns_record_id_4 "a5d2j439be8b8a926a1a8544d0f33005"

    # Clean up
    unset -f read_record
    unset -f api_validation

}

@test "get DNS record IPv6" {

    # Arrange
    source cloudflare-dns.sh
    domain_name="test.me"
    zone_id="zone_id"
    zone_token="zone_token"
    enable_ipv4=false
    enable_ipv6=true

    # Stub functions
    function read_record() { echo "${api_read_response_ip6}"; }
    function api_validation() { return 0;}
    export -f read_record
    export -f api_validation

    # Act
    get_dns_record_ip $domain_name $zone_id $zone_token

    # Assert
    assert_equal $is_proxied6 "true"
    assert_equal $is_proxiable6 "true"
    assert_equal $dns_record_ip6 "1111:2222:3333:4444:5555:6666:7777:8888"
    assert_equal $dns_record_id_6 "a5d2j439be8b8a926a1a8544d0f33005"

    # Clean up
    unset -f read_record
    unset -f api_validation

}

####################################################################################################
# Cloudflare API
####################################################################################################

# bats test_tags=API
@test "API response validation" {

    # Arrange
    source cloudflare-dns.sh

    # Act & Assert
    run api_validation $api_bad_response "check_api.com" "IP"
    assert_line --partial "Error! Can't "
    run api_validation $api_got_response "check_api.com" "IP"
    assert_line --partial "Loaded "

}

# bats test_tags=API
@test "API push validation" {

    # Arrange
    source cloudflare-dns.sh

    # Act & Assert
    run push_validation $api_bad_response "IP"
    assert_line --partial "Error! Update IP Failed"
    run push_validation $api_got_response "IP"
    assert_line --partial "Pushed new IP"

}

# bats test_tags=API
@test "Read record" {

    # Arrange
    source cloudflare-dns.sh

    # Act
    run read_record "" "" "" ""

    # Assert
    assert_line --partial '"success":false'

}

# bats test_tags=API
@test "Write record" {

    # Arrange
    source cloudflare-dns.sh

    # Act
    run write_record "" "" "" "" "" "" "" ""

    # Assert
    assert_line --partial '"success":false'

}

# bats test_tags=API
@test "Up to date message" {

    # Arrange
    source cloudflare-dns.sh
    var1=A
    var2=B
    var3=C
    var4=D

    # Act
    run up_to_date $var1 $var2 $var3 $var4

    # Assert
    assert_line --partial $(echo "Current DNS record ${var1} of ${var2} is ${var3} and proxy status is ${var4}, no changes needed.")

}

####################################################################################################
# Format text
####################################################################################################

# bats test_tags=format_text
@test "format text" {

    # Arrange
    source cloudflare-dns.sh
    end_color=$(tput sgr0)
    done_fb=$(tput setab 2 && tput setaf 0 && tput bold)
    done_c=$(tput setaf 2 && tput bold)
    err_c=$(tput setaf 1)
    load_c=$(tput setaf 3 && tput bold)
    warn_c=$(tput setaf 3)
    blue_b_c=$(tput setaf 4 && tput bold)
    green_c=$(tput setaf 2)
    word="test"

    # Act & assert
    run done_fb_msg "test"
    assert_line "${done_fb}$word${end_color}"
    run done_msg "test"
    assert_line "${done_c}$word${end_color}"
    run error_msg "test"
    assert_line "${err_c}$word${end_color}"
    run warn_msg "test"
    assert_line "${warn_c}$word${end_color}"
    run load_msg "test"
    assert_line "${load_c}$word${end_color}"
    run blue_bold_msg "test"
    assert_line "${blue_b_c}$word${end_color}"
    run green_msg "test"
    assert_line "${green_c}$word${end_color}"
}
