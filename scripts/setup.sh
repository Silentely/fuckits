#!/bin/bash
#
# Setup script for fuckits
# This script helps configure the environment and set up secrets for deployment
#

set -euo pipefail

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_RESET='\033[0m'

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo -e "${C_CYAN}${C_BOLD}🚀 fuckits Setup Script${C_RESET}"
echo -e "${C_CYAN}================================${C_RESET}\n"

# Check for Node.js
echo -e "${C_YELLOW}Checking dependencies...${C_RESET}"
if ! command -v node > /dev/null; then
    echo -e "${C_RED}❌ Node.js is not installed${C_RESET}"
    echo -e "${C_YELLOW}Please install Node.js from https://nodejs.org/${C_RESET}"
    exit 1
fi
echo -e "${C_GREEN}✅ Node.js $(node --version) found${C_RESET}"

# Check for npm
if ! command -v npm > /dev/null; then
    echo -e "${C_RED}❌ npm is not installed${C_RESET}"
    exit 1
fi
echo -e "${C_GREEN}✅ npm $(npm --version) found${C_RESET}"

# Install dependencies
echo -e "\n${C_YELLOW}📦 Installing npm dependencies...${C_RESET}"
npm install

# Check for wrangler
if ! command -v wrangler > /dev/null && ! command -v npx > /dev/null; then
    echo -e "${C_RED}❌ wrangler not found and cannot be installed${C_RESET}"
    exit 1
fi
echo -e "${C_GREEN}✅ wrangler is available${C_RESET}"

# Login to Cloudflare
echo -e "\n${C_CYAN}🔐 Cloudflare Authentication${C_RESET}"
echo -e "${C_YELLOW}You need to authenticate with Cloudflare to deploy workers${C_RESET}"
read -p "Do you want to login to Cloudflare now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    npx wrangler login
    echo -e "${C_GREEN}✅ Cloudflare authentication complete${C_RESET}"
fi

# Configure API key
echo -e "\n${C_CYAN}🔑 OpenAI API Configuration${C_RESET}"
echo -e "${C_YELLOW}This secret only powers the shared demo Worker (200 calls/day). Encourage end users to set FUCK_OPENAI_API_KEY locally.${C_RESET}"
read -p "Do you want to set the shared Worker OpenAI API key now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -s -p "Enter your OpenAI API key: " OPENAI_API_KEY_VALUE
    echo
    if [ -n "$OPENAI_API_KEY_VALUE" ]; then
        printf '%s' "$OPENAI_API_KEY_VALUE" | npx wrangler secret put OPENAI_API_KEY
        echo -e "${C_GREEN}✅ API key configured${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠️ Skipped API key because no value was provided${C_RESET}"
    fi
fi

# Optional: Configure admin bypass key
echo -e "\n${C_CYAN}🛡️ Admin Bypass Key (Optional)${C_RESET}"
echo -e "${C_YELLOW}Provide this only to trusted teammates. Matching ${C_BOLD}FUCK_ADMIN_KEY${C_RESET} values let them skip the shared 200 calls/day limit.${C_RESET}"
read -p "Do you want to set the admin bypass key now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -s -p "Enter the admin bypass key: " ADMIN_ACCESS_KEY_VALUE
    echo
    if [ -n "$ADMIN_ACCESS_KEY_VALUE" ]; then
        printf '%s' "$ADMIN_ACCESS_KEY_VALUE" | npx wrangler secret put ADMIN_ACCESS_KEY
        echo -e "${C_GREEN}✅ Admin bypass key configured${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠️ Skipped admin key because no value was provided${C_RESET}"
    fi
fi

# Optional: Configure custom model
echo -e "\n${C_CYAN}🤖 AI Model Configuration (Optional)${C_RESET}"
echo -e "${C_YELLOW}Default model: gpt-5-nano${C_RESET}"
read -p "Do you want to set a custom model? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter the model name (e.g., gpt-4o, gpt-4.1-mini): " CUSTOM_MODEL
    update_wrangler_var "OPENAI_API_MODEL" "$CUSTOM_MODEL"
fi

# Optional: Configure custom API base
echo -e "\n${C_CYAN}🌐 API Base URL Configuration (Optional)${C_RESET}"
echo -e "${C_YELLOW}Default: https://api.openai.com/v1${C_RESET}"
read -p "Do you want to set a custom API base URL? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter the API base URL: " CUSTOM_BASE
    update_wrangler_var "OPENAI_API_BASE" "$CUSTOM_BASE"
fi

# Make scripts executable
echo -e "\n${C_YELLOW}🔧 Making scripts executable...${C_RESET}"
chmod +x scripts/*.sh
chmod +x main.sh
chmod +x zh_main.sh
echo -e "${C_GREEN}✅ Scripts are now executable${C_RESET}"

# Summary
echo -e "\n${C_GREEN}${C_BOLD}✨ Setup completed!${C_RESET}"
echo -e "\n${C_CYAN}Next steps:${C_RESET}"
echo -e "  1. ${C_YELLOW}npm run build${C_RESET}    - Build the worker with embedded scripts"
echo -e "  2. ${C_YELLOW}npm run deploy${C_RESET}   - Deploy to Cloudflare Workers"
echo -e "  3. ${C_YELLOW}npm run dev${C_RESET}      - Run local development server"
echo -e "\n${C_CYAN}For more information, see README.md${C_RESET}"
