#!/bin/bash
#
# One-Click Deploy Script for fuckits
# This script automates the entire deployment process
#

set -euo pipefail

# Colors
readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_RESET='\033[0m'

# Print banner
echo -e "${C_CYAN}${C_BOLD}"
cat << "EOF"
   __            _    _ _        _     
  / _|_   _  ___| | _(_) |_   __| |__  
 | |_| | | |/ __| |/ / | __| / _` '_ \ 
 |  _| |_| | (__|   <| | |_ | (_| | | |
 |_|  \__,_|\___|_|\_\_|\__(_)__,_| |_|
                                        
 🚀 One-Click Deploy Script
EOF
echo -e "${C_RESET}"

# Function to check command availability
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${C_RED}❌ $1 is not installed${C_RESET}"
        return 1
    fi
    echo -e "${C_GREEN}✅ $1 is available${C_RESET}"
    return 0
}

# Function to prompt for input
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    
    if [ "$is_secret" = "true" ]; then
        read -sp "${prompt}: " value
        echo
    else
        read -p "${prompt}: " value
    fi
    
    eval "$var_name='$value'"
}

# Function to confirm action
confirm() {
    local prompt="$1"
    read -p "${prompt} [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

update_wrangler_var() {
    local key="$1"
    local value="$2"

    if [ -z "$value" ]; then
        echo -e "${C_YELLOW}⚠️ Skipping ${key}: empty value${C_RESET}"
        return
    fi

    if ! command -v python3 > /dev/null; then
        echo -e "${C_RED}❌ python3 is required to edit wrangler.toml vars${C_RESET}"
        echo -e "${C_YELLOW}Please install python3 or edit wrangler.toml manually.${C_RESET}"
        return 1
    fi

    python3 - "$key" "$value" <<'PY'
import re, sys
from pathlib import Path

key = sys.argv[1]
value = sys.argv[2]
escaped = value.replace('\\', '\\\\').replace('"', '\\"')
path = Path('wrangler.toml')
text = path.read_text()

if '[vars]' not in text:
    text = text.rstrip() + '\n\n[vars]\n'

pattern = rf'(?m)^\s*{re.escape(key)}\s*=.*$'
if re.search(pattern, text):
    text = re.sub(pattern, f'{key} = "{escaped}"', text, count=1)
else:
    match = re.search(r'(\[vars\]\s*\n)', text)
    if match:
        start = match.end()
        text = text[:start] + f'{key} = "{escaped}"\n' + text[start:]
    else:
        text = text.rstrip() + f'\n\n[vars]\n{key} = "{escaped}"\n'

path.write_text(text)
PY

    echo -e "${C_GREEN}✅ Updated ${key} in wrangler.toml${C_RESET}"
}

echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 1: Environment Check${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

# Check dependencies
DEPS_OK=true
check_command "node" || DEPS_OK=false
check_command "npm" || DEPS_OK=false
check_command "curl" || DEPS_OK=false

if [ "$DEPS_OK" = "false" ]; then
    echo -e "\n${C_RED}❌ Missing required dependencies${C_RESET}"
    echo -e "${C_YELLOW}Please install the missing dependencies and try again${C_RESET}"
    exit 1
fi

echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 2: Install npm Dependencies${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

if [ ! -d "node_modules" ]; then
    echo -e "${C_YELLOW}📦 Installing npm packages...${C_RESET}"
    npm install
    echo -e "${C_GREEN}✅ Dependencies installed${C_RESET}"
else
    echo -e "${C_GREEN}✅ Dependencies already installed${C_RESET}"
fi

echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 3: Cloudflare Authentication${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

# Check if already logged in
if npx wrangler whoami &> /dev/null; then
    echo -e "${C_GREEN}✅ Already authenticated with Cloudflare${C_RESET}"
    npx wrangler whoami
else
    echo -e "${C_YELLOW}🔐 Cloudflare authentication required${C_RESET}"
    echo -e "${C_CYAN}This will open a browser window for authentication${C_RESET}"
    
    if confirm "Do you want to login now?"; then
        npx wrangler login
        echo -e "${C_GREEN}✅ Authentication successful${C_RESET}"
    else
        echo -e "${C_RED}❌ Deployment cancelled - authentication required${C_RESET}"
        exit 1
    fi
fi

echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 4: Configure OpenAI API${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

echo -e "${C_YELLOW}🔑 This secret only powers the shared demo Worker (10 calls/day). CLI users should still configure FUCK_OPENAI_API_KEY locally.${C_RESET}"
echo -e "${C_CYAN}Get your API key from: https://platform.openai.com/api-keys${C_RESET}\n"

if confirm "Do you want to set the shared Worker OpenAI API key now?"; then
    read -s -p "Enter your OpenAI API key: " OPENAI_API_KEY_VALUE
    echo
    if [ -n "$OPENAI_API_KEY_VALUE" ]; then
        printf '%s' "$OPENAI_API_KEY_VALUE" | npx wrangler secret put OPENAI_API_KEY
        echo -e "${C_GREEN}✅ API key configured${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠️ Skipping API key setup because no value was provided${C_RESET}"
    fi
else
    echo -e "${C_YELLOW}⚠️ Skipping API key setup${C_RESET}"
    echo -e "${C_YELLOW}You can set it later with: npx wrangler secret put OPENAI_API_KEY${C_RESET}"
fi

# Optional: Configure model
echo -e "\n${C_CYAN}🤖 AI Model Configuration (Optional)${C_RESET}"
echo -e "${C_YELLOW}Default: gpt-4-turbo${C_RESET}"
if confirm "Do you want to use a different model?"; then
    read -p "Enter model name (e.g., gpt-4o, gpt-4.1-mini): " CUSTOM_MODEL
    update_wrangler_var "OPENAI_API_MODEL" "$CUSTOM_MODEL"
fi

# Optional: Configure API base
echo -e "\n${C_CYAN}🌐 Custom API Base (Optional)${C_RESET}"
echo -e "${C_YELLOW}Default: https://api.openai.com/v1${C_RESET}"
echo -e "${C_YELLOW}Use this if you're using a proxy or alternative API${C_RESET}"
if confirm "Do you want to set a custom API base URL?"; then
    read -p "Enter the API base URL: " CUSTOM_BASE
    update_wrangler_var "OPENAI_API_BASE" "$CUSTOM_BASE"
fi

echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 5: Works Custom Domain${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

DEFAULT_DOMAIN="fuckits.25500552.xyz"
read -p "Enter your Works custom domain [${DEFAULT_DOMAIN}]: " CUSTOM_DOMAIN
CUSTOM_DOMAIN="${CUSTOM_DOMAIN:-$DEFAULT_DOMAIN}"

echo -e "${C_CYAN}👉 Bind ${CUSTOM_DOMAIN} (and ${CUSTOM_DOMAIN}/zh) to this Worker inside the Cloudflare Dashboard after deployment.${C_RESET}"
echo -e "${C_YELLOW}DNS/SSL propagation may take a few minutes. You can verify with curl https://${CUSTOM_DOMAIN}/health later.${C_RESET}\n"

echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 6: Build Worker${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

echo -e "${C_YELLOW}🔨 Building worker with embedded scripts...${C_RESET}"
chmod +x scripts/build.sh
bash scripts/build.sh

echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 7: Deploy to Cloudflare${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

echo -e "${C_YELLOW}☁️ Deploying to Cloudflare Workers...${C_RESET}"
npx wrangler deploy

echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_CYAN}Step 8: Verify Health Endpoint${C_RESET}"
echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

if confirm "Run curl health-check against https://${CUSTOM_DOMAIN}/health now?"; then
    if curl -sSf --max-time 15 "https://${CUSTOM_DOMAIN}/health" >/tmp/fuckits-health.json; then
        echo -e "${C_GREEN}✅ Health endpoint responded:${C_RESET}"
        cat /tmp/fuckits-health.json
    else
        echo -e "${C_RED}⚠️ Health check failed. Verify DNS/SSL and make sure the domain points to this Worker.${C_RESET}"
    fi
    rm -f /tmp/fuckits-health.json
else
    echo -e "${C_YELLOW}Skipping automatic check. Remember to curl https://${CUSTOM_DOMAIN}/health manually once DNS propagates.${C_RESET}"
fi

echo -e "\n${C_GREEN}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}✨ Deployment Successful!${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

echo -e "${C_CYAN}${C_BOLD}📝 Next Steps:${C_RESET}\n"
echo -e "${C_YELLOW}1. Configure your Works custom domain:${C_RESET}"
echo -e "   • ${C_CYAN}${CUSTOM_DOMAIN}${C_RESET} (primary)"
echo -e "   • ${C_CYAN}${CUSTOM_DOMAIN}/zh${C_RESET} (Chinese endpoint via path)\n"

echo -e "${C_YELLOW}2. Test your deployment:${C_RESET}"
echo -e "   ${C_CYAN}curl -sS https://${CUSTOM_DOMAIN} | bash${C_RESET}"
echo -e "   ${C_CYAN}curl -sS https://${CUSTOM_DOMAIN}/zh | bash${C_RESET}\n"

echo -e "${C_YELLOW}3. For local development:${C_RESET}"
echo -e "   ${C_CYAN}npm run dev${C_RESET}\n"

echo -e "${C_GREEN}${C_BOLD}🎉 Happy fucking!${C_RESET}\n"
