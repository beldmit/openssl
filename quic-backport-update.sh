#!/bin/bash
# QUIC Medium Backport Update Script
# Updates QUIC client-side code from newer OpenSSL 3.5.x releases
#
# Usage: ./quic-backport-update.sh <source-tag>
# Example: ./quic-backport-update.sh openssl-3.5.9

set -e

BACKPORT_BRANCH="quic-35-backport-baseline"
SOURCE_TAG="$1"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <source-tag>"
    echo ""
    echo "Updates QUIC Medium Backport from a newer 3.5.x release."
    echo ""
    echo "Examples:"
    echo "  $0 openssl-3.5.9"
    echo "  $0 openssl-3.5.10"
    echo ""
    echo "This script will:"
    echo "  1. Create a tracking branch for the update"
    echo "  2. Update each backported file from the source tag"
    echo "  3. Attempt to build"
    echo "  4. Report conflicts and status"
    exit 1
}

if [ -z "$SOURCE_TAG" ]; then
    usage
fi

# Check if tag exists
if ! git rev-parse "$SOURCE_TAG" >/dev/null 2>&1; then
    echo -e "${RED}Error: Tag '$SOURCE_TAG' not found${NC}"
    echo "Available 3.5 tags:"
    git tag -l "openssl-3.5.*" | tail -10
    exit 1
fi

# Check if we're in the right repository
if [ ! -f "ssl/quic/quic_impl.c" ]; then
    echo -e "${RED}Error: Not in OpenSSL repository root${NC}"
    exit 1
fi

echo -e "${GREEN}=== QUIC Medium Backport Update ===${NC}"
echo "Source: $SOURCE_TAG"
echo "Target: $BACKPORT_BRANCH"
echo ""

# Checkout and create tracking branch
TRACKING_BRANCH="quic-backport-$(date +%Y%m%d)-$SOURCE_TAG"

echo -e "${YELLOW}Creating tracking branch: $TRACKING_BRANCH${NC}"
git checkout "$BACKPORT_BRANCH"
git checkout -b "$TRACKING_BRANCH"

# Layer 1: Foundation (Public API)
echo -e "${GREEN}=== Layer 1: Foundation ===${NC}"
FILES_LAYER1=(
    "include/openssl/quic.h"
)

for file in "${FILES_LAYER1[@]}"; do
    echo "Updating $file..."
    if git show "$SOURCE_TAG:$file" > "$file" 2>/dev/null; then
        git add "$file"
    else
        echo -e "${RED}  Warning: $file not found in $SOURCE_TAG${NC}"
    fi
done

# Layer 2: Infrastructure
echo -e "${GREEN}=== Layer 2: Infrastructure ===${NC}"
FILES_LAYER2=(
    "include/internal/quic_error.h"
    "include/internal/quic_types.h"
    "ssl/quic/quic_types.c"
    "ssl/quic/quic_txp.c"
)

for file in "${FILES_LAYER2[@]}"; do
    echo "Updating $file..."
    if git show "$SOURCE_TAG:$file" > "$file" 2>/dev/null; then
        git add "$file"
    else
        echo -e "${RED}  Warning: $file not found in $SOURCE_TAG${NC}"
    fi
done

# Layer 3: Stream Reassembly
echo -e "${GREEN}=== Layer 3: Stream Reassembly ===${NC}"
FILES_LAYER3=(
    "include/internal/quic_strm_reas.h"
    "ssl/quic/quic_strm_reas.c"
    "ssl/quic/quic_rstream.c"
    "include/internal/quic_stream.h"
)

for file in "${FILES_LAYER3[@]}"; do
    echo "Updating $file..."
    if git show "$SOURCE_TAG:$file" > "$file" 2>/dev/null; then
        git add "$file"
    else
        echo -e "${RED}  Warning: $file not found in $SOURCE_TAG${NC}"
    fi
done

# Layer 4: Connection ID Management
echo -e "${GREEN}=== Layer 4: Connection ID Management ===${NC}"
FILES_LAYER4=(
    "include/internal/quic_lcidm.h"
    "include/internal/quic_rcidm.h"
    "include/internal/quic_srtm.h"
    "include/internal/quic_srt_gen.h"
    "ssl/quic/quic_lcidm.c"
    "ssl/quic/quic_rcidm.c"
    "ssl/quic/quic_srtm.c"
    "ssl/quic/quic_srt_gen.c"
)

for file in "${FILES_LAYER4[@]}"; do
    echo "Updating $file..."
    if git show "$SOURCE_TAG:$file" > "$file" 2>/dev/null; then
        git add "$file"
    else
        echo -e "${RED}  Warning: $file not found in $SOURCE_TAG${NC}"
    fi
done

# Supporting Infrastructure
echo -e "${GREEN}=== Supporting Infrastructure ===${NC}"
FILES_SUPPORT=(
    "include/internal/quic_predef.h"
    "include/internal/list.h"
    "include/internal/ossl_rbtree.h"
)

for file in "${FILES_SUPPORT[@]}"; do
    echo "Updating $file..."
    if git show "$SOURCE_TAG:$file" > "$file" 2>/dev/null; then
        git add "$file"
    else
        echo -e "${RED}  Warning: $file not found in $SOURCE_TAG${NC}"
    fi
done

# Check for new CVE fixes in quic_fc.c
echo -e "${GREEN}=== Checking for Security Fixes ===${NC}"
echo "Reviewing changes to quic_fc.c..."
git diff "$BACKPORT_BRANCH" "$SOURCE_TAG" -- ssl/quic/quic_fc.c | head -50

echo ""
echo -e "${YELLOW}Review the diff above for new CVE fixes.${NC}"
echo "Press Enter to continue, or Ctrl+C to abort..."
read

# Commit the updates
echo -e "${GREEN}=== Committing Updates ===${NC}"
git commit -m "QUIC: Update Medium Backport from $SOURCE_TAG

Automated update of QUIC client-side components from $SOURCE_TAG.

Updated layers:
- Layer 1: Foundation (public API)
- Layer 2: Infrastructure
- Layer 3: Stream reassembly
- Layer 4: Connection ID management
- Supporting infrastructure

Manual review required for:
- New CVE fixes in quic_fc.c
- Build system changes
- Test suite updates

Co-Authored-By: quic-backport-update.sh
"

# Attempt build
echo -e "${GREEN}=== Building ===${NC}"
if make -j8 build_sw 2>&1 | tee build.log; then
    echo -e "${GREEN}Build SUCCEEDED${NC}"
else
    echo -e "${RED}Build FAILED - see build.log for details${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. New dependencies in source files"
    echo "  2. API changes requiring adaptation"
    echo "  3. Missing PORT/ENGINE infrastructure (expected for server code)"
    echo ""
    echo "Review build.log and fix manually, then:"
    echo "  git add <fixed-files>"
    echo "  git commit --amend"
    exit 1
fi

# Summary
echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
echo "Branch: $TRACKING_BRANCH"
echo ""
echo "Next steps:"
echo "  1. Review changes: git log $BACKPORT_BRANCH..$TRACKING_BRANCH"
echo "  2. Run tests: make test TESTS='test_quic*'"
echo "  3. Check for new CVEs in SECURITY_FIXES.md"
echo "  4. Merge to baseline: git checkout $BACKPORT_BRANCH && git merge $TRACKING_BRANCH"
echo ""
echo "Files updated:"
git diff --stat "$BACKPORT_BRANCH"
