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

# 版本递增（patch bump）— 部署时递增而非提交时
# 避免每次 commit 都产生版本号 + worker.js 变更
if [ -f "VERSION" ]; then
    NEW_VERSION=$(node -e "
        const fs = require('fs');
        const v = fs.readFileSync('VERSION', 'utf-8').trim();
        const parts = v.split('.');
        parts[2] = parseInt(parts[2] || 0) + 1;
        console.log(parts.join('.'));
    " 2>/dev/null)

    if [ -n "$NEW_VERSION" ]; then
        echo "$NEW_VERSION" > VERSION

        # 同步 package.json
        node -e "
            const fs = require('fs');
            const pkg = JSON.parse(fs.readFileSync('package.json', 'utf-8'));
            pkg.version = '$NEW_VERSION';
            fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        " 2>/dev/null

        echo -e "${C_CYAN}📦 Version bumped: ${NEW_VERSION}${C_RESET}"
    fi
fi

echo -e "${C_CYAN}📝 Generating changelog...${C_RESET}"
bash scripts/gen-changelog.sh

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
