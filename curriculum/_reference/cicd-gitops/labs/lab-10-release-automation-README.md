# Lab 10: Release Automation

## Overview

In this lab, you'll implement automated release management including semantic versioning, changelog generation, and release workflows. You'll learn to automate the entire release process from version bumping to publishing.

**Duration**: 2-3 hours
**Difficulty**: Intermediate

## Prerequisites

- GitHub account
- Node.js 20+ installed
- Git configured with GPG signing (optional)
- Understanding of semantic versioning

## Learning Objectives

- Implement semantic versioning with conventional commits
- Automate changelog generation
- Create release workflows with GitHub Actions
- Set up release branching strategies
- Implement multi-package releases (monorepo)

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/release-automation-lab && cd ~/release-automation-lab

# Initialize project
npm init -y

# Install release tools
npm install -D semantic-release \
  @semantic-release/changelog \
  @semantic-release/git \
  @semantic-release/github \
  @semantic-release/exec \
  conventional-changelog-cli \
  commitizen \
  cz-conventional-changelog \
  husky \
  @commitlint/cli \
  @commitlint/config-conventional

# Initialize Git
git init
git branch -M main

# Create project structure
mkdir -p src .github/workflows

# Create sample application
cat > src/index.js << 'EOF'
const VERSION = require('../package.json').version;

function getVersion() {
  return VERSION;
}

function greet(name) {
  return `Hello, ${name}! Version: ${VERSION}`;
}

module.exports = { getVersion, greet };
EOF

# Update package.json
cat > package.json << 'EOF'
{
  "name": "release-demo",
  "version": "0.0.0",
  "description": "Release automation demo",
  "main": "src/index.js",
  "scripts": {
    "test": "echo 'Tests passed'",
    "build": "echo 'Build complete'",
    "semantic-release": "semantic-release",
    "changelog": "conventional-changelog -p angular -i CHANGELOG.md -s",
    "commit": "cz",
    "prepare": "husky install"
  },
  "config": {
    "commitizen": {
      "path": "cz-conventional-changelog"
    }
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/YOUR_ORG/release-demo.git"
  }
}
EOF
```

---

## Part 1: Guided Exercise - Conventional Commits and Changelog

### Step 1: Configure Commitizen and Commitlint

```bash
# Create commitlint config
cat > commitlint.config.js << 'EOF'
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation
        'style',    // Formatting
        'refactor', // Code restructuring
        'perf',     // Performance improvement
        'test',     // Tests
        'build',    // Build system
        'ci',       // CI configuration
        'chore',    // Maintenance
        'revert'    // Revert commit
      ]
    ],
    'subject-case': [2, 'always', 'lower-case'],
    'header-max-length': [2, 'always', 72]
  }
};
EOF

# Set up Husky hooks
npx husky install

# Add commit-msg hook
npx husky add .husky/commit-msg 'npx --no -- commitlint --edit "$1"'

# Add pre-commit hook
npx husky add .husky/pre-commit 'npm test'
```

### Step 2: Configure Semantic Release

```bash
# Create semantic-release config
cat > .releaserc.json << 'EOF'
{
  "branches": [
    "main",
    {
      "name": "beta",
      "prerelease": true
    },
    {
      "name": "alpha",
      "prerelease": true
    }
  ],
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
        "npmPublish": false
      }
    ],
    [
      "@semantic-release/git",
      {
        "assets": ["package.json", "CHANGELOG.md"],
        "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
      }
    ],
    "@semantic-release/github"
  ]
}
EOF
```

### Step 3: Create Release Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches:
      - main
      - beta
      - alpha
  workflow_dispatch:

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    name: Release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Build
        run: npm run build

      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: npx semantic-release
```

### Step 4: Practice Conventional Commits

```bash
# Make some commits
git add .
git commit -m "feat: add initial project structure"

# Add a new feature
echo "// New feature" >> src/index.js
git add .
git commit -m "feat(core): add greeting function

This adds a new greeting function that includes
the version number in the output.

BREAKING CHANGE: greeting now requires a name parameter"

# Fix a bug
echo "// Bug fix" >> src/index.js
git add .
git commit -m "fix: correct version display format"

# Add documentation
echo "# Release Demo" > README.md
git add .
git commit -m "docs: add README with usage instructions"

# View changelog
npm run changelog
cat CHANGELOG.md
```

---

## Part 2: Semi-Guided Exercise - Release Branching Strategy

### Objective

Implement a release branching strategy with:
- Release branches for stabilization
- Hotfix workflow
- Version tagging
- Release notes automation

### Requirements

1. **Configure release branches**

<details>
<summary>Click for branch configuration hint</summary>

```json
// .releaserc.json
{
  "branches": [
    "main",
    { "name": "release/*", "prerelease": false },
    { "name": "hotfix/*", "prerelease": false },
    { "name": "develop", "prerelease": "dev" }
  ]
}
```
</details>

2. **Create release workflow**

<details>
<summary>Click for release workflow hint</summary>

```yaml
# Create release branch
- name: Create release branch
  run: |
    VERSION=$(npm pkg get version | tr -d '"')
    git checkout -b release/v$VERSION
    git push origin release/v$VERSION
```
</details>

3. **Implement hotfix process**

<details>
<summary>Click for hotfix hint</summary>

```yaml
# Hotfix workflow
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to hotfix (e.g., 1.2.3)'
        required: true

jobs:
  hotfix:
    steps:
      - name: Create hotfix branch
        run: |
          git checkout v${{ inputs.version }}
          git checkout -b hotfix/v${{ inputs.version }}-fix
```
</details>

### Tasks

1. Set up develop/main branching strategy
2. Create release branch automation
3. Implement hotfix workflow
4. Configure automatic cherry-picking
5. Set up release candidate workflow

### Validation

```bash
# Verify branch protection
gh api repos/:owner/:repo/branches/main/protection

# Check release tags
git tag -l "v*"

# Verify changelog
cat CHANGELOG.md | head -50

# Check release assets
gh release list
```

---

## Part 3: Challenge - Monorepo Release Management

### Objective

Implement release management for a monorepo with:
- Independent package versioning
- Coordinated releases
- Cross-package dependency management
- Consolidated changelog

### Requirements

1. **Set up monorepo structure**

```bash
# Create monorepo structure
mkdir -p packages/{core,utils,cli}

# Core package
cat > packages/core/package.json << 'EOF'
{
  "name": "@myorg/core",
  "version": "1.0.0",
  "main": "index.js"
}
EOF

# Utils package (depends on core)
cat > packages/utils/package.json << 'EOF'
{
  "name": "@myorg/utils",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "@myorg/core": "^1.0.0"
  }
}
EOF

# CLI package (depends on both)
cat > packages/cli/package.json << 'EOF'
{
  "name": "@myorg/cli",
  "version": "1.0.0",
  "bin": {
    "myorg": "./bin/cli.js"
  },
  "dependencies": {
    "@myorg/core": "^1.0.0",
    "@myorg/utils": "^1.0.0"
  }
}
EOF
```

2. **Configure Lerna or Changesets**

3. **Implement release workflow**

4. **Set up cross-package version sync**

### Success Criteria

- [ ] Independent package versions
- [ ] Coordinated releases possible
- [ ] Dependencies auto-updated
- [ ] Per-package changelogs
- [ ] Combined release notes
- [ ] NPM publishing works

### Starting Point - Changesets Configuration

```bash
# Install changesets
npm install -D @changesets/cli @changesets/changelog-github

# Initialize changesets
npx changeset init

# Configure changesets
cat > .changeset/config.json << 'EOF'
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": [
    "@changesets/changelog-github",
    { "repo": "YOUR_ORG/YOUR_REPO" }
  ],
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
EOF
```

### Starting Point - Monorepo Release Workflow

```yaml
# .github/workflows/release-monorepo.yml
name: Release Packages

on:
  push:
    branches:
      - main

concurrency: ${{ github.workflow }}-${{ github.ref }}

jobs:
  release:
    name: Release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          registry-url: 'https://registry.npmjs.org'

      - name: Install dependencies
        run: npm ci

      - name: Create Release Pull Request or Publish
        id: changesets
        uses: changesets/action@v1
        with:
          publish: npm run release
          version: npm run version
          commit: 'chore: release packages'
          title: 'chore: release packages'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Create GitHub releases
        if: steps.changesets.outputs.published == 'true'
        run: |
          for pkg in $(echo '${{ steps.changesets.outputs.publishedPackages }}' | jq -r '.[].name'); do
            version=$(echo '${{ steps.changesets.outputs.publishedPackages }}' | jq -r ".[] | select(.name == \"$pkg\") | .version")
            gh release create "${pkg}@${version}" \
              --title "${pkg}@${version}" \
              --generate-notes
          done
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Starting Point - Package Scripts

```json
{
  "scripts": {
    "build": "npm run build --workspaces",
    "test": "npm run test --workspaces",
    "version": "changeset version",
    "release": "npm run build && changeset publish",
    "changeset": "changeset",
    "changeset:status": "changeset status --verbose"
  },
  "workspaces": [
    "packages/*"
  ]
}
```

### Validation Script

```bash
#!/bin/bash
# validate-release-automation.sh

echo "Validating Release Automation..."

# Check semantic-release config
if [ -f ".releaserc.json" ] || [ -f "release.config.js" ]; then
    echo "✓ Semantic release configured"
else
    echo "⚠ No semantic-release config found"
fi

# Check commitlint config
if [ -f "commitlint.config.js" ]; then
    echo "✓ Commitlint configured"
else
    echo "⚠ No commitlint config found"
fi

# Check Husky hooks
if [ -d ".husky" ]; then
    HOOKS=$(ls .husky | grep -v "_" | wc -l)
    echo "✓ Husky configured with $HOOKS hooks"
else
    echo "⚠ No Husky hooks found"
fi

# Check release workflow
if [ -f ".github/workflows/release.yml" ]; then
    echo "✓ Release workflow exists"
else
    echo "⚠ No release workflow found"
fi

# Check changelog
if [ -f "CHANGELOG.md" ]; then
    ENTRIES=$(grep -c "^##" CHANGELOG.md)
    echo "✓ Changelog has $ENTRIES versions"
else
    echo "⚠ No changelog found"
fi

# Check for changesets (monorepo)
if [ -d ".changeset" ]; then
    CHANGESETS=$(ls .changeset/*.md 2>/dev/null | wc -l)
    echo "✓ Changesets configured ($CHANGESETS pending)"
fi

# Check conventional commits in recent history
CONVENTIONAL=$(git log --oneline -10 | grep -E "^[a-f0-9]+ (feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)" | wc -l)
echo "✓ $CONVENTIONAL/10 recent commits follow convention"

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove lab files
cd ~
rm -rf release-automation-lab

# Clean npm cache
npm cache clean --force
```

## Summary

In this lab, you learned:
- Implementing conventional commits with Commitizen
- Enforcing commit standards with Commitlint
- Automating releases with semantic-release
- Generating changelogs automatically
- Managing monorepo releases with Changesets
- Creating release branching strategies

## Next Steps

- Implement release previews for PRs
- Set up release notification channels
- Configure automated rollback on issues
- Implement release metrics and tracking

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Monorepo Release Management
- Configure Commitizen and Commitlint
- Configure Semantic Release
- Create Release Workflow

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
