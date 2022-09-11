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

export TEST_ROOT=$(dirname "$0")
[[ -f ${TEST_ROOT}/functions.sh ]] && . ${TEST_ROOT}/functions.sh
[[ -f ${TEST_ROOT}/config.sh ]] && . ${TEST_ROOT}/config.sh

is_debian || {
    log "SKIPPING under non Linux/Debian."
    exit 0
}

debian_setup
test_main
