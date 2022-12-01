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

# This regular expression can be set in the '.gitlab-ci.yml' file, and is passed
# on to the find expression used to aggregate all the files to check for license
# headers.
LICENSE_HEADERS_IGNORE_FILES_REGEXP="${LICENSE_HEADERS_IGNORE_FILES_REGEXP:-none}"

usage() {
    cat <<EOF
$(basename "$0") [--ent-start-commit=COMMIT]

Checks that all licenses in Go and Python files are correct.

--ent-start-commit=COMMIT
	For an Enterprise repository, specifies the earliest commit that is part
	of only Enterprise (the very first commit after the fork point).

If the FIRST_ENT_COMMIT env variable is set, the script uses its value for
the --ent-start-commit parameter.

Environment variables:

LICENSE_HEADERS_IGNORE_FILES_REGEXP:

  A regexp passed on to

    $(find . -type f \( ! -regex ${LICENSE_HEADERS_IGNORE_FILES_REGEXP} ...

  and can therefore be used to ignore files in a repository.
EOF
}

ENT_COMMIT="${FIRST_ENT_COMMIT}"

while [ -n "$1" ]; do
    case "$1" in
        --ent-start-commit=*)
            ENT_COMMIT="${1#--ent-start-commit=}"
            ;;
        --ent-start-commit)
            shift
            ENT_COMMIT="$1"
            ;;
        --verbose)
            set -x
            ;;
        *)
            echo >&2 "Unrecognized option $1"
            usage
            exit 1
            ;;
    esac
    shift
done

is_enterprise() {
    local file="$1"

    if [ -z "$ENT_COMMIT" ]; then
        # If there is no Enterprise commit specified, then this isn't an
        # Enterprise repository, so everything is Open Source.
        return 1
    fi

    # Find the latest commit that is not a descendant of the Enterprise
    # commit. This should be the latest Open Source commit. This doesn't change
    # over the course of a run, so cache it.
    if [ -z "$LATEST_OS_COMMIT" ]; then
        LATEST_OS_COMMIT=$(git rev-list $ENT_COMMIT..HEAD --ancestry-path --boundary --date-order \
                               | grep -v $ENT_COMMIT \
                               | grep "^-" \
                               | head -n1 \
                               | sed -e 's/[^0-9a-f]//')
        if [ -z "$LATEST_OS_COMMIT" ]; then
            # Very unlikely, but this can happen if every descendant commit of
            # ENT_COMMIT has no other ancestor. This can only happen if:
            #
            # 1) Open Source has never been merged into the repo after the fork.
            #
            # 2) ENT_COMMIT was pushed directly to the repo, instead of being
            #    merged.
            #
            # If so, the correct commit to set is $ENT_COMMIT~1
            LATEST_OS_COMMIT=$ENT_COMMIT~1
        fi
    fi

    # There is no commit before ENT_COMMIT, all code is enterprise
    if [ "$LATEST_OS_COMMIT" = "$ENT_COMMIT" ]; then
        return 0
    fi

    if git show $LATEST_OS_COMMIT:"$file" >& /dev/null; then
        # File exists, it's Open Source.
        return 1
    else
        # File does not exist, it's Enterprise.
        return 0
    fi
}

TEST_RESULT=0

strip_hashbang() {
    if [[ $#  -ne 1 ]]; then
        echo >&2 "strip_hashbang: Missing argument"
    fi
    tf=$(mktemp)
    local -r file="${1}"
    awk '!(NR == 1 && $1 ~/^#!.*/)' "${file}" > "${tf}"
    echo "${tf}"
}

check_file() {
    local file="$1"

    local license
    local lines
    local lic_type
    local -r CM="$2"
    local rc
    local -r tab=$'\t'

    cat > license-os.tmp <<-EOF
${CM}    Licensed under the Apache License, Version 2.0 (the "License");
${CM}    you may not use this file except in compliance with the License.
${CM}    You may obtain a copy of the License at
${CM}
${CM}        http://www.apache.org/licenses/LICENSE-2.0
${CM}
${CM}    Unless required by applicable law or agreed to in writing, software
${CM}    distributed under the License is distributed on an "AS IS" BASIS,
${CM}    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
${CM}    See the License for the specific language governing permissions and
${CM}    limitations under the License.
EOF
    LINES_OS=$(cat license-os.tmp | wc -l)
    # we need to add two extra lines missing from the license preamble
    # // Copyright <copyright_year> Northern.tech AS
    # //
    LINES_OS=$(($LINES_OS + 2))

    cat > license-ent.tmp <<-EOF
${CM}    All Rights Reserved
EOF
    LINES_ENT=$(cat license-ent.tmp | wc -l)
    # we need to add two extra lines missing from the license preamble
    # // Copyright <copyright_year> Northern.tech AS
    # //
    LINES_ENT=$(($LINES_ENT + 2))

    if is_enterprise ${file}; then
        license="license-ent.tmp"
        lines=$LINES_ENT
        lic_type="Enterprise"
    else
        license="license-os.tmp"
        lines=$LINES_OS
        lic_type="Open Source"
    fi

    modified_year=$(git log --follow --format=%ad --date=format:%Y -- "$file" | sort -n | tail -n 1)

    orig_file="${file}"
    file=$(strip_hashbang "${file}")

    head -n $lines "$file" | tail -n +3 | diff -u "$license" - > /dev/null
    rc=$?
    if [[ $rc -ne 0 ]]; then
        head -n $lines "$file" | sed -e "s/${tab}/    /g" | tail -n +3 | diff -u "$license" - > /dev/null
        rc=$?
    fi
    if [ $rc -ne 0 ]; then
        echo >&2 "!!! FAILED license check on ${orig_file}. Expected this $lic_type license:"
        cat "$license" >&2
        TEST_RESULT=1
    else
        copyright_modified=$(echo "${CM} Copyright <copyright_year> Northern.tech AS" | sed "s/<copyright_year>/$modified_year/g")
        copyright_file="$(head -n 1 "$file")"
        if [ "$copyright_modified" != "$copyright_file" ]; then
            echo >&2 "!!! FAILED license check on ${orig_file}; make sure copyright year matches last modified year of the file ($modified_year)"
            TEST_RESULT=1
        fi
    fi
    return ${TEST_RESULT}
}

check_files() {
    if [[ ! $# -ge 1 ]]; then
        echo >&2 "check_files requires one or more parameters"
    fi
    local -r SOURCE_FILES="$@"
    for source_file in ${SOURCE_FILES}; do
        case ${source_file} in
          *.go|*.[ch]|*.[ch]pp)
              CM='//'
              ;;
          *.py|*.sh)
              CM="#"
              ;;
          *)
              echo >&2 "No source file testing done for file:\n\t ${source_file}\nThe filetype is unsupported type"
              TEST_RESULT=1
              continue
              ;;
      esac
      check_file "${source_file}" "${CM}"
    done

    rm -f license-os.tmp license-ent.tmp
}

echo >&2 "LICENSE_HEADERS_IGNORE_FILES_REGEXP: ${LICENSE_HEADERS_IGNORE_FILES_REGEXP}"

echo >&2 "Checking licenses on all Go files"
GO_FILES="\
$(find . -type f ! -regex "${LICENSE_HEADERS_IGNORE_FILES_REGEXP}" ! -path './vendor/*' -name '*.go')
"
check_files "${GO_FILES}"

echo >&2 "Checking licenses on all Python files"
PYTHON_FILES="\
$(find . -type f ! -regex "${LICENSE_HEADERS_IGNORE_FILES_REGEXP}" ! -path './vendor/*' ! -regex '.*\.venv.*' ! -regex '.*build/.*' -name '*.py')"
check_files "${PYTHON_FILES}"

echo >&2 "Checking licenses on all Shell files"
SHELL_FILES="\
$(find . -type f ! -regex "${LICENSE_HEADERS_IGNORE_FILES_REGEXP}" ! -path './vendor/*' -name '*.sh')"
check_files "${SHELL_FILES}"

echo >&2 "Checking licenses on all C/C++ files"
C_FILES="\
$(find . -type f ! -regex "${LICENSE_HEADERS_IGNORE_FILES_REGEXP}" ! -path './vendor/*' \( -name '*.[ch]' -o -name '*.[ch]pp' \))"
check_files "${C_FILES}"

exit ${TEST_RESULT}
