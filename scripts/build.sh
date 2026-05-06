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

# Encode runtime-common.sh into main.sh and zh_main.sh (update _FC_RT_COMMON_B64)
echo -e "${C_YELLOW}📦 Encoding runtime-common.sh into shell scripts...${C_RESET}"
python3 -c "
import base64, re, sys
try:
    with open('scripts/runtime-common.sh', 'rb') as f:
        b64 = base64.b64encode(f.read()).decode()
    for script in ['main.sh', 'zh_main.sh']:
        with open(script) as f:
            text = f.read()
        pattern = r'(_FC_RT_COMMON_B64=\")([^\"]+)(\")'
        if re.search(pattern, text):
            text = re.sub(pattern, lambda m: m.group(1) + b64 + m.group(3), text, count=1)
            with open(script, 'w') as f:
                f.write(text)
            print(f'  {script}: _FC_RT_COMMON_B64 updated ({len(b64)} chars)')
        else:
            print(f'  {script}: _FC_RT_COMMON_B64 not found, skipped', file=sys.stderr)
except Exception as e:
    print(f'Error encoding runtime-common.sh: {e}', file=sys.stderr)
    sys.exit(1)
"
if [ $? -ne 0 ]; then
    echo -e "${C_RED}❌ Failed to encode runtime-common.sh${C_RESET}"
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
import base64
import json
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

# Read version from package.json (single source of truth)
try:
    pkg = json.loads(Path('package.json').read_text(encoding='utf-8'))
    version = pkg.get('version', '0.0.0')
except Exception as e:
    print(f"Error reading package.json version: {e}", file=sys.stderr)
    sys.exit(1)

# Replace __SCRIPT_VERSION__ placeholder in shell scripts before encoding
def inject_version(b64_content, script_name):
    try:
        text = base64.b64decode(b64_content).decode('utf-8')
        if '__SCRIPT_VERSION__' in text:
            text = text.replace('__SCRIPT_VERSION__', version, 1)
            print(f"  {script_name}: injected version {version}")
            return base64.b64encode(text.encode('utf-8')).decode()
        return b64_content
    except Exception as e:
        print(f"Warning: Failed to inject version in {script_name}: {e}", file=sys.stderr)
        return b64_content

b64_en = inject_version(b64_en, 'main.sh')
b64_zh = inject_version(b64_zh, 'zh_main.sh')

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

# Replace hardcoded version in health check with package.json version
pattern_version = r"version: '[^']*'"
replacement_version = f"version: '{version}'"
text, count_v = re.subn(pattern_version, replacement_version, text, count=1)

if count_v != 1:
    print(f"Warning: Expected to replace 1 version string, replaced {count_v}", file=sys.stderr)

# Write updated content
try:
    path.write_text(text, encoding='utf-8')
except Exception as e:
    print(f"Error writing worker.js: {e}", file=sys.stderr)
    sys.exit(1)

# Success - output to stdout
print(f"Build successful (version: {version})")
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
