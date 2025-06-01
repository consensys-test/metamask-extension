#!/bin/bash
# Script to migrate GitHub Actions workflows to use Yarn GitHub mirror

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Yarn Mirror Migration Script${NC}"
echo "============================"

# Check directory
if [ ! -d ".github/workflows" ]; then
    echo -e "${RED}Error: .github/workflows directory not found${NC}"
    exit 1
fi

# Create backup
BACKUP_DIR=".github/workflows-backup-$(date +%Y%m%d-%H%M%S)"
cp -r .github/workflows "$BACKUP_DIR"
echo "Backup created: $BACKUP_DIR"

# Migrate files
MIGRATED=0
for file in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$file" ] || continue

    if grep -q "MetaMask/action-checkout-and-setup@v1" "$file"; then
        echo "Migrating: $(basename "$file")"
        sed -i.tmp 's|MetaMask/action-checkout-and-setup@v1|./.github/actions/checkout-and-setup-mirror|g' "$file"
        rm -f "${file}.tmp"
        ((MIGRATED++))
    fi
done

echo -e "\n${GREEN}Migration complete!${NC}"
echo "Files migrated: $MIGRATED"
echo ""
echo "Next steps:"
echo "1. Create Yarn mirror: gh workflow run mirror-yarn-binaries.yml -f yarn-version=4.9.1"
echo "2. Review changes: git diff .github/workflows"
echo "3. Test: gh workflow run example-with-mirror.yml"
echo "4. Commit: git add .github && git commit -m 'chore: migrate to Yarn GitHub mirror'"