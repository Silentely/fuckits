#!/bin/bash
#
# Common functions for fuckits build scripts
# This file should be sourced by other scripts
#

# Function to update a variable in wrangler.toml [vars] section
# Usage: update_wrangler_var "KEY_NAME" "value"
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

    # Pass parameters via environment variables to avoid shell argument parsing issues
    KEY="$key" VALUE="$value" python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

try:
    key = os.environ['KEY']
    value = os.environ['VALUE']
    escaped = value.replace('\\', '\\\\').replace('"', '\\"')
    path = Path('wrangler.toml')
    text = path.read_text(encoding='utf-8')

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

    path.write_text(text, encoding='utf-8')
except Exception as e:
    print(f"Error updating wrangler.toml: {e}", file=sys.stderr)
    sys.exit(1)
PY

    # Check Python exit code
    if [ $? -ne 0 ]; then
        echo -e "${C_RED}❌ Failed to update ${key} in wrangler.toml${C_RESET}"
        return 1
    fi

    echo -e "${C_GREEN}✅ Updated ${key} in wrangler.toml${C_RESET}"
}
