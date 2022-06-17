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

set -e

while [[ $# -gt 0 ]]
do
    case "$1" in
        -h|--help)
            echo "usage: $(basename $0) [OPTIONS] <git-range>"
            echo
            echo "    --signoffs    Enable checking of signoffs"
            echo "    --changelogs  Enable checking of changelogs"
            echo "    --schema      Enable checking of the commit schema format (conventional commits required)"
            echo
            echo "In all cases it checks if commits are leaked from"
            echo "hosted/staging to any other branch."
            echo
            echo "NOTE: In the case that none of the above flags are set"
            echo "      then they are all enabled by default."
            exit 1
            ;;
        -s|--signoffs)
            CHECK_SIGNOFFS=TRUE
            shift
            continue
            ;;
        -c|--changelogs)
            echo "The Changelog check is deprecated"
            shift
            continue
            ;;
        -v|--schema)
            CHECK_COMMIT_SCHEMA=TRUE
            shift
            continue
            ;;
        *)
            break
            ;;
    esac
done

function check_required_tools() {
    which awk >/dev/null || { echo >&2 "AWK is a required tool for the commit check. Please install it"; exit 1; }
}

check_required_tools

# Special case, no Signoff, Schema, or Changelog flags set -> Do all
if [ -z "$CHECK_SIGNOFFS" ] && [ -z "$CHECK_COMMIT_SCHEMA" ]; then
    CHECK_SIGNOFFS=TRUE
    CHECK_COMMIT_SCHEMA=TRUE
fi

# Unset the check, if it is an unversioned repo
if [ -n "${UNVERSIONED_REPOSITORY}" ]; then
    CHECK_COMMIT_SCHEMA=
fi

if [ -z "$COMMIT_RANGE" ] && [ -n "$CI_COMMIT_REF_NAME" ]
then
    # Gitlab unfortunately doesn't record base branches of commits when the PR
    # comes from Github, so we need to detect branch names of PRs manually, and
    # then reconstruct the correct range from that, by excluding all other
    # branches.
    case "$CI_COMMIT_REF_NAME" in
        pr_[0-9]*)
            EXCLUDE_LIST=$(mktemp)
            EXCLUDE_LIST_REMOVE=$(mktemp)
            git for-each-ref --format='%(refname)' | sort > $EXCLUDE_LIST
            git for-each-ref --format='%(refname)' --points-at $CI_COMMIT_REF_NAME | sort > $EXCLUDE_LIST_REMOVE
            TO_EXCLUDE="$(comm -23 $EXCLUDE_LIST $EXCLUDE_LIST_REMOVE | tr '\n' ' ')"
            COMMIT_RANGE="$CI_COMMIT_REF_NAME --not $TO_EXCLUDE"
            rm -f $EXCLUDE_LIST $EXCLUDE_LIST_REMOVE
            ;;
    esac
fi

if [ -z "$COMMIT_RANGE" ] && [ -n "$TRAVIS_BRANCH" ]
then
    COMMIT_RANGE="$TRAVIS_BRANCH..HEAD"
fi

if [ -z "$COMMIT_RANGE" ]
then
    # Just check previous commit if nothing else is specified.
    COMMIT_RANGE=HEAD~1..HEAD
fi

if [ -n "$1" ]
then
    echo >&2 "Checking range: $@:"
    git --no-pager log "$@"
    commits="$(git rev-list --no-merges "$@")"
else
    echo "Checking range: ${COMMIT_RANGE}:"
    git --no-pager log $COMMIT_RANGE
    commits="$(git rev-list --no-merges $COMMIT_RANGE)"
fi

function check_commit_for_signoffs() {
    local -r i="$1"
    COMMIT_MSG="$(git show -s --format=%B "$i")"
    COMMIT_USER_EMAIL="$(git show -s --format="%an <%ae>" "$i")"

    # Ignore commits that have git-subtree tags in them. They are a PITA both
    # to sign and add changelogs to, and signing should anyway be present in the
    # original repository.
    if echo "$COMMIT_MSG" | egrep "^git-subtree-[^:]+:" >/dev/null; then
        return
    fi

    if [ -n "${CHECK_SIGNOFFS}" ]; then
        # Ignore commits from dependabot[-preview], as it has Git user and Signed-off-by user differ.
        if echo "${COMMIT_USER_EMAIL}" | egrep "^dependabot(-preview)?\[bot\] <[0-9]+\+dependabot(-preview)?\[bot\]@users.noreply.github.com>$" >/dev/null; then
            return
        fi
        # Check that Signed-off-by tags are present.
        if ! echo "$COMMIT_MSG" | grep -F "Signed-off-by: ${COMMIT_USER_EMAIL}" >/dev/null; then
            echo >&2 "Commit ${i} is not signed off! Use --signoff with your commit."
            notvalid="$notvalid $i"
        fi
    fi

}

# If any commit in the range TARGET_BRANCH...{hosted,staging} matches a commit in the PR
function prevent_staging_and_hosted_leaks() {
    local -r pull_request_commit="$1"
    # Get the commits in the range TARGET_BRANCH...{hosted,staging}
    local -r target_branch_commits="$(git rev-list origin/${TARGET_BRANCH}...origin/hosted 2>/dev/null || git rev-list origin/${TARGET_BRANCH}...origin/staging)"
    for commit in ${target_branch_commits}; do
        if [[ "${commit}" = "${pull_request_commit}" ]]; then
            echo >&2 "The commit ${pull_request_commit} is present in the hosted or staging branch."
            echo >&2 "Please do not merge this code to another branch (pretty please)."
            exit 1
        fi
    done
}

function branch_exists_in_remote() {
    git remote show origin 2>/dev/null | grep -q -E "\b$1\b"
}

function check_conventional_commits() {
    local -r git_msg="$(git show -s --format=%B $1)"
    if ! echo "${git_msg}" | $(dirname $(realpath ${BASH_SOURCE[0]}))/commitlint/commitlint; then
        echo >&2 "Commit $1 does not adhere to the conventional commit specification, used in the Mender project"
        echo >&2 "See https://github.com/mendersoftware/mendertesting/blob/master/commitlint/grammar.md for more information"
        notvalid="$notvalid $1"
    fi
}

TARGET_BRANCH="${CI_EXTERNAL_PULL_REQUEST_TARGET_BRANCH_NAME:-master}"
notvalid=
for i in $commits
do
    # Check the conventional commits
    [ -n "${CHECK_COMMIT_SCHEMA}" ] && check_conventional_commits ${i}
    # Check signoffs and changelogs
    check_commit_for_signoffs ${i}
    # Prevent staging and hosted leaks
    if [[ ! "${TARGET_BRANCH}" =~ "hosted|staging" ]] && branch_exists_in_remote "(hosted|staging)"; then
        prevent_staging_and_hosted_leaks ${i}
    fi
done

if [ -n "$notvalid" ]
then
    exit 1
fi
