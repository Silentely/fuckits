#!/bin/bash
#
# This script is the installer and temporary runner for fuckits
#
# --- RECOMMENDED SECURE USAGE ---
#
# 1. Download:
#    curl -o fuckits https://fuckits.25500552.xyz
#
# 2. Inspect:
#    less fuckits
#
# 3. Run (Install):
#    bash fuckits
#
# 4. Run (Temporary):
#    bash fuckits "your prompt"
#

set -euo pipefail

# --- Prevent Re-definition of readonly Variables ---
# This guard allows the script to be sourced multiple times (e.g., in tests)
if [[ -z "${FUCKITS_CONSTANTS_DEFINED:-}" ]]; then
    # Mark constants as being defined (export to make visible to subshells)
    export FUCKITS_CONSTANTS_DEFINED=1

# --- Color Definitions ---
readonly C_RESET='\033[0m'
readonly C_RED_BOLD='\033[1;31m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'

# --- FUCK! ---
readonly FUCK="${C_RED_BOLD}FUCK!${C_RESET}"
readonly FCKN="${C_RED}F*CKING${C_RESET}"

readonly FUCKITS_LOCALE="en"


# --- Configuration ---
if [ -z "${HOME:-}" ]; then
    echo -e "\033[1;31mFUCK!\033[0m \033[0;31mYour HOME variable isn't set. I don't know where to install this shit. Set it yourself (e.g., export HOME=/root).\033[0m" >&2
    exit 1
fi
readonly INSTALL_DIR="$HOME/.fuck"
readonly MAIN_SH="$INSTALL_DIR/main.sh"
readonly CONFIG_FILE="$INSTALL_DIR/config.sh"

fi  # End of readonly constants guard


# --- Core Logic (Embedded as a string) ---
read -r -d '' CORE_LOGIC <<'EOF' || true

# --- Begin Core Logic for fuckits ---

# --- Color Definitions ---
# Only define colors if they haven't been defined yet (for temp mode)
if [ -z "${C_RESET:-}" ]; then
    readonly C_RESET='\033[0m'
    readonly C_RED_BOLD='\033[1;31m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_CYAN='\033[0;36m'
    readonly C_BOLD='\033[1m'
    readonly C_DIM='\033[2m'

    # --- FUCK! ---
    readonly FUCK="${C_RED_BOLD}FUCK!${C_RESET}"
    readonly FCKN="${C_RED}F*CKING${C_RESET}"
fi

if [ -z "${INSTALL_DIR+x}" ] || [ -z "${MAIN_SH+x}" ] || [ -z "${CONFIG_FILE+x}" ]; then
    if [ -z "${HOME:-}" ]; then
        readonly INSTALL_DIR="/tmp/.fuck"
        readonly MAIN_SH="/tmp/.fuck/main.sh"
        readonly CONFIG_FILE="/tmp/.fuck/config.sh"
    else
        readonly INSTALL_DIR="$HOME/.fuck"
        readonly MAIN_SH="$INSTALL_DIR/main.sh"
        readonly CONFIG_FILE="$INSTALL_DIR/config.sh"
    fi
fi

# Note: Config loading is done AFTER validation functions are defined (see below)

if [ -z "${DEFAULT_API_ENDPOINT+x}" ]; then
    readonly DEFAULT_API_ENDPOINT="https://fuckits.25500552.xyz/"
fi

# --- Secure Config Validation ---
# Validates config file content before sourcing to prevent code injection
# Arguments: $1 - file path to validate
# Returns: 0 if safe, 1 if unsafe or error
_fuck_validate_config_file() {
    local file="$1"

    # File must exist and be readable
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        return 1
    fi

    # Check file permissions - should be owned by current user
    if [ "$(stat -c '%u' "$file" 2>/dev/null || stat -f '%u' "$file" 2>/dev/null)" != "$(id -u)" ]; then
        echo -e "$FUCK ${C_RED}Config file not owned by current user, refusing to source.${C_RESET}" >&2
        return 1
    fi

    local line_num=0
    local line

    # Pre-define regex patterns as variables (zsh compatibility: avoids special character parsing issues)
    local re_cmd_sub='\$\('
    local re_backtick='`'
    local re_arith='\$\(\('
    local re_semi=';'
    local re_and='&&'
    local re_or='\|\|'
    local re_pipe='\|'
    local re_gt='>'
    local re_lt='<'
    local re_amp='&'
    local re_esc='\\\$'

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # Skip empty lines
        if [ -z "$line" ] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Skip comment lines (# at start, optionally with leading whitespace)
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Check for dangerous shell metacharacters and command substitution
        # Reject: $(), ``, $((), ;, &&, ||, | (pipe), >, <, &, newline escapes
        if [[ "$line" =~ $re_cmd_sub ]] || \
           [[ "$line" =~ $re_backtick ]] || \
           [[ "$line" =~ $re_arith ]] || \
           [[ "$line" =~ $re_semi ]] || \
           [[ "$line" =~ $re_and ]] || \
           [[ "$line" =~ $re_or ]] || \
           [[ "$line" =~ $re_pipe ]] || \
           [[ "$line" =~ $re_gt ]] || \
           [[ "$line" =~ $re_lt ]] || \
           [[ "$line" =~ $re_amp ]] || \
           [[ "$line" =~ $re_esc ]]; then
            _fuck_debug "Config validation failed at line $line_num: dangerous metacharacter detected"
            echo -e "$FUCK ${C_RED}Unsafe config file: dangerous shell metacharacter at line $line_num${C_RESET}" >&2
            return 1
        fi

        # Only allow: export FUCK_*=... or FUCK_*=... (with optional whitespace)
        # Also allow: export FUCKITS_LOCALE=...
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?(FUCK_[A-Z_]+|FUCKITS_LOCALE)= ]]; then
            continue
        fi

        # Reject anything else
        _fuck_debug "Config validation failed at line $line_num: unrecognized pattern"
        echo -e "$FUCK ${C_RED}Unsafe config file: unrecognized pattern at line $line_num${C_RESET}" >&2
        return 1
    done < "$file"

    return 0
}

# Safely source a config file after validation
# Arguments: $1 - file path to source
# Returns: 0 if sourced successfully, 1 if validation failed or file doesn't exist
_fuck_safe_source_config() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return 0  # No file is fine
    fi

    if _fuck_validate_config_file "$file"; then
        # shellcheck disable=SC1090
        source "$file"
        return $?
    else
        echo -e "${C_YELLOW}Config file validation failed, skipping: $file${C_RESET}" >&2
        return 1
    fi
}

# --- Load User Configuration (with validation) ---
# Now that validation functions are defined, safely load the config
_fuck_safe_source_config "$CONFIG_FILE"

# Helper to find the user's shell profile file
_installer_detect_profile() {
    if [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "bash"; then
        echo "$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        # Fallback for sh, ksh, etc.
        echo "$HOME/.profile"
    elif [ -f "$HOME/.zshrc" ]; then
        # Fallback if SHELL var isn't set
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        # Fallback if SHELL var isn't set
        echo "$HOME/.bashrc"
    else
        echo "unknown_profile"
    fi
}

# --- System Information Collection ---
# Cache file for static system information (persisted across runs)
# Only define if not already set (prevents read-only variable errors)
if [ -z "${FUCK_SYSINFO_CACHE_FILE:-}" ]; then
    readonly FUCK_SYSINFO_CACHE_FILE="$INSTALL_DIR/.sysinfo.cache"
fi
# Cache state tracking variables
_FUCK_STATIC_CACHE_LOADED=0
_FUCK_STATIC_CACHE_DIRTY=0

# Loads static system information from cache file
# Globals: _FUCK_STATIC_CACHE_LOADED, FUCK_SYSINFO_CACHE_FILE
_fuck_load_static_cache() {
    # Return early if cache is already loaded
    if [ "${_FUCK_STATIC_CACHE_LOADED:-0}" -eq 1 ]; then
        return 0
    fi

    _FUCK_STATIC_CACHE_LOADED=1

    # Source cache file if it exists
    if [ -f "$FUCK_SYSINFO_CACHE_FILE" ]; then
        # shellcheck disable=SC1090
        source "$FUCK_SYSINFO_CACHE_FILE" || true
    fi
}

# Marks static cache as dirty (needs to be persisted)
# Globals: _FUCK_STATIC_CACHE_DIRTY
_fuck_mark_static_cache_dirty() {
    _FUCK_STATIC_CACHE_DIRTY=1
}

# Persists static system information to cache file
# Globals: _FUCK_STATIC_CACHE_DIRTY, FUCK_SYSINFO_CACHE_FILE
# Returns: 0 on success, 1 on failure
_fuck_persist_static_cache() {
    # Only persist if cache is dirty
    if [ "${_FUCK_STATIC_CACHE_DIRTY:-0}" -ne 1 ]; then
        return 0
    fi

    # Ensure cache directory exists
    local cache_dir
    cache_dir=$(dirname "$FUCK_SYSINFO_CACHE_FILE")
    if ! mkdir -p "$cache_dir" 2>/dev/null; then
        return 1
    fi

    # Create temporary file for atomic write
    local tmp_file
    tmp_file=$(mktemp) || return 1

    # Write cached variables to temporary file
    {
        printf '_FUCK_CACHED_DISTRO=%q\\n' "${_FUCK_CACHED_DISTRO:-}"
        printf '_FUCK_CACHED_KERNEL=%q\\n' "${_FUCK_CACHED_KERNEL:-}"
        printf '_FUCK_CACHED_ARCH=%q\\n' "${_FUCK_CACHED_ARCH:-}"
        printf '_FUCK_CACHED_PKG_MANAGER=%q\\n' "${_FUCK_CACHED_PKG_MANAGER:-}"
    } > "$tmp_file"

    # Atomic move to final location
    if mv "$tmp_file" "$FUCK_SYSINFO_CACHE_FILE" 2>/dev/null; then
        _FUCK_STATIC_CACHE_DIRTY=0
        return 0
    else
        # Clean up temporary file on failure
        rm -f "$tmp_file"
        return 1
    fi
}

# Detects the distribution/OS family with caching support
# Outputs: Distribution string (e.g., "Debian-based 12.04 (Ubuntu 24.04 LTS)")
_fuck_detect_distro() {
    _fuck_load_static_cache

    # Return cached value if available
    if [ -n "${_FUCK_CACHED_DISTRO:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_DISTRO"
        return 0
    fi

    local kernel_name distro id version pretty family
    kernel_name=$(uname -s 2>/dev/null || printf 'unknown')
    distro="unknown"

    # macOS detection
    if [ "$kernel_name" = "Darwin" ]; then
        local product version
        product=$(sw_vers -productName 2>/dev/null || printf 'macOS')
        product=$(printf '%s' "$product" | tr -d '\r\n')
        version=$(sw_vers -productVersion 2>/dev/null || printf 'unknown')
        version=$(printf '%s' "$version" | tr -d '\r\n')
        distro="$product $version"
    # Linux detection using /etc/os-release
    elif [ -r /etc/os-release ]; then
        id=$(grep -E '^ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        version=$(grep -E '^VERSION_ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"')
        pretty=$(grep -E '^PRETTY_NAME=' /etc/os-release | head -n1 | cut -d= -f2- | tr -d '"')

        # Determine OS family for better categorization
        family=""
        case "$id" in
            ubuntu|debian)
                family="Debian-based"
                ;;
            centos|rhel|rocky|almalinux|fedora)
                family="RHEL-based"
                ;;
            arch|manjaro|endeavouros)
                family="Arch-based"
                ;;
        esac

        # Format distribution string with family and version
        if [ -n "$family" ]; then
            distro="$family ${version:-}"
            if [ -n "$pretty" ]; then
                distro="$distro (${pretty})"
            fi
        else
            distro="${pretty:-Linux $version}"
        fi
    else
        distro="$kernel_name"
    fi

    # Cache and return result
    _FUCK_CACHED_DISTRO="$distro"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$distro"
}

# Gets kernel version information with caching
# Outputs: Kernel version string (e.g., "Linux 6.8.0-31-generic")
_fuck_get_kernel_version() {
    _fuck_load_static_cache

    # Return cached value if available
    if [ -n "${_FUCK_CACHED_KERNEL:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_KERNEL"
        return 0
    fi

    local kernel
    kernel=$(uname -sr 2>/dev/null || uname -s 2>/dev/null || printf 'unknown')
    kernel=$(printf '%s' "$kernel" | tr -d '\r\n')

    # Cache and return result
    _FUCK_CACHED_KERNEL="$kernel"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$kernel"
}

# Gets system architecture with caching
# Outputs: Architecture string (e.g., "x86_64", "arm64")
_fuck_get_architecture() {
    _fuck_load_static_cache

    # Return cached value if available
    if [ -n "${_FUCK_CACHED_ARCH:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_ARCH"
        return 0
    fi

    local arch
    arch=$(uname -m 2>/dev/null || printf 'unknown')
    arch=$(printf '%s' "$arch" | tr -d '\r\n')

    # Cache and return result
    _FUCK_CACHED_ARCH="$arch"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$arch"
}

# Collects user information including permissions
# Outputs: User info string (e.g., "User=john uid=1000 level=sudoer Groups=john adm sudo")
_fuck_collect_user_info() {
    local current_user uid groups level
    current_user="${USER:-}"

    # Fallback if USER is not set
    if [ -z "$current_user" ]; then
        current_user=$(whoami 2>/dev/null || printf 'unknown')
    fi

    # Get UID and groups if id command is available
    uid="unknown"
    groups="unknown"
    if command -v id >/dev/null 2>&1; then
        uid=$(id -u "$current_user" 2>/dev/null || id -u 2>/dev/null || printf 'unknown')
        groups=$(id -Gn "$current_user" 2>/dev/null || id -Gn 2>/dev/null || printf 'unknown')
    fi

    # Determine permission level
    level="user"
    if [ "$uid" = "0" ]; then
        level="root"
    elif printf '%s' "$groups" | grep -Eq '(^|[[:space:]])(sudo|wheel|admin)([[:space:]]|$)'; then
        level="sudoer"
    fi

    printf 'User=%s uid=%s level=%s Groups=%s' "$current_user" "$uid" "$level" "$groups"
}

# Collects version information for common development tools
# Outputs: Tool versions string (e.g., "git:git version 2.34.1; docker:Docker version 24.0.6; ...")
_fuck_collect_tool_versions() {
    local tools tool version result
    tools="git docker npm kubectl curl wget"
    result=""

    for tool in $tools; do
        version="not-installed"

        if command -v "$tool" >/dev/null 2>&1; then
            case "$tool" in
                git|docker|curl|wget)
                    version=$("$tool" --version 2>/dev/null | head -n1)
                    ;;
                npm)
                    version=$("$tool" --version 2>/dev/null | head -n1)
                    [ -n "$version" ] && version="npm $version"
                    ;;
                kubectl)
                    version=$("$tool" version --client --short 2>/dev/null | head -n1)
                    ;;
            esac
        fi

        # Clean up version string
        version=$(printf '%s' "${version:-unknown}" | tr '\r\n' '  ' | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//')
        [ -z "$version" ] && version="unknown"

        result="$result$tool:$version; "
    done

    # Remove trailing semicolon and space
    result="${result%; }"
    printf '%s' "$result"
}

# Detects the package manager with caching support
# Outputs: Package manager name (apt, yum, dnf, pacman, zypper, brew, unknown)
_fuck_detect_pkg_manager() {
    _fuck_load_static_cache

    # Return cached value if available
    if [ -n "${_FUCK_CACHED_PKG_MANAGER:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_PKG_MANAGER"
        return 0
    fi

    local manager="unknown"

    # Detect package manager in order of preference
    if command -v apt-get &> /dev/null; then
        manager="apt"
    elif command -v yum &> /dev/null; then
        manager="yum"
    elif command -v dnf &> /dev/null; then
        manager="dnf"
    elif command -v pacman &> /dev/null; then
        manager="pacman"
    elif command -v zypper &> /dev/null; then
        manager="zypper"
    elif command -v brew &> /dev/null; then
        manager="brew"
    fi

    # Cache and return result
    _FUCK_CACHED_PKG_MANAGER="$manager"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$manager"
}

# Collects simplified system information as a structured string
# Outputs: System info string for AI processing
_fuck_collect_sysinfo_string() {
    local os_type kernel_name pkg_manager summary

    # Detect operating system type
    kernel_name=$(uname -s 2>/dev/null || printf 'unknown')

    case "$kernel_name" in
        Darwin)
            os_type="macOS"
            pkg_manager="brew"
            ;;
        Linux)
            if [ -r /etc/os-release ]; then
                local id
                id=$(grep -E '^ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
                case "$id" in
                    ubuntu|debian)
                        os_type="Debian"
                        pkg_manager="apt"
                        ;;
                    centos|rhel|rocky|almalinux|fedora)
                        os_type="RHEL"
                        pkg_manager="yum"
                        ;;
                    arch|manjaro)
                        os_type="Arch"
                        pkg_manager="pacman"
                        ;;
                    *)
                        os_type="Linux"
                        pkg_manager="unknown"
                        ;;
                esac
            else
                os_type="Linux"
                pkg_manager="unknown"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            os_type="Windows"
            pkg_manager="unknown"
            ;;
        *)
            os_type="$kernel_name"
            pkg_manager="unknown"
            ;;
    esac

    # Format as simple structured string
    printf -v summary 'OS=%s; PkgMgr=%s' "$os_type" "$pkg_manager"
    printf '%s\n' "$summary"
}

# Escapes a string for use in a JSON payload
_fuck_json_escape() {
    local input="$1"
    # Use printf to properly handle control characters
    printf '%s' "$input" | sed -e '
        # First escape backslashes (must be first)
        s/\\/\\\\/g
        # Escape double quotes
        s/"/\\"/g
        # Escape control characters (ASCII 0-31)
        s/\x00/\\u0000/g
        s/\x01/\\u0001/g
        s/\x02/\\u0002/g
        s/\x03/\\u0003/g
        s/\x04/\\u0004/g
        s/\x05/\\u0005/g
        s/\x06/\\u0006/g
        s/\x07/\\u0007/g
        s/\x08/\\b/g
        s/\x09/\\t/g
        s/\x0A/\\n/g
        s/\x0B/\\u000B/g
        s/\x0C/\\f/g
        s/\x0D/\\r/g
        s/\x0E/\\u000E/g
        s/\x0F/\\u000F/g
        s/\x10/\\u0010/g
        s/\x11/\\u0011/g
        s/\x12/\\u0012/g
        s/\x13/\\u0013/g
        s/\x14/\\u0014/g
        s/\x15/\\u0015/g
        s/\x16/\\u0016/g
        s/\x17/\\u0017/g
        s/\x18/\\u0018/g
        s/\x19/\\u0019/g
        s/\x1A/\\u001A/g
        s/\x1B/\\u001B/g
        s/\x1C/\\u001C/g
        s/\x1D/\\u001D/g
        s/\x1E/\\u001E/g
        s/\x1F/\\u001F/g
    '
}

_fuck_should_use_local_api() {
    if [ -n "${FUCK_OPENAI_API_KEY:-}" ]; then
        return 0
    fi
    return 1
}

_fuck_local_system_prompt() {
    local sysinfo="$1"
    if [ "$FUCKITS_LOCALE" = "zh" ]; then
        printf '你是一个专业的 shell 命令生成器。用户会用自然语言描述他们想要完成的任务。你的任务是生成直接可执行的 shell 命令来完成用户的目标。

重要规则：
1. 用户输入是自然语言描述意图，不是命令参数。例如"列出目录"意思是执行 ls 命令，而不是 ls "列出目录"
2. 生成直接可执行的命令，不要生成带参数判断的脚本模板（如 if [ $# -eq 0 ]）
3. 对于简单任务直接返回单条命令，复杂任务可以是多行脚本
4. 不要提供任何解释、注释、markdown 格式（比如 ```bash）或 shebang（例如 #!/bin/bash）

示例：
- 用户说"列出目录" → 输出: ls
- 用户说"显示详细文件列表" → 输出: ls -la
- 用户说"查找大于10MB的文件" → 输出: find . -type f -size +10M

用户的系统信息是：%s' "$sysinfo"
    else
        printf 'You are an expert shell command generator. Users describe tasks in natural language. Your task is to generate directly executable shell commands to accomplish their goals.

Important rules:
1. User input is natural language intent, NOT command arguments. For example, "list directory" means run ls, not ls "list directory"
2. Generate directly executable commands, not script templates with parameter handling (like if [ $# -eq 0 ])
3. For simple tasks return single commands, complex tasks can be multi-line scripts
4. Do not provide any explanation, comments, markdown formatting (like ```bash), or a shebang (e.g., #!/bin/bash)

Examples:
- User says "list directory" → Output: ls
- User says "show detailed file list" → Output: ls -la
- User says "find files larger than 10MB" → Output: find . -type f -size +10M

The user'"'"'s system info is: %s' "$sysinfo"
    fi
}

_fuck_extract_command_from_json() {
    local json_file="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$json_file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
choices = data.get('choices') or []
if not choices:
    sys.exit(1)
message = choices[0].get('message') or {}
content = (message.get('content') or '').strip()
if not content:
    sys.exit(1)
print(content)
PY
        return
    fi

    if command -v node >/dev/null 2>&1; then
        node - "$json_file" <<'JS'
const fs = require('fs');
const path = process.argv[1];
const data = JSON.parse(fs.readFileSync(path, 'utf8'));
const choice = (data.choices && data.choices[0]) || {};
const message = choice.message || {};
const content = (message.content || '').trim();
if (!content) {
  process.exit(1);
}
console.log(content);
JS
        return
    fi

    echo -e "$FUCK ${C_RED}Cannot parse AI response because neither python3 nor node is available.${C_RESET}" >&2
    echo -e "${C_YELLOW}Please install python3 or node to use local API mode.${C_RESET}" >&2
    return 1
}

_fuck_request_local_model() {
    local prompt="$1"
    local sysinfo="$2"
    local curl_timeout="$3"

    local api_key="${FUCK_OPENAI_API_KEY:-}"
    if [ -z "$api_key" ]; then
        echo -e "$FUCK ${C_RED}Local API key not configured. Set FUCK_OPENAI_API_KEY in ~/.fuck/config.sh.${C_RESET}" >&2
        return 1
    fi

    local model="${FUCK_OPENAI_MODEL:-gpt-5-nano}"
    local api_base="${FUCK_OPENAI_API_BASE:-https://api.openai.com/v1}"
    api_base=${api_base%/}
    local api_url="$api_base/chat/completions"

    _fuck_debug "local api base=$api_base"
    _fuck_debug "local model=$model"

    local system_prompt
    system_prompt=$(_fuck_local_system_prompt "$sysinfo")

    local escaped_prompt escaped_system
    escaped_prompt=$(_fuck_json_escape "$prompt")
    escaped_system=$(_fuck_json_escape "$system_prompt")
    local payload
    payload=$(printf '{ "model": "%s", "messages": [ {"role":"system","content":"%s"}, {"role":"user","content":"%s"} ], "max_tokens": 1024, "temperature": 0.2 }' \
        "$model" "$escaped_system" "$escaped_prompt")

    local tmp_json
    tmp_json=$(mktemp) || return 1

    if ! curl -fsS --max-time "$curl_timeout" "$api_url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" > "$tmp_json"; then
        echo -e "$FUCK ${C_RED}Local API request failed.${C_RESET}" >&2
        cat "$tmp_json" >&2
        rm -f "$tmp_json"
        return 1
    fi

    local command_output
    if ! command_output=$(_fuck_extract_command_from_json "$tmp_json"); then
        rm -f "$tmp_json"
        echo -e "$FUCK ${C_RED}Unable to parse local model response.${C_RESET}" >&2
        return 1
    fi

    rm -f "$tmp_json"
    printf '%s\n' "$command_output"
}

_fuck_request_worker_model() {
    local prompt="$1"
    local sysinfo="$2"
    local curl_timeout="$3"
    local spinner_label="${4:-}"

    local admin_key="${FUCK_ADMIN_KEY:-}"
    local admin_segment=""
    if [ -n "$admin_key" ]; then
        admin_segment=$(printf ', "adminKey": "%s"' "$( _fuck_json_escape "$admin_key" )")
    fi

    local payload
    payload=$(printf '{ "sysinfo": "%s", "prompt": "%s"%s }' \
        "$( _fuck_json_escape "$sysinfo" )" \
        "$( _fuck_json_escape "$prompt" )" \
        "$admin_segment")

    local api_url="${FUCK_API_ENDPOINT:-$DEFAULT_API_ENDPOINT}"

    _fuck_debug "API URL: $api_url"
    _fuck_debug "Payload: $payload"
    _fuck_debug "Timeout: $curl_timeout"

    local tmp_response tmp_status
    tmp_response=$(mktemp)
    tmp_status=$(mktemp)

    (
        curl -sS --max-time "$curl_timeout" -X POST "$api_url" \
            -H "Content-Type: application/json" \
            -d "$payload" -o "$tmp_response" -w "%{http_code}" > "$tmp_status"
    ) &
    local pid=$!

    if [ -t 2 ]; then
        _fuck_spinner "$pid" "$spinner_label" >&2
    fi

    local curl_exit=0
    if ! wait "$pid"; then
        curl_exit=$?
    fi

    local http_status=""
    if [ -f "$tmp_status" ]; then
        http_status=$(tr -d '\r\n' < "$tmp_status")
        rm -f "$tmp_status"
    fi

    local response=""
    if [ -f "$tmp_response" ]; then
        response=$(cat "$tmp_response")
        rm -f "$tmp_response"
    fi

    if [ $curl_exit -ne 0 ]; then
        echo -e "$FUCK ${C_RED}Failed to reach the shared Worker.${C_RESET}" >&2
        if [ -n "$response" ]; then
            echo -e "${C_DIM}$response${C_RESET}" >&2
        fi
        return $curl_exit
    fi

    if [ -z "$http_status" ]; then
        http_status=0
    fi

    if [ "$http_status" -eq 429 ] && printf '%s' "$response" | grep -q 'DEMO_LIMIT_EXCEEDED'; then
        local limit
        limit=$(printf '%s' "$response" | sed -n 's/.*"limit":[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)
        local remaining
        remaining=$(printf '%s' "$response" | sed -n 's/.*"remaining":[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)
        [ -z "$limit" ] && limit=10
        _fuck_notify_demo_limit "$limit" "$remaining"
        return 2
    fi

    if [ "$http_status" -ge 400 ] || [ -z "$response" ]; then
        echo -e "$FUCK ${C_RED}Shared Worker returned HTTP $http_status.${C_RESET}" >&2
        if [ -n "$response" ]; then
            echo -e "${C_DIM}$response${C_RESET}" >&2
        fi
        return 1
    fi

    printf '%s\n' "$response"
}

_fuck_notify_demo_limit() {
    local daily_limit="${1:-10}"
    local remaining="${2:-0}"

    echo -e "$FUCK ${C_YELLOW}Shared demo quota exhausted (${daily_limit} calls per day).${C_RESET}" >&2
    case "$remaining" in
        ''|*[!0-9]*) ;;
        *)
            if [ "$remaining" -gt 0 ]; then
                echo -e "${C_DIM}$remaining calls left for today.${C_RESET}" >&2
            fi
            ;;
    esac

    _fuck_ensure_config_exists
    _fuck_secure_config_file

    echo -e "${C_CYAN}Switch to your own key:${C_RESET} run ${C_GREEN}fuck config${C_RESET} and set ${C_BOLD}FUCK_OPENAI_API_KEY${C_RESET} (plus optional ${C_BOLD}FUCK_OPENAI_MODEL${C_RESET}/${C_BOLD}FUCK_OPENAI_API_BASE${C_RESET})." >&2
    echo -e "${C_CYAN}Trusted maintainer override:${C_RESET} set ${C_BOLD}FUCK_ADMIN_KEY${C_RESET} if you were issued the worker's ADMIN_ACCESS_KEY to bypass the shared quota." >&2
    echo -e "${C_CYAN}Config path:${C_RESET} ${C_GREEN}$CONFIG_FILE${C_RESET}" >&2
    if [ -n "${EDITOR:-}" ]; then
        echo -e "${C_YELLOW}Hint:${C_RESET} ${EDITOR} \"$CONFIG_FILE\"" >&2
    fi
    echo -e "${C_DIM}Security:${C_RESET} the file permissions are locked to 600 so the key stays local." >&2
}

# Simple helper to parse boolean-like values
_fuck_truthy() {
    local value="${1:-}"
    local normalized
    normalized=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    case "$normalized" in
        1|true|yes|y|on)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Debug helper
_fuck_debug() {
    if _fuck_truthy "${FUCK_DEBUG:-0}"; then
        echo -e "${C_DIM}[debug] $*${C_RESET}" >&2
    fi
}

# Spinner animation
_fuck_spinner() {
    local pid=$1
    local prefix="${2:-}"
    local delay=0.1
    local -a frames=("|" "/" "-" "\\")
    local frame_count=${#frames[@]}
    local frame_idx=0
    local has_prefix=0
    if [ -n "$prefix" ]; then
        has_prefix=1
    fi
    
    tput civis 2>/dev/null || printf "\033[?25l"

    while kill -0 "$pid" 2>/dev/null; do
        if [ "$has_prefix" -eq 1 ]; then
            printf "\r%s%s" "$prefix" "${frames[$frame_idx]}"
        else
            printf " %s " "${frames[$frame_idx]}"
            printf "\b\b\b"
        fi
        frame_idx=$(( (frame_idx + 1) % frame_count ))
        sleep "$delay"
    done

    if [ "$has_prefix" -eq 1 ]; then
        printf "\r%s" "$prefix"
        tput el 2>/dev/null || printf "\033[K"
    else
        printf "   \b\b\b"
    fi
    
    tput cnorm 2>/dev/null || printf "\033[?25h"
}

# Detects potentially dangerous commands and prints a warning
# --- Security Detection Engine (Phase 2) ---

# Block-level security rules (highest severity - execution denied)
# Format: 'pattern|||reason'
# Note: Not using 'readonly' to ensure compatibility with function-scoped sourcing
if [ -z "${_FUCK_SECURITY_BLOCK_RULES+x}" ] || [[ ${#_FUCK_SECURITY_BLOCK_RULES[@]} -eq 0 ]] 2>/dev/null; then
    _FUCK_SECURITY_BLOCK_RULES=(
        '(^|[;&|[:space:]])rm[[:space:]]+-rf[[:space:]]+/([[:space:]]|$)|||Recursive delete targeting root filesystem'
        'rm[[:space:]]+-rf[[:space:]]+/\*|||Recursive delete using /* under root'
        'rm[[:space:]]+-rf[[:space:]]+--no-preserve-root|||rm --no-preserve-root against /'
        'rm[[:space:]]+-rf[[:space:]]+\.\*|||Recursive delete targeting hidden/system files'
        '\bdd\b[^#\n]*\b(of|if)=/dev/|||Raw disk write via dd targeting /dev devices'
        '\bmkfs(\.\w+)?\b|||Filesystem format command detected'
        '\bfdisk\b|\bparted\b|\bformat\b|\bwipefs\b|\bshred\b|||Partition or disk wipe command detected'
        ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*&[[:space:]]*\}[[:space:]]*;[[:space:]]*:|||Fork bomb function detected'
    )
fi

# Challenge-level security rules (requires explicit user confirmation)
# Format: 'pattern|||reason'
# Note: Not using 'readonly' to ensure compatibility with function-scoped sourcing
if [ -z "${_FUCK_SECURITY_CHALLENGE_RULES+x}" ] || [[ ${#_FUCK_SECURITY_CHALLENGE_RULES[@]} -eq 0 ]] 2>/dev/null; then
    _FUCK_SECURITY_CHALLENGE_RULES=(
        'curl[^|]*\|\s*(bash|sh)|||Remote script execution via curl pipeline'
        'wget[^|]*\|\s*(bash|sh)|||Remote script execution via wget pipeline'
        '\bsource\s+https?://|||Sourcing a remote file over HTTP(S)'
        '\beval\b|\bexec\b|||Explicit eval/exec usage'
        '\$\([^)]*\)|||Command substitution using $()'
        '`[^`]*`|||Command substitution using backticks'
        '\b(sh|bash|env)\s+-c\b|||Nested shell invocation through -c'
        '\bpython[0-9.]*\s+-c\b|||Inline interpreter execution via -c'
        '(^|[;&|[:space:]])(cp|mv|rm|chmod|chown|sed|tee|cat)[^;&|]*/(etc|boot|sys|proc|dev)\b|||Operation touches critical system paths'
        '\bperl\s+-e\b|||Inline Perl execution via -e'
        '\bruby\s+-e\b|||Inline Ruby execution via -e'
        '\bnode\s+-e\b|||Inline Node.js execution via -e'
        '\bphp\s+-r\b|||Inline PHP execution via -r'
        'base64[^|]*\|\s*(bash|sh|eval)|||Base64 encoded command execution'
        '\bxargs\b.*(-I|-i|{}).*\b(sh|bash|rm|chmod)\b|||Command execution via xargs'
        '\bfind\b[^|;]*-exec\b|||Command execution via find -exec'
        '\b(awk|gawk|nawk|mawk)\b[^|;]*system\s*\(|||Indirect command execution via awk system()'
        '\bprintf\b.*\\\\x[0-9a-fA-F]|||Potential hex-encoded command injection'
        '\$\{[^}]*#\}|||Parameter expansion that may alter command'
        'echo\s+[^|]*\|\s*(bash|sh|eval)|||Echo pipeline to shell execution'
    )
fi

# Warn-level security rules (warning only, user can proceed)
# Format: 'pattern|||reason'
# Note: Not using 'readonly' to ensure compatibility with function-scoped sourcing
if [ -z "${_FUCK_SECURITY_WARN_RULES+x}" ] || [[ ${#_FUCK_SECURITY_WARN_RULES[@]} -eq 0 ]] 2>/dev/null; then
    _FUCK_SECURITY_WARN_RULES=(
        'sudo[[:space:]]+[^;&|]*rm[[:space:]]+-rf|||sudo rm -rf detected'
        'rm[[:space:]]+-rf\b|||Recursive delete request detected'
        'chmod[[:space:]]+.*777\b|||World-writable permission change detected'
        '>[[:space:]]*/(etc/(passwd|shadow|sudoers)|dev/sd[a-z]+)|||Output redirection into sensitive system files'
    )
fi

# Gets the current security mode from configuration
# Outputs: "strict", "balanced", or "off"
_fuck_security_mode() {
    local mode="${FUCK_SECURITY_MODE:-balanced}"
    mode=$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')

    case "$mode" in
        strict) printf 'strict\n' ;;
        off|disabled|none) printf 'off\n' ;;
        balanced|default|"") printf 'balanced\n' ;;
        *) printf 'balanced\n' ;;
    esac
}

# Gets the default challenge text for security confirmations
# Outputs: Default challenge phrase
_fuck_security_default_challenge_text() {
    printf 'I accept the risk'
}

# Checks if a command matches the security whitelist
# Arguments: $1 - command to check
# Returns: 0 if whitelisted, 1 otherwise
_fuck_security_is_whitelisted() {
    local command="$1"
    local whitelist="${FUCK_SECURITY_WHITELIST:-}"

    if [ -z "$whitelist" ]; then
        return 1
    fi

    local normalized entry
    normalized=$(printf '%s' "$whitelist" | tr ',' '\n')

    while IFS= read -r entry; do
        entry=$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$entry" ] && continue

        if printf '%s' "$command" | grep -Fq "$entry"; then
            return 0
        fi
    done <<< "$normalized"

    return 1
}

# Converts security level to numeric value for comparison
# Arguments: $1 - security level (block/challenge/warn/ok)
# Outputs: Numeric value (3/2/1/0)
_fuck_security_level_value() {
    case "$1" in
        block) printf '3\n' ;;
        challenge) printf '2\n' ;;
        warn) printf '1\n' ;;
        *) printf '0\n' ;;
    esac
}

# Promotes security level if candidate is more severe
# Arguments: $1 - current level, $2 - candidate level
# Outputs: The more severe level
_fuck_security_promote() {
    local current="$1"
    local candidate="$2"
    local current_val candidate_val

    current_val=$(_fuck_security_level_value "$current")
    candidate_val=$(_fuck_security_level_value "$candidate")

    if [ "$candidate_val" -gt "$current_val" ]; then
        printf '%s\n' "$candidate"
    else
        printf '%s\n' "$current"
    fi
}

# Applies security mode adjustments to severity level
# Arguments: $1 - mode (strict/balanced/off), $2 - severity level
# Outputs: Adjusted severity level
_fuck_security_apply_mode() {
    local mode="$1"
    local severity="$2"

    case "$mode" in
        strict)
            case "$severity" in
                warn) severity="challenge" ;;
                challenge) severity="block" ;;
            esac
            ;;
    esac

    printf '%s\n' "$severity"
}

# Matches command against a security rule table
# Arguments: $1 - command, $2 - rule table name
# Outputs: Reason string if matched
# Returns: 0 if matched, 1 otherwise
_fuck_security_match_rule() {
    local command="$1"
    local table="$2"
    local -a rules=()

    eval "rules=(\"\${${table}[@]}\")"

    local rule pattern reason
    for rule in "${rules[@]}"; do
        pattern=${rule%%|||*}
        reason=${rule#*|||}
        [ -z "$pattern" ] && continue

        if printf '%s' "$command" | grep -Eiq -- "$pattern"; then
            printf '%s\n' "$reason"
            return 0
        fi
    done

    return 1
}

# Displays warning message for potentially dangerous commands
# Arguments: $1 - reason for warning
_fuck_security_warn_message() {
    local reason="$1"
    echo -e "${C_RED_BOLD}⚠️  SECURITY WARNING:${C_RESET} ${reason}" >&2
    echo -e "${C_YELLOW}Review the command manually or add a whitelist entry if you fully trust it.${C_RESET}" >&2
}

# Displays block message for prohibited commands
# Arguments: $1 - reason for blocking
_fuck_security_block_message() {
    local reason="$1"
    echo -e "${C_RED_BOLD}⛔ SECURITY BLOCK:${C_RESET} ${reason}" >&2
    echo -e "${C_RED}Execution denied. Adjust FUCK_SECURITY_MODE or whitelist the command if absolutely necessary.${C_RESET}" >&2
}

# Displays challenge message for high-risk commands
# Arguments: $1 - reason for challenge, $2 - required phrase
_fuck_security_challenge_message() {
    local reason="$1"
    local phrase="$2"
    echo -e "${C_RED_BOLD}⚠️  SECURITY CHALLENGE:${C_RESET} ${reason}" >&2
    echo -e "${C_CYAN}Type the following phrase to continue:${C_RESET}" >&2
    echo -e "${C_BOLD}${phrase}${C_RESET}" >&2
}

# Prompts user to enter the required phrase for security challenge
# Arguments: $1 - required phrase
# Returns: 0 if phrase matches, 1 otherwise
_fuck_security_prompt_phrase() {
    local phrase="$1"
    local input=""

    printf "%b> %b" "$C_BOLD" "$C_RESET" >&2

    if [ -r /dev/tty ]; then
        if ! IFS= read -r input < /dev/tty; then
            printf "\n" >&2
            return 1
        fi
    else
        if ! IFS= read -r input; then
            printf "\n" >&2
            return 1
        fi
    fi

    printf "\n" >&2
    [ "$input" = "$phrase" ]
}

# Handles security decision based on severity level
# Arguments: $1 - severity level, $2 - reason, $3 - command
# Returns: 0 to allow execution, 1 to deny
_fuck_security_handle_decision() {
    local severity="$1"
    local reason="$2"
    local command="$3"

    case "$severity" in
        ""|ok|off)
            return 0
            ;;
        warn)
            _fuck_security_warn_message "${reason:-Potentially dangerous command detected}"
            return 0
            ;;
        challenge)
            local phrase="${FUCK_SECURITY_CHALLENGE_TEXT:-$(_fuck_security_default_challenge_text)}"
            _fuck_security_challenge_message "${reason:-High-risk command detected}" "$phrase"

            if _fuck_security_prompt_phrase "$phrase"; then
                echo -e "${C_GREEN}Security challenge acknowledged.${C_RESET}" >&2
                return 0
            fi

            echo -e "${C_RED}Security challenge failed. Command aborted.${C_RESET}" >&2
            return 1
            ;;
        block)
            _fuck_security_block_message "${reason:-Command blocked by policy}"
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Evaluates command security and returns severity level with reason
# Arguments: $1 - command to evaluate
# Outputs: "severity|reason" string
# Returns: 0 always (result is in output)
_fuck_security_evaluate_command() {
    local command="$1"
    local mode severity reason match promoted structural_reason

    mode=$(_fuck_security_mode)

    # Security engine disabled
    if [ "$mode" = "off" ]; then
        printf 'off|Security engine disabled\n'
        return 0
    fi

    # Check whitelist
    if _fuck_security_is_whitelisted "$command"; then
        printf 'ok|Command matched whitelist\n'
        return 0
    fi

    severity="ok"
    reason=""
    match=""

    # Check block rules (highest priority)
    if match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_BLOCK_RULES"); then
        severity="block"
        reason="$match"
    fi

    # Check challenge rules (medium priority)
    if [ "$severity" != "block" ] && match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_CHALLENGE_RULES"); then
        severity="challenge"
        reason="$match"
    fi

    # Check warn rules (low priority)
    if [ "$severity" = "ok" ] && match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_WARN_RULES"); then
        severity="warn"
        reason="$match"
    fi

    # Check for command chaining/piping (structural analysis)
    if printf '%s' "$command" | grep -Eiq '(&&|\|\||;|\|)'; then
        structural_reason="Command chaining or piping detected"
        promoted=$(_fuck_security_promote "$severity" "warn")

        if [ "$promoted" != "$severity" ]; then
            severity="$promoted"
            reason="$structural_reason"
        elif [ -z "$reason" ]; then
            reason="$structural_reason"
        fi
    fi

    # Apply security mode adjustments
    severity=$(_fuck_security_apply_mode "$mode" "$severity")

    printf '%s|%s\n' "$severity" "${reason:-Safe execution}"
}

# Legacy function for backward compatibility
# Arguments: $1 - command to check
# Outputs: "severity|reason" string
_fuck_detect_dangerous_command() {
    _fuck_security_evaluate_command "$1"
}


# Ensure a config file exists to help users tweak the behaviour
_fuck_secure_config_file() {
    if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}

_fuck_append_config_hint() {
    local key="$1"
    local comment="$2"
    local sample="$3"
    local quoted="${4:-1}"
    [ -f "$CONFIG_FILE" ] || return
    if grep -Eq "^\\s*#?\\s*export\\s+$key" "$CONFIG_FILE"; then
        return
    fi

    local assignment
    if [ "$quoted" = "1" ]; then
        assignment="# export $key=\"$sample\""
    else
        assignment="# export $key=$sample"
    fi

    {
        printf '\n'
        printf '# %s\n' "$comment"
        printf '%s\n' "$assignment"
    } >> "$CONFIG_FILE"
}

_fuck_seed_config_placeholders() {
    [ -f "$CONFIG_FILE" ] || return
    _fuck_append_config_hint "FUCK_OPENAI_API_KEY" "Local OpenAI-compatible API key (recommended)" 'sk-...'
    _fuck_append_config_hint "FUCK_ADMIN_KEY" "Optional: admin bypass key for trusted maintainers" 'adm-...'
    _fuck_append_config_hint "FUCK_OPENAI_MODEL" "Optional: override model when using your own key" 'gpt-4o-mini'
    _fuck_append_config_hint "FUCK_OPENAI_API_BASE" "Optional: override API base" 'https://api.openai.com/v1'
    _fuck_append_config_hint "FUCK_ALIAS" "Add an extra alias besides the default 'fuck'" 'pls'
    _fuck_append_config_hint "FUCK_AUTO_EXEC" "Skip confirmation prompts (use with caution!)" 'false' 0
    _fuck_append_config_hint "FUCK_TIMEOUT" "Override curl timeout (seconds)" '30' 0
    _fuck_append_config_hint "FUCK_DEBUG" "Enable verbose debug logs" 'false' 0
    _fuck_append_config_hint "FUCK_DISABLE_DEFAULT_ALIAS" "Disable the built-in 'fuck' alias" 'false' 0
    _fuck_append_config_hint "FUCK_SECURITY_MODE" "Security engine mode: strict|balanced|off" 'balanced'
    _fuck_append_config_hint "FUCK_SECURITY_WHITELIST" "Comma/newline separated command patterns to bypass security checks" ''
    _fuck_append_config_hint "FUCK_SECURITY_CHALLENGE_TEXT" "Phrase required for high-risk command confirmation" 'I accept the risk'
}

_fuck_ensure_config_exists() {
    if [ -f "$CONFIG_FILE" ]; then
        _fuck_seed_config_placeholders
        _fuck_secure_config_file
        return
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat <<'CFG' > "$CONFIG_FILE"
# fuckits configuration
# Toggle the exports below to customise your experience.

# Custom API endpoint that points to your self-hosted worker
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# Local OpenAI-compatible API key (recommended)
# export FUCK_OPENAI_API_KEY="sk-..."

# Optional: admin bypass key for trusted maintainers
# export FUCK_ADMIN_KEY="adm-..."

# Optional: override model/base when using your own key
# export FUCK_OPENAI_MODEL="gpt-4o-mini"
# export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# Add an extra alias besides the default 'fuck'
# export FUCK_ALIAS="pls"

# Skip confirmation prompts (use with caution!)
# export FUCK_AUTO_EXEC=false

# Override curl timeout (seconds)
# export FUCK_TIMEOUT=30

# Enable verbose debug logs
# export FUCK_DEBUG=false

# Disable the built-in 'fuck' alias
# export FUCK_DISABLE_DEFAULT_ALIAS=false
CFG

    _fuck_seed_config_placeholders
    _fuck_secure_config_file
}

_fuck_show_config_help() {
    _fuck_ensure_config_exists
    echo -e "${C_YELLOW}Configuration file:${C_RESET} ${C_CYAN}$CONFIG_FILE${C_RESET}"
    if [ -n "${EDITOR:-}" ]; then
        echo -e "${C_YELLOW}Edit with:${C_RESET} ${C_CYAN}${EDITOR} \"$CONFIG_FILE\"${C_RESET}"
    else
        echo -e "${C_YELLOW}Open this file in your favourite editor to customise fuckits.${C_RESET}"
    fi
    echo -e "${C_CYAN}Available toggles:${C_RESET} FUCK_API_ENDPOINT, FUCK_OPENAI_API_KEY, FUCK_ADMIN_KEY, FUCK_OPENAI_MODEL, FUCK_OPENAI_API_BASE, FUCK_ALIAS, FUCK_AUTO_EXEC, FUCK_TIMEOUT, FUCK_DEBUG, FUCK_DISABLE_DEFAULT_ALIAS"
    echo -e "${C_DIM}Pro tip:${C_RESET} we lock ${CONFIG_FILE} to chmod 600 so your API key stays local."
}

# Uninstalls the script
_uninstall_script() {
    echo -e "$FUCK ${C_YELLOW}So you're kicking me out? Fine.${C_RESET}"

    # Find the profile file
    local profile_file
    profile_file=$(_installer_detect_profile)
    local source_line="source $MAIN_SH"

    if [ "$profile_file" != "unknown_profile" ] && [ -f "$profile_file" ]; then
        if grep -qF "$source_line" "$profile_file"; then
            # Use sed to remove the lines. Create a backup.
            if sed --version >/dev/null 2>&1; then
                # GNU sed (Linux)
                sed -i.bak "\|$source_line\|d" "$profile_file"
                sed -i.bak "\|# Added by fuckits installer\|d" "$profile_file"
            else
                # BSD/macOS sed requires argument letter after -i
                sed -i.bak "" -e "\|$source_line\|d" "$profile_file"
                sed -i.bak "" -e "\|# Added by fuckits installer\|d" "$profile_file"
            fi
        fi
    else
        echo -e "${C_YELLOW}Could not find a shell profile file to modify. Your problem now.${C_RESET}"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi

    echo -e "$FUCK ${C_GREEN}I'm gone. Don't come crying back.${C_RESET}"
    echo -e "${C_CYAN}Now restart your damn shell.${C_RESET}"
}

# The main function that contacts the API
# Takes >0 arguments as the prompt
_fuck_execute_prompt() {
    # If the user types *only* "fuck uninstall"
    if [ "$1" = "uninstall" ] && [ "$#" -eq 1 ]; then
        _uninstall_script
        return 0
    fi

    # If the user types "fuck config"
    if [ "$1" = "config" ] && [ "$#" -eq 1 ]; then
        _fuck_show_config_help
        return 0
    fi

    if ! command -v curl &> /dev/null; then
        echo -e "$FUCK ${C_RED}'fuck' command needs 'curl'. Please install it.${C_RESET}" >&2
        return 1
    fi

    if [ "$#" -eq 0 ]; then
        echo -e "$FUCK ${C_RED}You forgot to ask me what to do.${C_RESET}" >&2
        return 1
    fi

    local prompt="$*"
    local auto_mode="${FUCK_AUTO_EXEC:-0}"
    local curl_timeout="${FUCK_TIMEOUT:-30}"
    local sysinfo_string
    sysinfo_string=$(_fuck_collect_sysinfo_string)

    local response=""
    local exit_code=0
    if _fuck_should_use_local_api; then
        echo -ne "${C_YELLOW}Using your local API key...${C_RESET} "
        response=$(_fuck_request_local_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    else
        local spinner_label="Thinking... "
        printf '%s' "$spinner_label"
        response=$(_fuck_request_worker_model "$prompt" "$sysinfo_string" "$curl_timeout" "$spinner_label")
        exit_code=$?
    fi

    echo ""

    if [ $exit_code -ne 0 ] || [ -z "$response" ]; then
        return $exit_code
    fi

    echo -e "${C_CYAN}Here is what I came up with:${C_RESET}"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"
    printf '%s\n' "$response"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"

    # Security check for dangerous commands
    local security_result security_level security_reason
    security_result=$(_fuck_detect_dangerous_command "$response")
    security_level=${security_result%%|*}
    security_reason=${security_result#*|}

    # Handle security decision based on severity
    if ! _fuck_security_handle_decision "$security_level" "$security_reason" "$response"; then
        echo -e "${C_RED}❌ Command aborted due to security policy.${C_RESET}" >&2
        return 1
    fi

    local should_exec=false

    if _fuck_truthy "$auto_mode"; then
        echo -e "${C_YELLOW}⚡ Auto-exec enabled. Running...${C_RESET}"
        should_exec=true
    else
        # Interactive confirmation
        while true; do
            printf "${C_BOLD}Execute? [Y/n] ${C_RESET}"
            local confirmation normalized
            if [ -r /dev/tty ]; then
                IFS= read -r confirmation < /dev/tty
            else
                # Fallback for no TTY
                IFS= read -r confirmation
            fi

            confirmation=$(printf '%s' "${confirmation:-}" | tr -d ' \t\r')
            normalized=$(printf '%s' "$confirmation" | tr '[:upper:]' '[:lower:]')

            case "$normalized" in
                ""|"y"|"yes")
                    should_exec=true
                    echo -e "${C_GREEN}✅ Executing...${C_RESET}"
                    break
                    ;;
                "n"|"no")
                    should_exec=false
                    echo -e "${C_YELLOW}❌ Aborted.${C_RESET}" >&2
                    break
                    ;;
                *)
                    # Loop again
                    ;;
            esac
        done
    fi

    if [ "$should_exec" = "true" ]; then
        eval "$response"
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo -e "$FUCK ${C_RED}Command failed with exit code $exit_code.${C_RESET}" >&2
        fi
        return $exit_code
    else
        # The 'Aborted.' message is now printed within the loop,
        # so we just return 1 here if should_exec is false.
        return 1
    fi
}

# Define the alias for interactive use (supports custom aliases)
_fuck_define_aliases() {
    local default_alias="fuck"

    if ! _fuck_truthy "${FUCK_DISABLE_DEFAULT_ALIAS:-0}"; then
        alias "$default_alias"='_fuck_execute_prompt'
    fi

    if [ -n "${FUCK_ALIAS:-}" ] && [ "$FUCK_ALIAS" != "$default_alias" ]; then
        alias "$FUCK_ALIAS"='_fuck_execute_prompt'
    fi
}

_fuck_define_aliases

# --- End Core Logic ---
EOF

# --- End of Core Logic Heredoc ---

# Helper to materialize the embedded core logic into a file (used for install/temp execution)
_fuck_write_core() {
    local target="$1"
    printf '%s\n' "$CORE_LOGIC" > "$target"
}

# Helper to source the core logic into the current shell
_fuck_source_core() {
   local tmp_core
   tmp_core=$(mktemp)
   _fuck_write_core "$tmp_core"
   # shellcheck disable=SC1090
   source "$tmp_core"
   rm -f "$tmp_core"
}


# --- Installer Functions (Run by the outer script) ---

# Helper to find the user's shell profile file
_installer_detect_profile() {
    if [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "bash"; then
        echo "$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        # Fallback for sh, ksh, etc.
        echo "$HOME/.profile"
    elif [ -f "$HOME/.zshrc" ]; then
        # Fallback if SHELL var isn't set
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        # Fallback if SHELL var isn't set
        echo "$HOME/.bashrc"
    else
        echo "unknown_profile"
    fi
}

# Main installation function
_installer_secure_config_file() {
        if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}

_install_script() {
    echo -e "$FCKN ${C_BOLD}Alright, let's get this shit installed...${C_RESET}"
    mkdir -p "$INSTALL_DIR"
    
    # Write the embedded core logic to the main.sh file
    _fuck_write_core "$MAIN_SH"
    
    if [ $? -ne 0 ]; then
        echo -e "$FUCK ${C_RED}Can't write to the file. Check your damn permissions.${C_RESET}" >&2
        return 1
    fi

    # Create a default config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        cat <<'CFG' > "$CONFIG_FILE"
# fuckits configuration
# Toggle the exports below to customise your experience.

# Custom API endpoint that points to your self-hosted worker
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# Local OpenAI-compatible API key (recommended)
# export FUCK_OPENAI_API_KEY="sk-..."

# Optional: override model/base when using your own key
# export FUCK_OPENAI_MODEL="gpt-4o-mini"
# export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# Add an extra alias besides the default 'fuck'
# export FUCK_ALIAS="pls"

# Skip confirmation prompts (use with caution!)
# export FUCK_AUTO_EXEC=false

# Override curl timeout (seconds)
# export FUCK_TIMEOUT=30

# Enable verbose debug logs
# export FUCK_DEBUG=false

# Disable the built-in 'fuck' alias
# export FUCK_DISABLE_DEFAULT_ALIAS=false
CFG
        _installer_secure_config_file
    fi

    # Add source line to shell profile
    local profile_file
    profile_file=$(_installer_detect_profile)
    
    if [ "$profile_file" = "unknown_profile" ]; then
        echo -e "$FUCK ${C_RED}I can't find .bashrc, .zshrc, or .profile. You're on your own.${C_RESET}" >&2
        echo -e "${C_YELLOW}Manually add this line to whatever startup file you use:${C_RESET}" >&2
        echo -e "\n  ${C_CYAN}source $MAIN_SH${C_RESET}\n" >&2
        return
    fi
    
    local source_line="source $MAIN_SH"
    if ! grep -qF "$source_line" "$profile_file"; then
        # Ensure the file ends with a newline before we add our lines
        if [ -n "$(tail -c1 "$profile_file")" ]; then
            echo "" >> "$profile_file"
        fi
        echo "# Added by fuckits installer" >> "$profile_file"
        echo "$source_line" >> "$profile_file"
        echo -e "$FUCK ${C_GREEN}It's installed. Now get to work.${C_RESET}"
        echo -e "${C_YELLOW}Restart your shell, or run ${C_BOLD}source $profile_file${C_YELLOW} to start.${C_RESET}"
        echo -e "\n${C_BOLD}--- HOW TO USE ---${C_RESET}"
        echo -e "Just type ${C_RED_BOLD}fuck${C_RESET} followed by what you want to do."
        echo -e "Examples:"
        echo -e "  ${C_CYAN}fuck install git${C_RESET}"
        echo -e "  ${C_CYAN}fuck uninstall git${C_RESET}"
        echo -e "  ${C_CYAN}fuck find all files larger than 10MB in the current directory${C_RESET}"
        echo -e "  ${C_RED_BOLD}fuck uninstall${C_RESET} ${C_GREEN}# Uninstalls ${C_RESET}${C_RED}fuck${C_RESET}${C_GREEN} itself${C_RESET}"
        echo -e "  ${C_RED_BOLD}fuck config${C_RESET} ${C_GREEN}# Show configuration help${C_RESET}"
        echo -e "\n${C_YELLOW}Remember to restart your shell to begin!${C_RESET}"
    else
        echo -e "$FUCK ${C_YELLOW}It's already installed, genius. Just updated the script for you.${C_RESET}"
    fi
}


# --- Main Script Entrypoint ---

# If being sourced for testing, load core logic and skip entrypoint
if [ -n "${BATS_TEST_DIRNAME:-}" ] || [ -n "${BATS_TEST_FILENAME:-}" ]; then
    # Load core logic functions for testing
    _fuck_source_core
    return 0
fi

# If arguments are passed (e.g., "bash -s ...")
if [ "$#" -gt 0 ]; then
    if [ "$1" = "install" ] && [ "$#" -eq 1 ]; then
        _install_script
        exit 0
    fi

    _fuck_source_core
    _fuck_execute_prompt "$@"
else
    _install_script
fi
