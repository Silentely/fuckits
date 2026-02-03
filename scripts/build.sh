#!/bin/bash
#
# Build script for fuckits (Cloudflare Worker)
# Since scripts are now served from R2, this script mainly validates the project structure
#

set -euo pipefail

# Ensure we're in the project root
if [ ! -f "worker.js" ] || [ ! -f "main.sh" ]; then
    echo -e "\033[0;31mError: This script must be run from the project root\033[0m"
    exit 1
fi

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_RESET='\033[0m'

echo -e "${C_CYAN}🔨 Building fuckits worker...${C_RESET}"

# Check if required files exist
if [ ! -f "main.sh" ]; then
    echo -e "${C_RED}Error: main.sh not found${C_RESET}"
    exit 1
fi

if [ ! -f "zh_main.sh" ]; then
    echo -e "${C_RED}Error: zh_main.sh not found${C_RESET}"
    exit 1
fi

if [ ! -f "worker.js" ]; then
    echo -e "${C_RED}Error: worker.js not found${C_RESET}"
    exit 1
fi

if [ ! -f "wrangler.toml" ]; then
    echo -e "${C_RED}Error: wrangler.toml not found${C_RESET}"
    exit 1
fi

# Check if scripts have executable permissions (optional but recommended)
if [ ! -x "main.sh" ]; then
    echo -e "${C_YELLOW}⚠️  Warning: main.sh is not executable (chmod +x main.sh)${C_RESET}"
fi

if [ ! -x "zh_main.sh" ]; then
    echo -e "${C_YELLOW}⚠️  Warning: zh_main.sh is not executable (chmod +x zh_main.sh)${C_RESET}"
fi

# Validate worker.js syntax (basic check)
echo -e "${C_YELLOW}📝 Validating worker.js syntax...${C_RESET}"
if ! node -c worker.js 2>/dev/null; then
    echo -e "${C_RED}❌ worker.js has syntax errors${C_RESET}"
    exit 1
fi

# Check if R2 bucket is configured
if ! grep -q "SCRIPTS_BUCKET" wrangler.toml; then
    echo -e "${C_RED}❌ Error: R2 bucket (SCRIPTS_BUCKET) not configured in wrangler.toml${C_RESET}"
    exit 1
fi

# Reminder to upload scripts to R2
echo -e "${C_CYAN}📦 Build validation passed!${C_RESET}"
echo -e "${C_YELLOW}⚠️  Remember to upload scripts to R2 before deploying:${C_RESET}"
echo -e "${C_CYAN}   npm run upload-scripts${C_RESET}"
echo -e ""
echo -e "${C_GREEN}✅ Build completed successfully!${C_RESET}"
echo -e "${C_CYAN}📄 Project structure validated, ready for deployment${C_RESET}"
