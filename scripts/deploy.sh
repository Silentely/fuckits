#!/bin/bash
#
# Deploy script for fuckits
# This script builds the worker and deploys it to Cloudflare Workers using wrangler
#

set -euo pipefail

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_RESET='\033[0m'

# Ensure wrangler is installed
if ! command -v npx > /dev/null; then
    echo -e "${C_RED}npx not found. Please install Node.js${C_RESET}"
    exit 1
fi

if ! npx wrangler --version > /dev/null 2>&1; then
    echo -e "${C_YELLOW}⚠️ wrangler not found. Installing locally...${C_RESET}"
    npm install wrangler --save-dev
fi

echo -e "${C_CYAN}🔧 Running build script...${C_RESET}"
bash scripts/build.sh

# Warn if wrangler.toml still has placeholder KV namespace IDs
if grep -q 'YOUR_KV_NAMESPACE_ID' wrangler.toml 2>/dev/null; then
    echo -e "${C_YELLOW}⚠️  wrangler.toml contains placeholder KV namespace IDs.${C_RESET}"
    echo -e "${C_YELLOW}   Run: npx wrangler kv:namespace create \"AI_CACHE\" and update the id.${C_RESET}"
fi

echo -e "${C_CYAN}☁️ Deploying to Cloudflare Workers...${C_RESET}"

# Source common functions for deploy output filtering
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

npx wrangler deploy "$@" | _mask_deploy_output

echo -e "${C_GREEN}✅ Deployment completed successfully!${C_RESET}"
