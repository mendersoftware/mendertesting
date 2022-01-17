#!/bin/bash

set -e

while [[ $# -gt 0 ]]
do
    case "$1" in
        -h|--help)
            echo "usage: $(basename $0) [OPTIONS] <git-range>"
            echo
            echo "    --signoffs    Enable checking of signoffs"
            echo "    --changelogs  Enable checking of changelogs"
            echo
            echo "In all cases it checks if commits are leaked from"
            echo "hosted/staging to any other branch."
            echo
            echo "NOTE: In the case that none of the above flags are set"
            echo "      then they are both enabled by default."
            exit 1
            ;;
        -s|--signoffs)
            CHECK_SIGNOFFS=TRUE
            shift
            continue
            ;;
        -c|--changelogs)
            CHECK_CHANGELOGS=TRUE
            shift
            continue
            ;;
        *)
            break
            ;;
    esac
done

# Special case, no Signoff or Changelog flags set -> Do both
if [ -z $CHECK_SIGNOFFS ] && [ -z $CHECK_CHANGELOGS ]; then
    CHECK_SIGNOFFS=TRUE
    CHECK_CHANGELOGS=TRUE
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

function check_commit_for_signoffs_and_changelogs() {
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

    if [ -n "${CHECK_CHANGELOGS}" ]; then
        # Check that Changelog tags are present.
        if ! echo "$COMMIT_MSG" | grep -i "^ *Changelog:" >/dev/null; then
            echo >&2 "Commit ${i} doesn't have a changelog tag! Make a changelog entry for your commit (https://github.com/mendersoftware/mender/blob/master/CONTRIBUTING.md#changelog-tags)."
            notvalid="$notvalid $i"
        # Less than three words probably means something was misspelled, except for
        # None, Title, Commit and All.
        elif ! echo "$COMMIT_MSG" | egrep -i "^ *Changelog: *(None|Title|Commit|All|\S+(\s+\S+){2,}) *$" >/dev/null; then
            echo >&2 "Commit ${i} has less than three words in its changelog tag! Typo? (https://github.com/mendersoftware/mender/blob/master/CONTRIBUTING.md#changelog-tags)."
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

TARGET_BRANCH="${CI_EXTERNAL_PULL_REQUEST_TARGET_BRANCH_NAME:-master}"
notvalid=
for i in $commits
do
    # Check signoffs and changelogs
    check_commit_for_signoffs_and_changelogs ${i}
    # Prevent staging and hosted leaks
    if [[ ! "${TARGET_BRANCH}" =~ "hosted|staging" ]] && branch_exists_in_remote "(hosted|staging)"; then
        prevent_staging_and_hosted_leaks ${i}
    fi
done

if [ -n "$notvalid" ]
then
    exit 1
fi
