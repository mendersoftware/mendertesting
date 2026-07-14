# Mender conventional commit specification

This is the contributor-facing spec that Mender PR templates and CONTRIBUTING
files link to. It states the rules a commit must follow. For the full rationale,
changelog structure, and release-notes policy, see the source-of-truth document:
<https://github.com/mendersoftware/mender-qa/blob/master/Documentation/commits-and-release-notes.md>.

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

## What CI enforces

CI gates **format only** — [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
plus a sign-off. Nothing else below is a CI gate: the `Ticket:` and `Changelog:`
trailers are never required by the linter, and scope is only checked where a repo
opts in to its own scope rules.

1. The subject MUST start with a lowercase `type` from the allowed set, an OPTIONAL
   `(scope)`, an OPTIONAL `!` breaking-change marker, then a `:` and a space.
2. `feat` MUST be used for a new feature; `fix` MUST be used for a bug fix.
3. A `(scope)` MAY follow the type: a noun for the affected component/area, e.g.
   `fix(deployments):`. Scope is free-form by default, but a repo MAY enforce its
   own allow-list (e.g. `mender-server` via its `commitlint.config.js`). Follow the
   local repo's linter.
4. The subject is a short summary with no trailing period, in the imperative mood.
5. A body MAY follow one blank line after the subject and is free-form.
6. Footers (git trailers) MAY follow one blank line after the body: a token, a
   `:` and a space, then a value. Use `-` in place of spaces in a token
   (e.g. `Signed-off-by`), except `BREAKING CHANGE` which MAY be used as a token.
7. Every commit MUST be signed off (`Signed-off-by:`), added by `git commit -s`.

### Allowed types

`feat`, `fix`, `perf`, `refactor`, `chore`, `ci`, `build`, `docs`, `test`, `style`, `revert`.

If a commit has no externally observable behavior change, the type is not `feat`/`fix`
— use `refactor`, `perf`, or `chore`.

## Breaking changes

A breaking change MAY be indicated by **either** (or both):

- a `!` marker after the type/scope: `feat(api)!:`, `fix(client)!:`; or
- a `BREAKING CHANGE:` footer carrying the migration detail.

```
feat(api)!: remove legacy /devices/list endpoint

BREAKING CHANGE: Clients must migrate to /devices/v2/list; the legacy
endpoint now returns 404.

Ticket: MEN-9420
Signed-off-by: Jane Developer <jane.developer@northern.tech>
```

## Trailers

All trailers are optional and never CI-gated, except `Signed-off-by:`, which is
required on every commit and enforced in CI.

| Trailer | Purpose |
|---|---|
| `Ticket: <id>` | Link to Jira (auto-linked in the changelog); `Ticket: None` for no ticket |
| `Changelog: None` | Omit this commit from the changelog |
| `Changelog: Commit` | Include the commit body in the changelog (default is subject only) |
| `Changelog: <sentence>` | Replace the changelog line with a user-facing sentence |
| `Deprecation: <sentence>` | Add an entry to the changelog's Deprecations section |
| `BREAKING CHANGE: <text>` | Migration detail for a breaking commit |
| `Signed-off-by: <name>` | Required on every commit |

Notes:

- By default (no `Changelog:` trailer) the changelog renders the **subject only**;
  the body stays in `git log`. Opt the body in with `Changelog: Commit`.
- Trailer values are capitalized: keyword values exactly as written (`Changelog: None`,
  `Changelog: Commit` — miscased forms are ignored, treated as no trailer), and free-text
  sentences start with an uppercase letter, since they are rendered to users as-is.
- A trailer value may span multiple lines; parsing stops at the next `Token:` line.
- `Deprecation:` announces an upcoming removal (the thing still works today). Use
  `!` / `BREAKING CHANGE:` only when behavior actually changes now.

### Changelog examples

```
fix(client): prevent crash when dbus restarts unexpectedly

Changelog: None
Ticket: MEN-5143
Signed-off-by: Ole Petter <ole.orhagen@northern.tech>
```

```
refactor(server): rename ReleaseOrImageFilter to ReleaseFilter

Changelog: None
```

```
feat(deployments): trim deployment logs that exceed the size limit

Changelog: Devices report log tails when uploads would exceed the size limit.
Ticket: MEN-9415
```
