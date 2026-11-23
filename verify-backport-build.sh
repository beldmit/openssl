#!/bin/bash
# QUIC Backport Build Verification Script
# Verifies shared library build with FIPS enabled

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== QUIC Backport Build Verification (Shared + FIPS) ===${NC}"
echo ""

# Clean previous build
echo "Cleaning previous build..."
make distclean >/dev/null 2>&1 || true

# Configure
echo -e "${YELLOW}>>> Configuring: shared enable-fips${NC}"
if ! ./config shared enable-fips; then
    echo -e "${RED}FAILED: Configure failed${NC}"
    exit 1
fi

# Build
echo -e "${YELLOW}>>> Building...${NC}"
if ! make -j8 2>&1 | tee build-verification.log | tail -20; then
    echo -e "${RED}FAILED: Build failed${NC}"
    echo "See build-verification.log for details"
    exit 1
fi

# Verify critical symbols are present in shared libraries
echo ""
echo -e "${YELLOW}>>> Verifying symbols in libcrypto.so...${NC}"
if ! nm -D libcrypto.so | grep -q "SipHash_Init"; then
    echo -e "${RED}WARNING: SipHash symbols not in libcrypto.so (expected - compiled into libssl)${NC}"
fi

echo -e "${YELLOW}>>> Verifying symbols in libssl.so...${NC}"
if ! nm -D libssl.so | grep -q "ossl_quic_rstream_new"; then
    echo -e "${RED}FAILED: QUIC symbols not found in libssl.so${NC}"
    exit 1
fi

echo -e "${GREEN}Symbol verification passed${NC}"

# Run test suite
echo ""
echo -e "${YELLOW}>>> Running test suite (HARNESS_JOBS=8)...${NC}"
if ! make test HARNESS_JOBS=8 2>&1 | tee test-verification.log | tail -50; then
    echo -e "${RED}FAILED: Test suite failed${NC}"
    echo "See test-verification.log for details"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Build Verification PASSED ===${NC}"
echo ""
echo "Build log: build-verification.log"
echo "Test log: test-verification.log"
