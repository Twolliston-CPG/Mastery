# Module 10: Release Management

## Learning Objectives

By the end of this module, you will be able to:
- Implement semantic versioning strategies
- Automate changelog generation
- Create release workflows with proper tagging
- Manage release branches and hotfixes
- Implement release approval processes
- Coordinate releases across multiple services

## Introduction

Release management encompasses the processes and tools for planning, scheduling, and controlling software releases. Effective release management ensures predictable, traceable, and reversible deployments while maintaining clear communication with stakeholders.

## Semantic Versioning

### Version Format

**Semantic versioning**

```text
MAJOR . MINOR . PATCH
  │       │       └── bug fixes, no API change
  │       └────────── new features, backward compatible
  └────────────────── breaking changes
```

| From → to | Kind |
|---|---|
| `1.0.0` → `1.0.1` | Patch — a bug fix |
| `1.0.1` → `1.1.0` | Minor — a new feature, nothing broken |
| `1.1.0` → `2.0.0` | Major — something that was working now needs changing |
| `2.0.0-beta.1` | Pre-release |

**Pre-release identifiers**

| Identifier | Means |
|---|---|
| `alpha` | Early development, unstable, API may still move |
| `beta` | Feature complete, expect bugs |
| `rc` | Release candidate — ships unless something is found |
| `+build.123` | Build metadata; ignored when comparing versions |

The rule people get wrong: the major number is decided by **the consumer's experience**, not by how
much work it was. A one-line change that renames a field is a major bump; a three-month rewrite that
keeps every signature identical is a minor one.

### Automated Version Bumping

```yaml
# Automated version management
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Determine version bump
        id: version
        run: |
          # Analyze commits since last tag
          COMMITS=$(git log $(git describe --tags --abbrev=0)..HEAD --oneline)

          if echo "$COMMITS" | grep -qE "^.*(BREAKING CHANGE|!)"; then
            echo "bump=major" >> $GITHUB_OUTPUT
          elif echo "$COMMITS" | grep -qE "^.*(feat|feature):"; then
            echo "bump=minor" >> $GITHUB_OUTPUT
          else
            echo "bump=patch" >> $GITHUB_OUTPUT
          fi

      - name: Bump version
        id: bump
        run: |
          CURRENT=$(cat package.json | jq -r '.version')
          IFS='.' read -r major minor patch <<< "$CURRENT"

          case "${{ steps.version.outputs.bump }}" in
            major) NEW_VERSION="$((major + 1)).0.0" ;;
            minor) NEW_VERSION="${major}.$((minor + 1)).0" ;;
            patch) NEW_VERSION="${major}.${minor}.$((patch + 1))" ;;
          esac

          echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT

      - name: Update package.json
        run: |
          npm version ${{ steps.bump.outputs.new_version }} --no-git-tag-version
```

## Changelog Generation

### Conventional Commits

**Conventional Commits**

Format: <type>(<scope>): <description>

**Types:**

- feat: — New feature (MINOR version bump)
- fix: — Bug fix (PATCH version bump)
- docs: — Documentation only
- style: — Formatting, no code change
- refactor: Code restructuring
- perf: — Performance improvement
- test: — Adding tests
- chore: — Maintenance tasks
- ci: — CI/CD changes

Breaking Changes: Add BREAKING CHANGE: in footer or ! after type

**Examples:**

- feat(auth): add OAuth2 support
- fix(api): handle null response
- docs: update README
- feat(api)!: change endpoint structure
- refactor(core): simplify state management


### Automated Changelog

```yaml
# Generate changelog with semantic-release
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: npx semantic-release

---
# .releaserc.json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    [
      "@semantic-release/changelog",
      {
        "changelogFile": "CHANGELOG.md"
      }
    ],
    [
      "@semantic-release/npm",
      {
        "npmPublish": true
      }
    ],
    [
      "@semantic-release/git",
      {
        "assets": ["package.json", "CHANGELOG.md"],
        "message": "chore(release): ${nextRelease.version} [skip ci]"
      }
    ],
    "@semantic-release/github"
  ]
}
```

### Manual Changelog with Release Drafter

```yaml
# .github/release-drafter.yml
name-template: 'v$RESOLVED_VERSION'
tag-template: 'v$RESOLVED_VERSION'
categories:
  - title: 'Features'
    labels:
      - 'feature'
      - 'enhancement'
  - title: 'Bug Fixes'
    labels:
      - 'fix'
      - 'bugfix'
      - 'bug'
  - title: 'Maintenance'
    labels:
      - 'chore'
      - 'maintenance'
  - title: 'Documentation'
    labels:
      - 'documentation'
      - 'docs'
  - title: 'Security'
    labels:
      - 'security'
  - title: 'Breaking Changes'
    labels:
      - 'breaking'

change-template: '- $TITLE @$AUTHOR (#$NUMBER)'
change-title-escapes: '\<*_&'

version-resolver:
  major:
    labels:
      - 'major'
      - 'breaking'
  minor:
    labels:
      - 'minor'
      - 'feature'
  patch:
    labels:
      - 'patch'
      - 'fix'
      - 'bugfix'
  default: patch

template: |
  ## Changes

  $CHANGES

  ## Contributors

  $CONTRIBUTORS

---
# Workflow to update draft
name: Release Drafter

on:
  push:
    branches: [main]
  pull_request:
    types: [opened, reopened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  update-release-draft:
    runs-on: ubuntu-latest
    steps:
      - uses: release-drafter/release-drafter@v5
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Release Workflows

### Tag-Based Release

```yaml
# Release on tag push
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get version from tag
        id: version
        run: echo "version=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build
        run: |
          npm ci
          npm run build

      - name: Generate release notes
        id: notes
        run: |
          # Get commits since last tag
          PREV_TAG=$(git describe --tags --abbrev=0 HEAD^)
          NOTES=$(git log ${PREV_TAG}..HEAD --pretty=format:"- %s (%h)" --no-merges)
          echo "notes<<EOF" >> $GITHUB_OUTPUT
          echo "$NOTES" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ steps.version.outputs.version }}
          name: Release ${{ steps.version.outputs.version }}
          body: ${{ steps.notes.outputs.notes }}
          files: |
            dist/*
            CHANGELOG.md
          generate_release_notes: true
```

### Release Branch Workflow

```yaml
# Git flow release process
name: Create Release Branch

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g., 1.2.0)'
        required: true
        type: string

jobs:
  create-release-branch:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: develop

      - name: Create release branch
        run: |
          git checkout -b release/${{ inputs.version }}
          npm version ${{ inputs.version }} --no-git-tag-version
          git add package.json
          git commit -m "chore: bump version to ${{ inputs.version }}"
          git push origin release/${{ inputs.version }}

      - name: Create PR to main
        uses: peter-evans/create-pull-request@v5
        with:
          branch: release/${{ inputs.version }}
          base: main
          title: "Release ${{ inputs.version }}"
          body: |
            ## Release ${{ inputs.version }}

            This PR contains the release branch for version ${{ inputs.version }}.

            ### Checklist
            - [ ] All features complete
            - [ ] All tests passing
            - [ ] Documentation updated
            - [ ] Changelog reviewed

---
# Hotfix workflow
name: Create Hotfix

on:
  workflow_dispatch:
    inputs:
      issue:
        description: 'Issue number'
        required: true
        type: string
      description:
        description: 'Brief description'
        required: true
        type: string

jobs:
  create-hotfix:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main

      - name: Get current version
        id: version
        run: |
          CURRENT=$(cat package.json | jq -r '.version')
          IFS='.' read -r major minor patch <<< "$CURRENT"
          NEW_VERSION="${major}.${minor}.$((patch + 1))"
          echo "version=$NEW_VERSION" >> $GITHUB_OUTPUT

      - name: Create hotfix branch
        run: |
          git checkout -b hotfix/${{ steps.version.outputs.version }}
          git push origin hotfix/${{ steps.version.outputs.version }}

      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          branch: hotfix/${{ steps.version.outputs.version }}
          base: main
          title: "Hotfix ${{ steps.version.outputs.version }}: ${{ inputs.description }}"
          body: |
            Fixes #${{ inputs.issue }}

            ## Description
            ${{ inputs.description }}
```

## Release Approval

### Environment-Based Approval

```yaml
# Release with approval gates
name: Production Release

on:
  release:
    types: [published]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
      - run: ./deploy.sh staging

  e2e-tests:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run test:e2e
        env:
          BASE_URL: https://staging.example.com

  deploy-production:
    needs: e2e-tests
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build
      - run: ./deploy.sh production

      - name: Notify release
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Released ${{ github.event.release.tag_name }} to production"
            }
```

### Release Train

```yaml
# Scheduled release train
name: Weekly Release

on:
  schedule:
    # Every Tuesday at 10 AM UTC
    - cron: '0 10 * * 2'
  workflow_dispatch:

jobs:
  prepare-release:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.new_version }}
      changes: ${{ steps.changes.outputs.has_changes }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check for changes
        id: changes
        run: |
          LAST_RELEASE=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          if [ -z "$LAST_RELEASE" ]; then
            echo "has_changes=true" >> $GITHUB_OUTPUT
          else
            COMMITS=$(git rev-list ${LAST_RELEASE}..HEAD --count)
            if [ "$COMMITS" -gt 0 ]; then
              echo "has_changes=true" >> $GITHUB_OUTPUT
            else
              echo "has_changes=false" >> $GITHUB_OUTPUT
            fi
          fi

      - name: Calculate version
        if: steps.changes.outputs.has_changes == 'true'
        id: version
        run: |
          DATE=$(date +%Y.%m.%d)
          echo "new_version=$DATE" >> $GITHUB_OUTPUT

  create-release:
    needs: prepare-release
    if: needs.prepare-release.outputs.changes == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v${{ needs.prepare-release.outputs.version }}
          generate_release_notes: true
```

## Multi-Service Releases

### Monorepo Release

```yaml
# Release affected packages in monorepo
name: Release Packages

on:
  push:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.changes.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changed packages
        id: changes
        run: |
          CHANGED=$(npx lerna changed --json 2>/dev/null || echo "[]")
          MATRIX=$(echo $CHANGED | jq -c '[.[] | {name: .name, path: .location}]')
          echo "matrix=$MATRIX" >> $GITHUB_OUTPUT

  release:
    needs: detect-changes
    if: needs.detect-changes.outputs.matrix != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4

      - name: Release ${{ matrix.package.name }}
        working-directory: ${{ matrix.package.path }}
        run: |
          npm version patch
          npm publish
```

### Service Coordination

```yaml
# Coordinated multi-service release
name: Coordinated Release

on:
  workflow_dispatch:
    inputs:
      services:
        description: 'Services to release (comma-separated)'
        required: true
        type: string
      version:
        description: 'Release version'
        required: true
        type: string

jobs:
  release-services:
    runs-on: ubuntu-latest
    strategy:
      max-parallel: 1  # Sequential releases
      matrix:
        service: ${{ fromJson(format('[{0}]', inputs.services)) }}
    steps:
      - name: Trigger service release
        uses: peter-evans/repository-dispatch@v2
        with:
          repository: company/${{ matrix.service }}
          event-type: coordinated-release
          client-payload: |
            {
              "version": "${{ inputs.version }}",
              "coordinator": "${{ github.repository }}"
            }

      - name: Wait for deployment
        run: |
          # Poll for deployment completion
          for i in {1..30}; do
            STATUS=$(curl -s https://${{ matrix.service }}.example.com/health | jq -r '.version')
            if [ "$STATUS" = "${{ inputs.version }}" ]; then
              echo "Service ${{ matrix.service }} deployed successfully"
              exit 0
            fi
            sleep 10
          done
          echo "Deployment timeout"
          exit 1
```

## Release Communication

### Release Notes Template

```markdown
# Release v{{ version }}

## Highlights

{{ highlights }}

## What's New

### Features
{{ features }}

### Improvements
{{ improvements }}

### Bug Fixes
{{ fixes }}

## Breaking Changes

{{ breaking_changes }}

## Migration Guide

{{ migration_guide }}

## Known Issues

{{ known_issues }}

## Contributors

Thanks to everyone who contributed to this release:
{{ contributors }}

## Full Changelog

{{ full_changelog }}
```

### Automated Notifications

```yaml
# Notify on release
- name: Send Slack notification
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "blocks": [
          {
            "type": "header",
            "text": {
              "type": "plain_text",
              "text": "🚀 New Release: ${{ github.event.release.tag_name }}"
            }
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Repository:* ${{ github.repository }}\n*Release Notes:* ${{ github.event.release.html_url }}"
            }
          }
        ]
      }

- name: Update status page
  run: |
    curl -X POST https://api.statuspage.io/v1/pages/$PAGE_ID/incidents \
      -H "Authorization: OAuth ${{ secrets.STATUSPAGE_TOKEN }}" \
      -d '{
        "incident": {
          "name": "Release ${{ github.event.release.tag_name }}",
          "status": "resolved",
          "body": "Successfully deployed ${{ github.event.release.tag_name }}"
        }
      }'
```

## Hands-On Exercise

### Exercise: Implement Complete Release Management

1. Set up conventional commits with commitlint
2. Configure semantic-release for automated versioning
3. Create a release workflow with approval gates
4. Implement changelog generation
5. Set up release notifications

## Summary

- Semantic versioning provides clear version meaning and expectations
- Conventional commits enable automated changelog generation
- Release branches allow for stabilization before production
- Environment approvals provide quality gates for releases
- Multi-service releases require coordination and communication
- Automated notifications keep stakeholders informed

## Additional Resources

- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [semantic-release](https://semantic-release.gitbook.io/)
- [Release Drafter](https://github.com/release-drafter/release-drafter)

## Next Steps

In the next module, we'll explore feature flags and progressive delivery, learning how to safely release features to production incrementally.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Semantic Versioning
- Changelog Generation
- Release Workflows
- Release Approval

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
