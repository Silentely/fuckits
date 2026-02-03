#!/bin/bash
#
# Build script for fuckits (Cloudflare Worker)
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

# Check for Python3 (required for safe file editing)
if ! command -v python3 > /dev/null; then
    echo -e "${C_RED}Error: python3 is required for building${C_RESET}"
    echo -e "${C_YELLOW}Please install python3 and try again${C_RESET}"
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
else
    # Linux
    echo -e "${C_YELLOW}📝 Encoding scripts (Linux)...${C_RESET}"
    B64_EN=$(base64 -w 0 main.sh)
    B64_ZH=$(base64 -w 0 zh_main.sh)
fi

# Use Python for safe file editing (avoids sed separator and length limit issues)
# Pass base64 content via environment variables to avoid shell argument parsing issues
B64_EN="$B64_EN" B64_ZH="$B64_ZH" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

# Read base64 content from environment variables
b64_en = os.environ.get('B64_EN', '')
b64_zh = os.environ.get('B64_ZH', '')

if not b64_en or not b64_zh:
    print("Error: Base64 content not provided", file=sys.stderr)
    sys.exit(1)

# Read worker.js
try:
    path = Path('worker.js')
    text = path.read_text(encoding='utf-8')
except Exception as e:
    print(f"Error reading worker.js: {e}", file=sys.stderr)
    sys.exit(1)

# Replace INSTALLER_SCRIPT line
pattern_en = r'^const INSTALLER_SCRIPT = b64_to_utf8\(`.*`\);'
replacement_en = f'const INSTALLER_SCRIPT = b64_to_utf8(`{b64_en}`);'
text, count_en = re.subn(pattern_en, replacement_en, text, count=1, flags=re.MULTILINE)

if count_en != 1:
    print(f"Error: Expected to replace 1 INSTALLER_SCRIPT line, replaced {count_en}", file=sys.stderr)
    sys.exit(1)

# Replace INSTALLER_SCRIPT_ZH line
pattern_zh = r'^const INSTALLER_SCRIPT_ZH = b64_to_utf8\(`.*`\);'
replacement_zh = f'const INSTALLER_SCRIPT_ZH = b64_to_utf8(`{b64_zh}`);'
text, count_zh = re.subn(pattern_zh, replacement_zh, text, count=1, flags=re.MULTILINE)

if count_zh != 1:
    print(f"Error: Expected to replace 1 INSTALLER_SCRIPT_ZH line, replaced {count_zh}", file=sys.stderr)
    sys.exit(1)

# Write updated content
try:
    path.write_text(text, encoding='utf-8')
except Exception as e:
    print(f"Error writing worker.js: {e}", file=sys.stderr)
    sys.exit(1)

# Success - output to stdout
print("Build successful")
PY

# Check Python exit code
if [ $? -ne 0 ]; then
    echo -e "${C_RED}❌ Build failed during file editing${C_RESET}"
    mv worker.js.backup worker.js
    exit 1
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
