#!/bin/bash
# ============================================================================
# JAI MEATBOY - AthenaEnv v4 Build Script
# Builds ISO for PCSX2 emulator
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
ISO_DIR="${BUILD_DIR}/iso"
OUTPUT_DIR="${BUILD_DIR}/output"

# AthenaEnv release URL (v4)
ATHENA_RELEASE_URL="https://github.com/DanielSant0s/AthenaEnv/releases/latest/download"
ATHENA_ELF="athena.elf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  JAI MEATBOY - AthenaEnv v4 Build${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# ============================================================================
# CREATE DIRECTORIES
# ============================================================================

echo -e "${YELLOW}Creating build directories...${NC}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${ISO_DIR}"
mkdir -p "${OUTPUT_DIR}"

# ============================================================================
# DOWNLOAD ATHENA.ELF (if not present)
# ============================================================================

if [ ! -f "${BUILD_DIR}/${ATHENA_ELF}" ]; then
    echo -e "${YELLOW}Downloading AthenaEnv runtime...${NC}"

    # Try to download from GitHub releases
    if command -v curl &> /dev/null; then
        curl -L -o "${BUILD_DIR}/${ATHENA_ELF}" "${ATHENA_RELEASE_URL}/${ATHENA_ELF}" 2>/dev/null || true
    elif command -v wget &> /dev/null; then
        wget -O "${BUILD_DIR}/${ATHENA_ELF}" "${ATHENA_RELEASE_URL}/${ATHENA_ELF}" 2>/dev/null || true
    fi

    # Check if download succeeded
    if [ ! -f "${BUILD_DIR}/${ATHENA_ELF}" ] || [ ! -s "${BUILD_DIR}/${ATHENA_ELF}" ]; then
        echo -e "${RED}ERROR: Could not download athena.elf${NC}"
        echo ""
        echo "Please download athena.elf manually from:"
        echo "  https://github.com/DanielSant0s/AthenaEnv/releases"
        echo ""
        echo "And place it in: ${BUILD_DIR}/"
        exit 1
    fi

    echo -e "${GREEN}Downloaded athena.elf successfully${NC}"
else
    echo -e "${GREEN}Using existing athena.elf${NC}"
fi

# ============================================================================
# PREPARE ISO CONTENTS
# ============================================================================

echo -e "${YELLOW}Preparing ISO contents...${NC}"

# Clean ISO directory
rm -rf "${ISO_DIR}"/*

# Copy boot files
cp "${SCRIPT_DIR}/SYSTEM.CNF" "${ISO_DIR}/"
cp "${BUILD_DIR}/${ATHENA_ELF}" "${ISO_DIR}/ATHENA.ELF"

# Copy AthenaEnv configuration
cp "${SCRIPT_DIR}/athena.ini" "${ISO_DIR}/"

# Copy game scripts
cp "${SCRIPT_DIR}"/*.js "${ISO_DIR}/"

# Copy assets
mkdir -p "${ISO_DIR}/assets/levels"
cp "${SCRIPT_DIR}/assets/levels"/*.json "${ISO_DIR}/assets/levels/"

echo -e "${GREEN}ISO contents prepared${NC}"

# ============================================================================
# LIST ISO CONTENTS
# ============================================================================

echo ""
echo -e "${YELLOW}ISO Contents:${NC}"
find "${ISO_DIR}" -type f | sort | while read -r file; do
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "???")
    relpath="${file#${ISO_DIR}/}"
    printf "  %-40s %s bytes\n" "$relpath" "$size"
done
echo ""

# ============================================================================
# CREATE ISO
# ============================================================================

ISO_NAME="JaiMeatboy.iso"
ISO_PATH="${OUTPUT_DIR}/${ISO_NAME}"

echo -e "${YELLOW}Creating ISO image...${NC}"

# Try different ISO creation tools
if command -v mkisofs &> /dev/null; then
    echo "Using mkisofs..."
    mkisofs \
        -iso-level 1 \
        -l \
        -J \
        -A "JAIMEATBOY" \
        -V "JAIMEATBOY" \
        -sysid "PLAYSTATION" \
        -o "${ISO_PATH}" \
        "${ISO_DIR}"
elif command -v genisoimage &> /dev/null; then
    echo "Using genisoimage..."
    genisoimage \
        -iso-level 1 \
        -l \
        -J \
        -A "JAIMEATBOY" \
        -V "JAIMEATBOY" \
        -sysid "PLAYSTATION" \
        -o "${ISO_PATH}" \
        "${ISO_DIR}"
elif command -v xorriso &> /dev/null; then
    echo "Using xorriso..."
    xorriso \
        -as mkisofs \
        -iso-level 1 \
        -l \
        -J \
        -A "JAIMEATBOY" \
        -V "JAIMEATBOY" \
        -sysid "PLAYSTATION" \
        -o "${ISO_PATH}" \
        "${ISO_DIR}"
else
    echo -e "${RED}ERROR: No ISO creation tool found${NC}"
    echo ""
    echo "Please install one of the following:"
    echo "  - mkisofs (part of cdrtools)"
    echo "  - genisoimage"
    echo "  - xorriso"
    echo ""
    echo "On Debian/Ubuntu: sudo apt-get install genisoimage"
    echo "On macOS: brew install cdrtools"
    echo "On Fedora: sudo dnf install genisoimage"
    echo ""

    # Create a ZIP file as fallback
    echo -e "${YELLOW}Creating ZIP archive as fallback...${NC}"
    cd "${ISO_DIR}"
    zip -r "${OUTPUT_DIR}/JaiMeatboy.zip" .
    cd "${SCRIPT_DIR}"
    echo -e "${GREEN}Created ZIP: ${OUTPUT_DIR}/JaiMeatboy.zip${NC}"
    echo ""
    echo "You can convert this ZIP to ISO using online tools like mconverter.eu"
    exit 0
fi

# ============================================================================
# VERIFY ISO
# ============================================================================

if [ -f "${ISO_PATH}" ]; then
    ISO_SIZE=$(stat -f%z "${ISO_PATH}" 2>/dev/null || stat -c%s "${ISO_PATH}" 2>/dev/null || echo "unknown")
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  BUILD SUCCESSFUL!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "ISO created: ${GREEN}${ISO_PATH}${NC}"
    echo -e "Size: ${ISO_SIZE} bytes"
    echo ""
    echo -e "${YELLOW}To run in PCSX2:${NC}"
    echo "  1. Open PCSX2"
    echo "  2. Go to System > Boot ISO"
    echo "  3. Select: ${ISO_PATH}"
    echo ""
    echo -e "${YELLOW}For HostFS development (faster iteration):${NC}"
    echo "  1. In PCSX2, enable 'Enable Host Filesystem' in Settings > Emulation"
    echo "  2. Go to System > Start File..."
    echo "  3. Select: ${BUILD_DIR}/athena.elf"
    echo "  4. PCSX2 will load files from the athena folder"
    echo ""
else
    echo -e "${RED}ERROR: ISO creation failed${NC}"
    exit 1
fi
