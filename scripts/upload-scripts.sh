#!/bin/bash
#
# Upload scripts to Cloudflare R2
# This script uploads main.sh and zh_main.sh to the R2 bucket
# Supports --env parameter for multi-environment deployments
#

set -euo pipefail

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_RESET='\033[0m'

# 解析环境参数
ENV_ARG=""
BUCKET_NAME="fuckits-scripts"

for arg in "$@"; do
    case $arg in
        --env=*)
            ENV_ARG="${arg#*=}"
            shift
            ;;
        --env)
            ENV_ARG="$2"
            shift 2
            ;;
    esac
done

# 根据环境调整 bucket 名称 (可选)
# 如果需要为不同环境使用不同的 bucket,可以在这里配置
# 例如: staging -> fuckits-scripts-staging, production -> fuckits-scripts
if [ -n "$ENV_ARG" ]; then
    echo -e "${C_CYAN}📦 Deploying to environment: ${ENV_ARG}${C_RESET}"
    # 可选:根据环境使用不同的 bucket
    # case "$ENV_ARG" in
    #     staging)
    #         BUCKET_NAME="fuckits-scripts-staging"
    #         ;;
    #     production)
    #         BUCKET_NAME="fuckits-scripts"
    #         ;;
    # esac
fi

echo -e "${C_CYAN}📤 Uploading scripts to R2 bucket: ${BUCKET_NAME}...${C_RESET}"

# Check if required files exist
if [ ! -f "main.sh" ]; then
    echo -e "${C_RED}Error: main.sh not found${C_RESET}"
    exit 1
fi

if [ ! -f "zh_main.sh" ]; then
    echo -e "${C_RED}Error: zh_main.sh not found${C_RESET}"
    exit 1
fi

# Check if wrangler is available
if ! command -v npx > /dev/null; then
    echo -e "${C_RED}Error: npx not found${C_RESET}"
    echo -e "${C_YELLOW}Please install Node.js and npm${C_RESET}"
    exit 1
fi

# Upload English script
echo -e "${C_YELLOW}📤 Uploading main.sh (English)...${C_RESET}"
npx wrangler r2 object put "${BUCKET_NAME}/en/main.sh" --file=main.sh

if [ $? -eq 0 ]; then
    echo -e "${C_GREEN}✅ English script uploaded successfully${C_RESET}"
else
    echo -e "${C_RED}❌ Failed to upload English script${C_RESET}"
    exit 1
fi

# Upload Chinese script
echo -e "${C_YELLOW}📤 Uploading zh_main.sh (Chinese)...${C_RESET}"
npx wrangler r2 object put "${BUCKET_NAME}/zh/main.sh" --file=zh_main.sh

if [ $? -eq 0 ]; then
    echo -e "${C_GREEN}✅ Chinese script uploaded successfully${C_RESET}"
else
    echo -e "${C_RED}❌ Failed to upload Chinese script${C_RESET}"
    exit 1
fi

echo -e "${C_GREEN}🎉 All scripts uploaded successfully!${C_RESET}"
echo -e "${C_CYAN}📝 Scripts are now available in R2 bucket: ${BUCKET_NAME}${C_RESET}"
echo -e "${C_CYAN}   - en/main.sh${C_RESET}"
echo -e "${C_CYAN}   - zh/main.sh${C_RESET}"
