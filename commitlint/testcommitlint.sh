#! /bin/bash

function commitlint() {
    $(dirname ${BASH_SOURCE[1]})/commitlint
}

function assert() {
    case $1 in
        true)
            shift
            local -r test_name="$1"
            shift
            if ! echo "$@" | commitlint; then
                echo >&2 "== Failed == ${test_name}"
                exit 1
            else
                echo >&2 "== Passed == ${test_name}"
            fi
            ;;
        false)
            shift
            local -r test_name="$1"
            shift
            if echo "$@" | commitlint; then
                echo >&2 "== Failed == ${test_name}"
                exit 1
            else
                echo >&2 "== Passed == ${test_name}"
            fi
            ;;
        *)
            ;;
    esac
}


assert "true" \
       "Base case" \
"chore(client): foobar"

assert "true" \
       "Base case (no scope)" \
       "chore: foobar"

assert "true" \
       "Changelog required when fix, or feat or breaking change!" \
"fix(client): foobar

Ticket: None
Changelog: None
"

assert "false" \
       "Ticket required when fix, or feat or breaking change!" \
"fix: foobar

Changelog: None
"

assert "false" \
       "fix requires a ticket" \
       "fix(client): foobar

Changelog: None
"

assert "false" \
       "fix requires a Changelog" \
       "fix(client): foobar

Ticket: None
"


assert "false" \
       "feat requires a Changelog" \
       "feat: foobar

Ticket: None
"


assert "true" \
       "Multiple paragraphs in the body" \
       "fix(client): foobar

Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Donec hendrerit tempor
tellus. Donec pretium posuere tellus. Proin quam nisl, tincidunt et, mattis
eget, convallis nec, purus. Cum sociis natoque penatibus et magnis dis
parturient montes, nascetur ridiculus mus. Nulla posuere. Donec vitae dolor.
Nullam tristique diam non turpis. Cras placerat accumsan nulla. Nullam rutrum.
Nam vestibulum accumsan nisl.

Lorem ipsum dolor sit amet, consectetuer adipiscing elit.  Donec hendrerit tempor tellus.  Donec pretium posuere tellus.  Proin quam nisl, tincidunt et, mattis eget, convallis nec, purus.  Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.  Nulla posuere.  Donec vitae dolor.  Nullam tristique diam non turpis.  Cras placerat accumsan nulla.  Nullam rutrum.  Nam vestibulum accumsan nisl.

Ticket: None
Changelog: None

"

assert "false" \
       "Body must have one line of air in between the header and the body" \
       "fix(client): foobar
Lorem ipsum dolor sit amet, consectetuer adipiscing elit.  Donec hendrerit tempor tellus.  Donec pretium posuere tellus.  Proin quam nisl, tincidunt et, mattis eget, convallis nec, purus.  Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.  Nulla posuere.  Donec vitae dolor.  Nullam tristique diam non turpis.  Cras placerat accumsan nulla.  Nullam rutrum.  Nam vestibulum accumsan nisl.

"

assert "false" \
       "Error fix misspelled as fx" \
       "fx(client): foobar

"

assert "false" \
       "BREAKING CHANGE requires a Changelog and a ticket" \
       "feat(client): foobar

BREAKING CHANGE: No more bueno
"

assert "true" \
       "BREAKING CHANGE requires a Changelog and a Ticket" \
       "chore(client): foobar

Ticket: None
Changelog: None

BREAKING CHANGE: No more bueno
"


assert "true" \
       "Chore handling lorem ipsum etc etc" \
       "chore(client): foobar


Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Donec hendrerit tempor
tellus. Donec pretium posuere tellus. Proin quam nisl, tincidunt et, mattis
eget, convallis nec, purus. Cum sociis natoque penatibus et magnis dis
parturient montes, nascetur ridiculus mus. Nulla posuere. Donec vitae dolor.
Nullam tristique diam non turpis. Cras placerat accumsan nulla. Nullam rutrum.
Nam vestibulum accumsan nisl.


Lorem ipsum dolor sit amet, consectetuer adipiscing elit.  Donec hendrerit tempor tellus.  Donec pretium posuere tellus.  Proin quam nisl, tincidunt et, mattis eget, convallis nec, purus.  Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.  Nulla posuere.  Donec vitae dolor.  Nullam tristique diam non turpis.  Cras placerat accumsan nulla.  Nullam rutrum.  Nam vestibulum accumsan nisl.


"


assert "false" \
       "No air in between body and footer" \
       "fix(client): foobar


Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Donec hendrerit tempor
tellus. Donec pretium posuere tellus. Proin quam nisl, tincidunt et, mattis
eget, convallis nec, purus. Cum sociis natoque penatibus et magnis dis
parturient montes, nascetur ridiculus mus. Nulla posuere. Donec vitae dolor.
Nullam tristique diam non turpis. Cras placerat accumsan nulla. Nullam rutrum.
Nam vestibulum accumsan nisl.
Ticket: None
Changelog: None

BREAKING CHANGE: No more bueno
"

assert "true" \
       "Changelog commit" \
       "fix(client): foobar

Changelog: Commit
Ticket: None
"

assert "true" \
       "Multiline Changelog commit" \
       "fix(client): foobar

Changelog: Lorem ipsum dolor sit amet, consectetuer adipiscing elit.  Donec hendrerit tempor tellus.  Donec pretium posuere tellus.  Proin quam nisl, tincidunt et, mattis eget, convallis nec, purus.  Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.  Nulla posuere.  Donec vitae dolor.  Nullam tristique diam non turpis.  Cras placerat accumsan nulla.  Nullam rutrum.  Nam vestibulum accumsan nisl.
Ticket: None

"

assert "true" \
       "With sign-off" \
       "fix(client): foobar

Changelog: Lorem ipsum dolor sit amet, consectetuer adipiscing elit.  Donec hendrerit tempor tellus.  Donec pretium posuere tellus.  Proin quam nisl, tincidunt et, mattis eget, convallis nec, purus.  Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.  Nulla posuere.  Donec vitae dolor.  Nullam tristique diam non turpis.  Cras placerat accumsan nulla.  Nullam rutrum.  Nam vestibulum accumsan nisl.
Ticket: None
Signed-off-by: Ole Petter <ole.orhagen@northern.tech>
"

assert "true" \
       "real commit check" \
"fix(changelog-generator): Remove brackets surrounding a ticket ref

Previously a ticket reference embedded in brackets would leave:

* [] Fix sending on closed signal channel
    ([MEN-4832](https://tracker.mender.io/browse/MEN-4832))

After this fix:

* Fix sending on closed signal channel
    ([MEN-4832](https://tracker.mender.io/browse/MEN-4832))

Changelog: None
Ticket: MEN-5143
Signed-off-by: Ole Petter <ole.orhagen@northern.tech>
"

assert "true" \
       "Ticket allowed in all cases" \
       "chore(changelog-generator): Remove brackets surrounding a ticket ref

Previously a ticket reference embedded in brackets would leave:

* [] Fix sending on closed signal channel
    ([MEN-4832](https://tracker.mender.io/browse/MEN-4832))

After this fix:

* Fix sending on closed signal channel
    ([MEN-4832](https://tracker.mender.io/browse/MEN-4832))

Ticket: MEN-5143
Signed-off-by: Ole Petter <ole.orhagen@northern.tech>
"


assert "false" \
       "BREAKING CHANGE vs BREAKING-CHANGE (this should fail due to missing Changelog)" \
       "chore(client): foobar

Changelog: None

BREAKING-CHANGE: No more bueno
"


assert "true" \
       "fix with cherry-pick footer" \
       "fix(client): foobar

Changelog: None
Ticket: None

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"

assert "false" \
       "Misspelled Title in the Changelog" \
       "fix(client): foobar

Changelog: Tilte
Ticket: None

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"

assert "true" \
       "Changelog with scope" \
       "fix(client): foobar

Changelog(fix): Title
Ticket: None

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"


assert "true" \
       "Changelog(s) with scope(s)" \
       "fix(client): foobar

Changelog(fix): Title
Changelog(feat): Lorem Ipsum Dorem.
Ticket: None

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"


assert "false" \
       "Changelog(s) with scope(s), misspelled Changelog" \
       "fix(client): foobar

Changelog(feat): Lorem Ipsum Dorem.
Changelog(fix): Tilte
Ticket: None

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"

assert "false" \
       "Misspelled Ticket: Noen" \
       "fix(client): foobar

Changelog(feat): Lorem Ipsum Dorem.
Changelog(fix): Title
Ticket: Noen

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"

assert "true" \
       "Proper ticket number" \
       "fix(client): foobar

Changelog: Title
Ticket: MEN-1234

Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
(cherry picked from commit 9ce8090ec2e4c7dc4a6ad428751a761254520106)
"

exit 0
