#!/bin/bash
# Copyright 2022 Northern.tech AS
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
set -ex

function log() {
    echo "$(date) ${TEST_NAME:-"unknown"}/$$ $HOSTNAME $@"
}

function is_debian() {
    [[ "$(lsb_release -d 2> /dev/null)" =~ "Debian" ]] || [[ "$(cat /etc/issue 2> /dev/null)" =~ "Debian" ]]
}

function debian_setup() {
    local pin="${TEST_CONFIG[pin]}"
    local sopin="${TEST_CONFIG[sopin]}"

    log "running setup for debian"
    apt-get update
    apt-get install -qy softhsm2 softhsm2-common libsofthsm2 libengine-pkcs11-openssl opensc-pkcs11 opensc gnutls-bin openssl gawk
    echo "module: /usr/lib/softhsm/libsofthsm2.so" > /usr/share/p11-kit/modules/softhsm2.module
    mkdir -p /softhsm/tokens
    echo "directories.tokendir = /softhsm/tokens" > /softhsm/softhsm2.conf
    export SOFTHSM2_CONF=/softhsm/softhsm2.conf
    softhsm2-util --init-token --free --label unittoken1 --pin "$pin" --so-pin "$sopin"
    openssl genrsa -out "${TEST_CONFIG[privatekey_path]}" "${TEST_CONFIG[keylen]}"
    pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin "$pin" --write-object "${TEST_CONFIG[privatekey_path]}" --type privkey --id 0909 --label privatekey
    p11tool --login --provider=/usr/lib/softhsm/libsofthsm2.so --set-pin="$pin" --list-all-privkeys
}

function test_main() {
    local pin="${TEST_CONFIG[pin]}"
    local sopin="${TEST_CONFIG[sopin]}"
    local artifact="${TEST_CONFIG[artifact]}"

    [[ "$TEST_CONFIGURED" == "1" ]] || {
        log "test is not configured"
        return 1
    }
    "${TEST_CONFIG[mender_artifact]}" write module-image -T local-type -n ci-tests-artifact-1 -t ci-type-1 -o "$artifact"
    echo -ne "[openssl_init]\nengines=engine_section\n\n[engine_section]\npkcs11 = pkcs11_section\n\n[pkcs11_section]\nengine_id = pkcs11\nMODULE_PATH = /usr/lib/softhsm/libsofthsm2.so\ninit = 0\n" >> /etc/ssl/openssl.cnf
    p11tool --login --provider=/usr/lib/softhsm/libsofthsm2.so --set-pin="$pin" --list-all-privkeys | awk -v pin="$pin" -v menderartifact="${TEST_CONFIG[mender_artifact]}" -v artifact="$artifact" '/URL/{ rc=system(menderartifact" sign --key-pkcs11 \""$NF";pin-value="pin"\" "artifact); exit(rc); }' && log PASSED
}
