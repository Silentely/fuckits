#!/bin/bash
#
# Build script for fuckits (Cloudflare Worker)
# This script generates main.sh and zh_main.sh from fuckits.sh, then embeds them
# into worker.js as base64 strings.
#

set -euo pipefail

# Ensure we're in the project root
if [[ ! -f "worker.js" ]] || [[ ! -f "fuckits.sh" ]]; then
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
if [[ ! -f "fuckits.sh" ]]; then
    echo -e "${C_RED}Error: fuckits.sh not found${C_RESET}"
    exit 1
fi

if [[ ! -f "worker.js" ]]; then
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

# Use Python for cross-platform consistent base64 encoding and file editing
# (avoids macOS/Linux base64 command differences and sed separator issues)
python3 - <<'PY'
import base64
import os
import re
import sys
from pathlib import Path

# Read version from VERSION file (single source of truth)
try:
    version = Path('VERSION').read_text(encoding='utf-8').strip()
    if not version:
        raise ValueError("VERSION file is empty")
except Exception as e:
    print(f"Error reading VERSION file: {e}", file=sys.stderr)
    sys.exit(1)

# 在读取 fuckits.sh 之后，注入语言设置
def inject_locale(content, locale):
    """注入默认语言设置（只替换赋值语句，不替换条件检查）"""
    # 只替换赋值语句中的占位符，不替换条件检查中的
    return re.sub(
        r'(_FUCKITS_BUILD_DEFAULT_LOCALE=)"__BUILD_DEFAULT_LOCALE__"',
        f'\\1"{locale}"',
        content
    )

def inject_version(content, script_name):
    """注入脚本版本号"""
    original = content
    content = content.replace(
        'SCRIPT_VERSION="${SCRIPT_VERSION:-__SCRIPT_VERSION__}"',
        f"SCRIPT_VERSION='{version}'",
    )
    content = content.replace('__SCRIPT_VERSION__', version)
    if content != original:
        print(f"  {script_name}: injected version {version}")
    return content

def inline_runtime_common(content, script_name):
    """将运行时共享函数内联进生成脚本，保证安装后的单文件脚本可独立 source"""
    try:
        runtime_content = Path('scripts/runtime-common.sh').read_text(encoding='utf-8')
    except Exception as e:
        print(f"Error reading scripts/runtime-common.sh: {e}", file=sys.stderr)
        sys.exit(1)

    runtime_block = (
        "# --- 内联运行时共享函数（由 build.sh 从 scripts/runtime-common.sh 注入）---\n"
        + runtime_content
        + "\n# --- 内联运行时共享函数结束 ---"
    )
    pattern = (
        r'# --- 加载运行时共享函数 ---\n'
        r'# 仓库源码优先使用 scripts/runtime-common\.sh；安装后的单文件场景则使用同目录副本。\n'
        r'_FC_SCRIPT_DIR="\$\{_FC_SCRIPT_DIR:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)" && pwd\)\}"\n'
        r'if \[\[ -f "\$_FC_SCRIPT_DIR/scripts/runtime-common\.sh" \]\]; then\n'
        r'    # shellcheck disable=SC1091\n'
        r'    source "\$_FC_SCRIPT_DIR/scripts/runtime-common\.sh"\n'
        r'elif \[\[ -f "\$_FC_SCRIPT_DIR/runtime-common\.sh" \]\]; then\n'
        r'    # shellcheck disable=SC1091\n'
        r'    source "\$_FC_SCRIPT_DIR/runtime-common\.sh"\n'
        r'fi'
    )
    # 使用函数替换，避免 re.sub 将 runtime-common.sh 中的 \r/\n 等字面反斜杠序列解释成控制字符。
    content, count = re.subn(pattern, lambda _match: runtime_block, content, count=1)
    if count != 1:
        print(f"Error: Expected to inline runtime-common.sh once for {script_name}, replaced {count}", file=sys.stderr)
        sys.exit(1)
    print(f"  {script_name}: inlined runtime-common.sh")
    return content

# 读取 fuckits.sh 作为源码
try:
    source_content = Path('fuckits.sh').read_text(encoding='utf-8')
except Exception as e:
    print(f"Error reading fuckits.sh: {e}", file=sys.stderr)
    sys.exit(1)

# 生成英文版（默认语言为英文）
en_content = inject_locale(source_content, 'en')
en_content = inject_version(en_content, 'main.sh')
en_content = inline_runtime_common(en_content, 'main.sh')

# 生成中文版（默认语言为中文）
zh_content = inject_locale(source_content, 'zh')
zh_content = inject_version(zh_content, 'zh_main.sh')
zh_content = inline_runtime_common(zh_content, 'zh_main.sh')

try:
    Path('main.sh').write_text(en_content, encoding='utf-8')
    Path('zh_main.sh').write_text(zh_content, encoding='utf-8')
    os.chmod('main.sh', 0o755)
    os.chmod('zh_main.sh', 0o755)
except Exception as e:
    print(f"Error writing generated shell scripts: {e}", file=sys.stderr)
    sys.exit(1)

# 使用 Python base64 编码，保证 macOS/Linux 行为一致
b64_en = base64.b64encode(en_content.encode('utf-8')).decode()
b64_zh = base64.b64encode(zh_content.encode('utf-8')).decode()

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

# Replace VERSION constant with version from VERSION file (single source of truth)
pattern_version = r"const VERSION = '[^']*'"
replacement_version = f"const VERSION = '{version}'"
text, count_v = re.subn(pattern_version, replacement_version, text, count=1)

if count_v != 1:
    print(f"Warning: Expected to replace 1 VERSION constant, replaced {count_v}", file=sys.stderr)

# Inject changelog entries from docs/CHANGELOG.md (latest 10)
changelog_path = Path('docs/CHANGELOG.md')
if changelog_path.exists():
    import re as _re
    changelog_text = changelog_path.read_text(encoding='utf-8')
    entries = []
    current_ver = None
    current_items = []
    for line in changelog_text.splitlines():
        m = _re.match(r'^## (v[\d.]+)', line)
        if m:
            if current_ver and current_items:
                entries.append((current_ver, current_items[:]))
            current_ver = m.group(1)
            current_items = []
        elif line.startswith('- ') and current_ver:
            current_items.append(line[2:].strip())
    if current_ver and current_items:
        entries.append((current_ver, current_items[:]))

    # 取最新 10 条
    entries = entries[:10]

    # 生成 HTML 列表项（中英文内容相同，后续可扩展为双语）
    # 注意：内容将注入 JavaScript 单引号字符串，不能包含字面换行符或单引号
    li_items = []
    for ver, items in entries:
        desc = '；'.join(items) if len(items) <= 2 else items[0] + ' 等'
        desc = desc.replace("'", "\\'")
        li_items.append(f'<li><strong>{ver}</strong> — {desc}</li>')
    # 用 \\n 拼接，确保注入后是 JavaScript 转义换行而非字面换行
    changelog_html = '\\n'.join(li_items)

    # 先尝试替换占位符
    if '<!--CHANGELOG_ZH-->' in text:
        text = text.replace('<!--CHANGELOG_ZH-->', changelog_html)
        text = text.replace('<!--CHANGELOG_EN-->', changelog_html)
        print(f"  Changelog: injected {len(entries)} entries (placeholder)")
    else:
        # 占位符不存在时，用正则匹配已注入的更新日志行并替换
        # 匹配以 '<li><strong>v 开头、以 </li>', 结尾的整行（含多条 \\n 分隔的条目）
        pattern = r"    '<li><strong>v[\d.]+</strong>.*?</li>',"
        match = _re.search(pattern, text)
        if match:
            old_line = match.group(0)
            # 构造新行：保持同样的缩进和引号格式
            new_line = f"    '{changelog_html}',"
            text = text.replace(old_line, new_line)
            print(f"  Changelog: injected {len(entries)} entries (regex replace)")
        else:
            print("  Changelog: no placeholder or existing block found, skipped", file=sys.stderr)
else:
    print("  Changelog: docs/CHANGELOG.md not found, skipped", file=sys.stderr)

# Replace build time placeholder with current ISO timestamp
from datetime import datetime, timezone
build_time = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
text = text.replace("'__BUILD_TIME__'", f"'{build_time}'")

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
if [[ $? -ne 0 ]]; then
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
