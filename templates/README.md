# GitLab CI/CD Components for Mender

<!-- Last updated: 2025-10-03 -->

This directory contains reusable GitLab CI/CD components for Mender projects. These components streamline common CI/CD tasks and implement the standardized release process.

## What are GitLab CI/CD Components?

GitLab CI/CD components are reusable pipeline configurations that can be shared across projects. They provide:
- **Modularity**: Break complex pipelines into manageable, reusable pieces
- **Consistency**: Ensure uniform CI/CD practices across all Mender projects
- **Versioning**: Use semantic versioning for controlled updates
- **Input validation**: Define required and optional inputs with defaults and descriptions

For comprehensive documentation, see the [official GitLab CI/CD Components documentation](https://docs.gitlab.com/ci/components/).

## Available Components

### Helper Components

#### commit-lint
Validates commit messages against conventional commit format using commitlint. A default commitlint config is fetched if the repo does not provide its own.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/commit-lint@~latest
    inputs:
      stage: test  # optional, default: test
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
      registry: ${CI_DEPENDENCY_PROXY_DIRECT_GROUP_IMAGE_PREFIX}  # optional
      commitlint-tag: latest  # optional, default: latest
```

#### brew-build
Tests Homebrew formula builds on macOS runners. Builds from source using current commit and runs brew test.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/brew-build@~latest
    inputs:
      formula: m/mender-artifact.rb  # required
      repo: mender-artifact  # optional, defaults to formula name
      stage: test  # optional, default: test
      runner: mac-runner  # optional, default: mac-runner
```

### Release Process Components (Click Click Click)

The Click Click Click (CCC) release process provides automated, consistent releases across all Mender components.

**Note:** Release components require environment variables that are already configured at the GitLab Mender group level:
- `GITHUB_BOT_TOKEN_REPO_FULL` - GitHub token with repository access
- `GITHUB_CLI_TOKEN` - GitHub CLI authentication token
- `COMPASS_JIRA_USER` - Atlassian Jira username (for release-compass)
- `COMPASS_JIRA_API_TOKEN` - Atlassian Jira API token (for release-compass)

#### release-candidate
Creates and manages release candidates using release-please and git-cliff for changelog generation.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-candidate@~latest
    inputs:
      github_repo: mendersoftware/mender-artifact  # required
      stage: publish  # optional, default: publish
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
      github_user_name: mender-test-bot  # optional, default: mender-test-bot
      github_user_email: mender@northern.tech  # optional, default: mender@northern.tech
```

#### release-compass
Updates Atlassian Compass deployment tracking when a release is published.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-compass@~latest
    inputs:
      compass_component_id: 12345abcd...  # required, find in Compass URL
      stage: publish  # optional, default: publish
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
```

#### release-dist-packages
Triggers distribution package builds in the mender-dist-packages repository. Validates package name against mender-dist-packages variables.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-dist-packages@~latest
    inputs:
      package: MENDER_ARTIFACT  # required, uppercase package name
      test-mender-dist-packages: true  # optional, default: true
      publish-mender-dist-packages: true  # optional, default: true
      mender-dist-packages-branch: master  # optional, default: master
      stage: publish  # optional, default: publish
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
```

#### release-docs-changelog
Updates changelog documentation in the mender-docs-changelog repository. Requires `.docs_header.md` and `CHANGELOG.md` in source repo.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-docs-changelog@~latest
    inputs:
      remote_changelog_file: 30.mender-artifact/docs.md  # required
      stage: publish  # optional, default: publish
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
      alpine-git-tag: latest  # optional, default: latest
      github_user_name: mender-test-bot  # optional, default: mender-test-bot
      github_user_email: mender@northern.tech  # optional, default: mender@northern.tech
```

#### release-mender-docs
Updates component versions in the mender-docs repository using the autoversion.py script.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-mender-docs@~latest
    inputs:
      component: mender-artifact  # required
      stage: publish  # optional, default: publish
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
      github_user_name: mender-test-bot  # optional, default: mender-test-bot
      github_user_email: mender@northern.tech  # optional, default: mender@northern.tech
```

#### release-oslicenses-golang
Generates and publishes Open Source license manifest for Go projects. Scans dependencies and creates license information for compliance purposes.

**Usage:**
```yaml
include:
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-oslicenses-golang@~latest
    inputs:
      remote_license_file: 302.Release-information/03.Open-source-licenses/30.mender-artifact/docs.md  # required
      golang_version: 1.24  # optional, default: 1.24
      golang_flags: ""  # optional, default: ""
      stage: publish  # optional, default: publish
      runner: hetzner-amd-beefy  # optional, default: hetzner-amd-beefy
      github_user_name: mender-test-bot  # optional, default: mender-test-bot
      github_user_email: mender@northern.tech  # optional, default: mender@northern.tech
```

## Other Components

The following components are currently not in use.
- `workstation-tools-repository.yml` - Source-able code to install workstation tools
- `device-components-repository.yml` - Source-able code to install device components


## Example: Complete Release Setup

Here's a complete example of setting up the Click Click Click release process for a component (from mender-artifact):

```yaml
# .gitlab-ci.yml
include:
  # Release CI/CD components
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-candidate@~latest
    inputs:
      github_repo: mendersoftware/mender-artifact
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-mender-docs@~latest
    inputs:
      component: mender-artifact
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-dist-packages@~latest
    inputs:
      package: MENDER_ARTIFACT
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-compass@~latest
    inputs:
      compass_component_id: abc123-your-component-id-here
  - component: $CI_SERVER_FQDN/Northern.tech/Mender/mendertesting/release-oslicenses-golang@~latest
    inputs:
      remote_license_file: 302.Release-information/03.Open-source-licenses/30.mender-artifact/docs.md

stages:
  - test
  - publish
```

