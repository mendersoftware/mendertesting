# Mender conventional commit specification

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

# Specification

    1. Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, and REQUIRED terminal colon and space (See #allowed-types for more information).
    2. The type feat MUST be used when a commit adds a new feature to your application or library.
    3. The type fix MUST be used when a commit represents a bug fix for your application.
    4. A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
    5. A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
    6. A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
    7. A commit body is free-form and MAY consist of any number of newline separated paragraphs.
    8. One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by a :<space> separator, followed by a string value (this is inspired by the git trailer convention). See #allowed-footers for more information.
    9. A footer’s token MUST use - in place of whitespace characters, e.g., Acked-by (this helps differentiate the footer section from a multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY also be used as a token.
    10. A footer’s value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
    11. Breaking changes MUST be indicated in the footer.
    12. A breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
    13. Types other than feat and fix MAY be used in your commit messages, e.g., docs: updated ref docs (See #allowed-types for more information).
    14. BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.
    15. A feat, fix or a BREAKING CHANGE must have a Ticket, and a Changelog in the footer. The allowed values for the Changelog is either freeform text, `Title`, `Commit`, or `None`. The allowed value for `Ticket` is a valid ticket reference or `None`.
    16. All commits must be signed off.

## Notes

Our grammar is taken from https://conventionalcommits.org with a few
notable modifications.

1. We do not support the exclamation mark in the commit header for breaking
   changes.


   Hence, a breaking change is done like:

```
feat(backend): Remove the v1 API

...
...

BREAKING CHANGE: Removed the v1 API from the backend

...
...

```

   As opposed to:

```
feat(backend)!: Remove the v1 API

...
...

```

2. A fix, feat, or BREAKING CHANGE requires both a Changelog, and a Ticket
   reference in the footer.

```
fix(changelog-generator): Remove brackets surrounding a ticket ref

...
...

Changelog: None
Ticket: MEN-5143
Signed-off-by: Ole Petter <ole.orhagen@northern.tech>

```

In any instance, both the Changelog, and/or the Ticket can be None.

3. All commits need to be signed off


## Changelog tags

Every commit requires a changelog tag to document what has changed from one
release to the next. Unlike commit messages, these should be written in a user
centric way.

### Changelog tag types

Below is the complete list of possible tags. See also examples in the next
section.

* `Changelog: <message>` - Use `<message>` as the changelog entry. Message can
  span multiple lines, but is terminated by two consecutive newlines.

* `Changelog: Title` - Use the commit title (the first line) as the changelog
  entry.

* `Changelog: Commit` - Use the entire commit message as a changelog entry (but
  see filtered content below).

* `Changelog: None` - Don't generate a changelog entry for this commit.

A few things are always filtered from changelog entries: `cherry picked from...`
lines and `Signed-off-by:`, which are standard Git strings. In addition, any
reverted commit will automatically remove the corresponding entry from the
changelog output.

One commit can have several changelog tags, which will generate several entries,
if desired.

#### Examples:

* Given the commit message:

  ```
  Fix crash when /etc/mender/mender.conf is empty.
  ```

  This message is understandable by a user, and can therefore be used as is:

  ```
  Fix crash when /etc/mender/mender.conf is empty.

  Changelog: Title
  ```

* However, given the commit message:
  ```
  Implement mutex locking around user data.
  ```

  This is very developer centric and doesn't tell the user what changed for
  him. In this case it's appropriate to give a different changelog message, like
  this:

  ```
  Implement mutex locking around user data.

  Changelog: Fix crash when updating user data fields.
  ```

* In some cases it's appropriate not to provide a changelog message, for
  instance:

  ```
  Refactor dataProcess(), no functionality change.
  ```

  This is has no visible effect, therefore it's appropriate to add:

  ```
  Refactor dataProcess(), no functionality change.

  Changelog: None
  ```


# allowed types

The allowed commit types are as follows:

* feat: A new feature
* fix: A bug fix
* chore - misc category, say comment nitpicks, spelling, etc.
* build: Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)
* ci: Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)
* docs: Documentation only changes
* perf: A code change that improves performance
* refactor: A code change that neither fixes a bug nor adds a feature
* style: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
* test: Adding missing tests or correcting existing tests


# allowed footers

In general our allowed footers are free-form key-values, with a few rules enforced in certain
cases for keywords we own, see rule number `15` for more information.

One notable addition is our Changelog tags, which can be overridden with a
scope. The use case here is in the instance you find it hard to split a commit
up, and it contains both a `fix`, and `feat` for instance. In this case, the
`Changelog` key should look like:

```
Changelog(fix): <some description of the fix for the Changelog>
Changelog(feat): <some description of the feature for the Changelog.
```

Which will add the individual entries to both entries in the Changelog.
