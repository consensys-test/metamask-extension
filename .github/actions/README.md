# GitHub Actions for Yarn Setup

This directory contains custom GitHub Actions to set up Yarn in CI/CD workflows while avoiding rate limiting issues.

## Available Actions

### 1. `setup-yarn-from-mirror`

Low-level action that downloads and sets up Yarn using GitHub releases as a mirror.

**Features:**
- Downloads from GitHub releases (avoids rate limiting)
- Falls back to repo.yarnpkg.com with retry logic
- Caches Yarn binary and dependencies
- Configurable Node.js and Yarn versions

**Usage:**
```yaml
- uses: ./.github/actions/setup-yarn-from-mirror
  with:
    yarn-version: '4.9.1'
    node-version: '22.15'
    skip-install: false
    github-token: ${{ github.token }}
```

### 2. `checkout-and-setup-mirror`

Drop-in replacement for `MetaMask/action-checkout-and-setup@v1` that uses the GitHub mirror.

**Usage:**
```yaml
- uses: ./.github/actions/checkout-and-setup-mirror
  with:
    skip-allow-scripts: true
    is-high-risk-environment: false
```

### 3. `setup-yarn-with-corepack` (Alternative)

Uses Node.js built-in Corepack to manage Yarn (from fix #2).

**Usage:**
```yaml
- uses: ./.github/actions/setup-yarn-with-corepack
  with:
    yarn-version: '4.9.1'
    skip-install: false
```

## Quick Migration Guide

Replace this:
```yaml
- uses: MetaMask/action-checkout-and-setup@v1
  with:
    skip-allow-scripts: true
```

With this:
```yaml
- uses: ./.github/actions/checkout-and-setup-mirror
  with:
    skip-allow-scripts: true
```

## Architecture Decision

We chose the GitHub mirror approach (fix #3) because:
1. **Complete control**: We manage our own mirror
2. **No external dependencies**: Reduces points of failure
3. **Better caching**: Multiple cache layers for performance
4. **Audit trail**: All downloads are tracked in releases

## Maintenance

- Mirror workflow runs weekly to check for updates
- Manual trigger available for immediate updates
- All mirrors include checksums for verification

See [docs/yarn-mirror-setup.md](../../docs/yarn-mirror-setup.md) for detailed setup and maintenance instructions.