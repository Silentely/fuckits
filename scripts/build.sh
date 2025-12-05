#!/bin/bash
#
# Build script for fuckit.sh
# This script embeds main.sh and zh_main.sh into worker.js as base64 strings
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

echo -e "${C_CYAN}🔨 Building fuckit.sh worker...${C_RESET}"

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

# Create backup
echo -e "${C_YELLOW}📦 Creating backup of worker.js...${C_RESET}"
cp worker.js worker.js.backup

# Detect OS and use appropriate base64 command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo -e "${C_YELLOW}📝 Encoding scripts (macOS)...${C_RESET}"
    B64_EN=$(base64 -i main.sh)
    B64_ZH=$(base64 -i zh_main.sh)
    # Use macOS compatible sed
    sed -i.tmp "s#^const INSTALLER_SCRIPT = b64_to_utf8(\`.*\`);#const INSTALLER_SCRIPT = b64_to_utf8(\`${B64_EN}\`);#" worker.js
    sed -i.tmp "s#^const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`.*\`);#const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`${B64_ZH}\`);#" worker.js
    rm -f worker.js.tmp
else
    # Linux
    echo -e "${C_YELLOW}📝 Encoding scripts (Linux)...${C_RESET}"
    B64_EN=$(base64 -w 0 main.sh)
    B64_ZH=$(base64 -w 0 zh_main.sh)
    # Use Linux sed
    sed -i "s#^const INSTALLER_SCRIPT = b64_to_utf8(\`.*\`);#const INSTALLER_SCRIPT = b64_to_utf8(\`${B64_EN}\`);#" worker.js
    sed -i "s#^const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`.*\`);#const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`${B64_ZH}\`);#" worker.js
fi

# Verify the build
if grep -q "const INSTALLER_SCRIPT = b64_to_utf8(\`\`);" worker.js; then
    echo -e "${C_RED}❌ Build failed: INSTALLER_SCRIPT is empty${C_RESET}"
    mv worker.js.backup worker.js
    exit 1
fi

if grep -q "const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`\`);" worker.js; then
    echo -e "${C_RED}❌ Build failed: INSTALLER_SCRIPT_ZH is empty${C_RESET}"
    mv worker.js.backup worker.js
    exit 1
fi

# Remove backup on success
rm -f worker.js.backup

echo -e "${C_GREEN}✅ Build completed successfully!${C_RESET}"
echo -e "${C_CYAN}📄 worker.js has been updated with the latest scripts${C_RESET}"
