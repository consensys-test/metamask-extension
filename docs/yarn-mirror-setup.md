# Yarn GitHub Mirror Setup Guide

This guide explains how to set up and use GitHub releases as a mirror for Yarn binaries to avoid HTTP 429 rate limiting issues from repo.yarnpkg.com.

## Overview

The GitHub mirror solution provides:
- **Rate limit immunity**: Downloads from your own GitHub releases
- **High availability**: GitHub's infrastructure ensures reliable access
- **Caching**: Multiple levels of caching for optimal performance
- **Fallback mechanism**: Automatic fallback to repo.yarnpkg.com with retry logic
- **Version control**: Track which Yarn versions are used in your CI/CD

## Architecture

```
┌─────────────────┐
│ CI/CD Workflow  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐     ┌──────────────────┐
│ setup-yarn-from-mirror      │────▶│ GitHub Releases  │
│ (Custom Action)             │     │ (Primary Source) │
└─────────────────────────────┘     └──────────────────┘
         │                                     ▲
         │ (fallback)                          │
         ▼                                     │
┌─────────────────────────────┐     ┌──────────────────┐
│ repo.yarnpkg.com            │     │ mirror-yarn      │
│ (with retry logic)          │◀────│ workflow         │
└─────────────────────────────┘     └──────────────────┘
```

## Setup Steps

### 1. Initial Mirror Setup

First, manually trigger the mirror workflow to create the initial Yarn release:

```bash
# Using GitHub CLI
gh workflow run mirror-yarn-binaries.yml -f yarn-version=4.9.1

# Or use the GitHub UI:
# Actions → Mirror Yarn Binaries → Run workflow → Enter version 4.9.1
```

### 2. Verify Mirror Creation

Check that the release was created successfully:

```bash
gh release view yarn-v4.9.1
```

You should see:
- `yarn-4.9.1.js` - Main Yarn binary
- `yarn-4.9.1-checksums.txt` - SHA256 checksums
- `yarn-4.9.1-info.json` - Version metadata

### 3. Update Workflows

#### Option A: Full Migration (Recommended)

Replace all instances of:
```yaml
- name: Checkout and setup environment
  uses: MetaMask/action-checkout-and-setup@v1
  with:
    skip-allow-scripts: true
```

With:
```yaml
- name: Checkout and setup environment
  uses: ./.github/actions/checkout-and-setup-mirror
  with:
    skip-allow-scripts: true
```

#### Option B: Gradual Migration

For critical workflows, test the mirror setup first:
```yaml
- name: Checkout repository
  uses: actions/checkout@v4

- name: Setup Yarn from mirror
  uses: ./.github/actions/setup-yarn-from-mirror
  with:
    yarn-version: '4.9.1'
    skip-install: false
```

## Migration Script

Use this script to automatically update all workflows:

```bash
#!/bin/bash
# migrate-to-mirror.sh

find .github/workflows -name "*.yml" -o -name "*.yaml" | while read -r file; do
  if grep -q "MetaMask/action-checkout-and-setup@v1" "$file"; then
    echo "Updating $file..."
    sed -i.bak 's|MetaMask/action-checkout-and-setup@v1|./.github/actions/checkout-and-setup-mirror|g' "$file"
  fi
done

echo "Migration complete. Review changes with: git diff"
```

## Maintenance

### Adding New Yarn Versions

When upgrading to a new Yarn version:

1. Update the mirror:
   ```bash
   gh workflow run mirror-yarn-binaries.yml -f yarn-version=4.10.0
   ```

2. Update the default version in actions:
   - `.github/actions/setup-yarn-from-mirror/action.yml`
   - `.github/actions/checkout-and-setup-mirror/action.yml`

### Automated Updates

The mirror workflow runs weekly to check for new Yarn releases. You can also set up notifications:

```yaml
# .github/workflows/notify-yarn-updates.yml
name: Notify Yarn Updates
on:
  schedule:
    - cron: '0 9 * * 1' # Weekly on Mondays
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Check for new Yarn version
        run: |
          # Implementation to check and notify
```

## Performance Optimization

The solution includes multiple caching layers:

1. **GitHub Actions Cache**: Caches the Yarn binary locally
2. **Yarn Cache**: Caches dependencies in `.yarn/cache`
3. **Node Modules Cache**: Standard GitHub Actions Node.js caching

Cache hit rates in typical scenarios:
- First run: Downloads from GitHub mirror (~2s)
- Subsequent runs: Uses cached binary (~0.1s)
- After cache expiry: Re-downloads from mirror

## Troubleshooting

### Mirror Not Available

If the GitHub mirror isn't available, the action automatically falls back to repo.yarnpkg.com with exponential backoff:

```
⚠️  GitHub mirror not available, falling back to repo.yarnpkg.com with retry logic
❌ Attempt 1 failed, retrying in 2 seconds...
❌ Attempt 2 failed, retrying in 4 seconds...
✅ Downloaded from repo.yarnpkg.com on attempt 3
```

### Verification Failed

To verify the integrity of mirrored binaries:

```bash
# Download checksums
gh release download yarn-v4.9.1 --pattern "*checksums.txt"

# Verify locally
sha256sum -c yarn-4.9.1-checksums.txt
```

### Rate Limiting on GitHub

GitHub releases have generous rate limits:
- Authenticated: 5,000 requests/hour
- Workflow tokens: Higher limits

If you hit GitHub rate limits, consider:
1. Reducing parallel workflow runs
2. Implementing workflow concurrency limits
3. Using a dedicated GitHub App token

## Security Considerations

1. **Binary Integrity**: All binaries include SHA256 checksums
2. **Source Tracking**: Each release includes metadata about the source
3. **Access Control**: Use GitHub's release permissions to control who can modify mirrors
4. **Audit Trail**: All mirror operations are logged in GitHub Actions

## Rollback Procedure

If issues occur, rollback is straightforward:

1. Revert the workflow files:
   ```bash
   find .github/workflows -name "*.yml.bak" -exec sh -c 'mv "$0" "${0%.bak}"' {} \;
   ```

2. Or temporarily point to a specific known-good release:
   ```yaml
   - name: Setup Yarn
     run: |
       curl -fsSL https://github.com/${{ github.repository }}/releases/download/yarn-v4.9.1/yarn-4.9.1.js -o yarn.js
       chmod +x yarn.js
       ./yarn.js install
   ```

## Benefits Summary

1. **Eliminates HTTP 429 errors**: No more rate limiting from repo.yarnpkg.com
2. **Improved reliability**: GitHub's infrastructure is highly available
3. **Faster CI/CD**: Cached binaries and parallel downloads
4. **Version control**: Track and audit Yarn versions used
5. **Flexibility**: Easy to add custom patches or configurations

## Next Steps

1. Run the initial mirror workflow to create Yarn v4.9.1 release
2. Test on a single non-critical workflow
3. Monitor performance and stability
4. Gradually roll out to all workflows
5. Set up automated monitoring and updates