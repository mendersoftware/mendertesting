# Click Click Click Release Process

<!-- Last updated: 2025-09-23 -->

## Introduction

The Click Click Click release process aims to provide a lightweight and modular release workflow through GitLab CI/CD components. The process is designed to be flexible and adapt to different types of components being released.

**Common release actions** (applicable to all components):
- Changelog updates
- Mender documentation version updates
- License manifest generation
- Atlassian Compass deployment tracking
- JIRA version release

**Component-specific actions** (depending on the nature of what's being released):
- **Binary distribution packages** (.deb, .rpm) for system-level tools
- **Container images** for containerized applications
- **Yocto recipes** for embedded system components

## Process

### 🔍 First Click: Check Requirements
Before initiating a release, verify that all prerequisites are met:
- **No JIRA blockers** - Ensure no critical issues prevent the release
- **Team alignment** - No concerns raised during team meetings or stand-ups
- **Green pipelines** - All related CI/CD pipelines are green. The release will be triggered from the main branch

### 🧨 Second Click: Run the Show
Execute the release preparation and validation:
- **Review and merge Release Candidate** Review generated changelog PR `https://github.com/mendersoftware/<reposistory>/pulls?q=is%3Apr+is%3Aopen+label%3A%22autorelease%3A+pending%22`
- **Tag and publish the Release** - Trigger the manual job from `https://gitlab.com/Northern.tech/Mender/<reposistory>/-/jobs?statuses=MANUAL`

### 📦 Third Click: Deliver It
Review that all the Git-tag triggered actions complete successfully:
- **GitHub Release** - Verify that the Git tag and GitHub release were done
- **Automated Pull Requests** - Review and merge PRs for Mender Docs, changelogs, etc
- **Technical deliverables** - Verify the deliverables: Container images, binary packages, Yocto recipes
- **Documentation updates** - Verify the formalities: Mender Docs updated, JIRA version released, changelogs published, license manifest published
- **Communication** - Inform stakeholders and celebrate with pizza 🍕
- **Follow-up** - Monitor and assist downstream repositories that consume the release

## ASCII Flow Diagram

```
┌──────────────────┐
│  CI/CD Pipeline  │
│    Build, Test   │ ──┐
│       ...        │   │
│  (main branch)   │   │
└──────────────────┘   │
                       ▼
              ┌────────────┐                        ┌────────────────┐
              │ Release    │         Click,         │                │
              │ Candidate  │ ──────> Click, ──────> │ Git tag +      │
              │            │         Click!         │ GitHub Release │
              └────────────┘                        └────┬───────────┘
                                                         │
                                                         ▼
                                         ╔════════════════════════════════╗
                                         ║ 🔵 Common Release Actions      ║
                                         ║     (always executed)          ║
                                         ╠════════════════════════════════╣
                                         ║   Changelog                    ║──→ PR in mender-docs-changelog
                                         ║   release-docs-changelog.yml   ║
                                         ╟────────────────────────────────╢
                                         ║   Mender Docs version          ║──→ PR in mender-docs (version update)
                                         ║   release-mender-docs.yml      ║
                                         ╟────────────────────────────────╢
                                         ║   License manifest             ║──→ PR in mender-docs (license manifest update)
                                         ║   release-oslicenses-golang.yml║
                                         ║   TODO QA-1212                 ║
                                         ║   release-oslicenses-generic.yml ║
                                         ╟────────────────────────────────╢
                                         ║   Atlassian Compass            ║──→ Deployment tracking updated
                                         ║   release-compass.yml          ║
                                         ╟────────────────────────────────╢
                                         ║   JIRA version release         ║──→ All tickets mentioned ini the changelog marked with fixVersion
                                         ║   TODO QA-1211                 ║
                                         ║   release-jira-versions.yml    ║
                                         ╚════════════════════════════════╝
                                                  ║
                                                  ▼
                                         ╔════════════════════════════════╗
                                         ║ 🟡 Component-Specific Actions  ║
                                         ║      (optional/conditional)    ║
                                         ╠════════════════════════════════╣
                                         ║   Dist packages                ║──→ .deb, packages
                                         ║   release-dist-packages.yml    ║
                                         ╟────────────────────────────────╢
                                         ║   Container Image              ║──→ Images in Container Image Registry (Docker Hub, Mender Registry)
                                         ║   TODO QA-1183                 ║
                                         ║   release-container-images.yml ║
                                         ╟────────────────────────────────╢
                                         ║   Yocto recipe                 ║──→ PR in meta-mender
                                         ║   TODO QA-1213                 ║
                                         ║   release-yocto-recipe.yml     ║
                                         ╚════════════════════════════════╝
                                                  │
                                                  ▼
                                         ╔════════════════════════════════╗
                                         ║ 👤 Manual steps                ║
                                         ╠════════════════════════════════╣
                                         ║ 🟡 Submit PR to                ║──→ Updated formula in homebrew-core
                                         ║    Homebrew/homebrew-core      ║
                                         ╚════════════════════════════════╝
                                                  │
                                                  ▼
                                         ┌─────────────────────────┐
                                         │ 🍕 Pizza celebration 🍕 │
                                         └─────────────────────────┘
```

## Component Status

### Implemented Components
- **release-candidate.yml** - Creates release using release-please (the "Click Click Click" part)
- **release-mender-docs.yml** - Updates component versions in mender-docs
- **release-docs-changelog.yml** - Updates changelog in mender-docs-changelog
- **release-dist-packages.yml** - Triggers distribution package builds
- **release-compass.yml** - Updates Atlassian Compass deployment tracking
- **release-oslicenses-golang.yml** - Generates and publishes Open Source license manifest for Go projects

### TODO Components
- **release-oslicenses-generic.yml** - Generic license manifest generation (TODO QA-1212)
- **release-jira-versions.yml** - Automatically mark JIRA tickets with fixVersion (TODO QA-1211)
- **release-yocto-recipe.yml** - Update Yocto recipes with new version (TODO QA-1213)
- **release-container-images.yml** - Publish container images to registries (TODO QA-1183)

### 👤 Manual Steps
- **Homebrew formula submission** - Submit PR to Homebrew/homebrew-core with updated formula
