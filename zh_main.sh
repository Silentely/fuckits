#!/bin/bash
#
# 这是 fuckits 的安装和临时运行脚本
# 欢迎使用
#
# --- 安全使用方法 ---
#
# 1. 下载:
#    curl -o fuckits https://fuckits.25500552.xyz/zh
#
# 2. 查看代码:
#    less fuckits
#
# 3. 运行 (安装):
#    bash fuckits
#
# 4. 运行 (临时使用):
#    bash fuckits "你的命令"
#

set -euo pipefail

# --- 颜色定义 ---
readonly C_RESET='\033[0m'
readonly C_RED_BOLD='\033[1;31m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'

readonly FUCKITS_LOCALE="zh"

# --- 提示符 ---
readonly FUCK="${C_RED_BOLD}[!]${C_RESET}"
readonly FCKN="${C_RED}[提示]${C_RESET}"


# --- 配置 ---
if [ -z "${HOME:-}" ]; then
    echo -e "\033[1;31m错误!\033[0m \033[0;31m您的 HOME 环境变量未设置，无法确定安装位置，请先设置该变量。 (例如: export HOME=/root)\033[0m" >&2
    exit 1
fi
readonly INSTALL_DIR="$HOME/.fuck"
readonly MAIN_SH="$INSTALL_DIR/main.sh"
readonly CONFIG_FILE="$INSTALL_DIR/config.sh"


# --- 核心逻辑 (塞进一个字符串里) ---
read -r -d '' CORE_LOGIC <<'EOF' || true

# --- fuckits 核心逻辑开始 ---

# --- 颜色定义 ---
# 只有在没定义过颜色的情况下才定义 (临时模式用)
if [ -z "${C_RESET:-}" ]; then
    readonly C_RESET='\033[0m'
    readonly C_RED_BOLD='\033[1;31m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_CYAN='\033[0;36m'
    readonly C_BOLD='\033[1m'
    readonly C_DIM='\033[2m'

    # --- 提示符 ---
    readonly FUCK="${C_RED_BOLD}[!]${C_RESET}"
    readonly FCKN="${C_RED}[提示]${C_RESET}"

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

# 如果存在配置文件则加载
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

if [ -z "${DEFAULT_API_ENDPOINT+x}" ]; then
    readonly DEFAULT_API_ENDPOINT="https://fuckits.25500552.xyz/zh"
fi

# 找用户 shell 配置文件的辅助函数
_installer_detect_profile() {
    if [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "bash"; then
        echo "$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        # 兼容 sh, ksh 等
        echo "$HOME/.profile"
    elif [ -f "$HOME/.zshrc" ]; then
        # SHELL 变量没设置时的备用方案
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        # SHELL 变量没设置时的备用方案
        echo "$HOME/.bashrc"
    else
        echo "unknown_profile"
    fi
}

# --- 系统信息收集模块 ---
# 静态系统信息缓存文件（跨运行持久化）
# 仅在未定义时设置（防止 read-only 变量错误）
if [ -z "${FUCK_SYSINFO_CACHE_FILE:-}" ]; then
    readonly FUCK_SYSINFO_CACHE_FILE="$INSTALL_DIR/.sysinfo.cache"
fi
# 缓存状态跟踪变量
_FUCK_STATIC_CACHE_LOADED=0
_FUCK_STATIC_CACHE_DIRTY=0

# 从缓存文件加载静态系统信息
# 全局变量: _FUCK_STATIC_CACHE_LOADED, FUCK_SYSINFO_CACHE_FILE
_fuck_load_static_cache() {
    # 如果缓存已加载则直接返回
    if [ "${_FUCK_STATIC_CACHE_LOADED:-0}" -eq 1 ]; then
        return 0
    fi

    _FUCK_STATIC_CACHE_LOADED=1

    # 如果缓存文件存在则加载
    if [ -f "$FUCK_SYSINFO_CACHE_FILE" ]; then
        # shellcheck disable=SC1090
        source "$FUCK_SYSINFO_CACHE_FILE" || true
    fi
}

# 标记静态缓存为脏（需要持久化）
# 全局变量: _FUCK_STATIC_CACHE_DIRTY
_fuck_mark_static_cache_dirty() {
    _FUCK_STATIC_CACHE_DIRTY=1
}

# 将静态系统信息持久化到缓存文件
# 全局变量: _FUCK_STATIC_CACHE_DIRTY, FUCK_SYSINFO_CACHE_FILE
# 返回值: 成功返回 0，失败返回 1
_fuck_persist_static_cache() {
    # 仅在缓存脏时才持久化
    if [ "${_FUCK_STATIC_CACHE_DIRTY:-0}" -ne 1 ]; then
        return 0
    fi

    # 确保缓存目录存在
    local cache_dir
    cache_dir=$(dirname "$FUCK_SYSINFO_CACHE_FILE")
    if ! mkdir -p "$cache_dir" 2>/dev/null; then
        return 1
    fi

    # 创建临时文件进行原子写入
    local tmp_file
    tmp_file=$(mktemp) || return 1

    # 将缓存变量写入临时文件
    {
        printf '_FUCK_CACHED_DISTRO=%q\\n' "${_FUCK_CACHED_DISTRO:-}"
        printf '_FUCK_CACHED_KERNEL=%q\\n' "${_FUCK_CACHED_KERNEL:-}"
        printf '_FUCK_CACHED_ARCH=%q\\n' "${_FUCK_CACHED_ARCH:-}"
        printf '_FUCK_CACHED_PKG_MANAGER=%q\\n' "${_FUCK_CACHED_PKG_MANAGER:-}"
    } > "$tmp_file"

    # 原子移动到最终位置
    if mv "$tmp_file" "$FUCK_SYSINFO_CACHE_FILE" 2>/dev/null; then
        _FUCK_STATIC_CACHE_DIRTY=0
        return 0
    else
        # 失败时清理临时文件
        rm -f "$tmp_file"
        return 1
    fi
}

# 检测发行版/系统家族（支持缓存）
# 输出: 发行版字符串（如："Debian 系 12.04 (Ubuntu 24.04 LTS)"）
_fuck_detect_distro() {
    _fuck_load_static_cache

    # 如果有缓存值则直接返回
    if [ -n "${_FUCK_CACHED_DISTRO:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_DISTRO"
        return 0
    fi

    local kernel_name distro id version pretty family
    kernel_name=$(uname -s 2>/dev/null || printf 'unknown')
    distro="unknown"

    # macOS 检测
    if [ "$kernel_name" = "Darwin" ]; then
        local product version
        product=$(sw_vers -productName 2>/dev/null || printf 'macOS')
        product=$(printf '%s' "$product" | tr -d '\r\n')
        version=$(sw_vers -productVersion 2>/dev/null || printf 'unknown')
        version=$(printf '%s' "$version" | tr -d '\r\n')
        distro="$product $version"
    # Linux 使用 /etc/os-release 检测
    elif [ -r /etc/os-release ]; then
        id=$(grep -E '^ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        version=$(grep -E '^VERSION_ID=' /etc/os-release | head -n1 | cut -d= -f2 | tr -d '"')
        pretty=$(grep -E '^PRETTY_NAME=' /etc/os-release | head -n1 | cut -d= -f2- | tr -d '"')

        # 确定系统家族以便更好地分类
        family=""
        case "$id" in
            ubuntu|debian)
                family="Debian 系"
                ;;
            centos|rhel|rocky|almalinux|fedora)
                family="RHEL 系"
                ;;
            arch|manjaro|endeavouros)
                family="Arch 系"
                ;;
        esac

        # 格式化发行版字符串，包含家族和版本信息
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

    # 缓存并返回结果
    _FUCK_CACHED_DISTRO="$distro"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$distro"
}

# 获取内核版本信息（支持缓存）
# 输出: 内核版本字符串（如："Linux 6.8.0-31-generic"）
_fuck_get_kernel_version() {
    _fuck_load_static_cache

    # 如果有缓存值则直接返回
    if [ -n "${_FUCK_CACHED_KERNEL:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_KERNEL"
        return 0
    fi

    local kernel
    kernel=$(uname -sr 2>/dev/null || uname -s 2>/dev/null || printf 'unknown')
    kernel=$(printf '%s' "$kernel" | tr -d '\r\n')

    # 缓存并返回结果
    _FUCK_CACHED_KERNEL="$kernel"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$kernel"
}

# 获取系统架构（支持缓存）
# 输出: 架构字符串（如："x86_64", "arm64"）
_fuck_get_architecture() {
    _fuck_load_static_cache

    # 如果有缓存值则直接返回
    if [ -n "${_FUCK_CACHED_ARCH:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_ARCH"
        return 0
    fi

    local arch
    arch=$(uname -m 2>/dev/null || printf 'unknown')
    arch=$(printf '%s' "$arch" | tr -d '\r\n')

    # 缓存并返回结果
    _FUCK_CACHED_ARCH="$arch"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$arch"
}

# 收集用户信息包括权限级别
# 输出: 用户信息字符串（如："User=john uid=1000 level=sudoer Groups=john adm sudo"）
_fuck_collect_user_info() {
    local current_user uid groups level
    current_user="${USER:-}"

    # 如果 USER 未设置则使用备用方法
    if [ -z "$current_user" ]; then
        current_user=$(whoami 2>/dev/null || printf 'unknown')
    fi

    # 如果 id 命令可用则获取 UID 和用户组
    uid="unknown"
    groups="unknown"
    if command -v id >/dev/null 2>&1; then
        uid=$(id -u "$current_user" 2>/dev/null || id -u 2>/dev/null || printf 'unknown')
        groups=$(id -Gn "$current_user" 2>/dev/null || id -Gn 2>/dev/null || printf 'unknown')
    fi

    # 确定权限级别
    level="user"
    if [ "$uid" = "0" ]; then
        level="root"
    elif printf '%s' "$groups" | grep -Eq '(^|[[:space:]])(sudo|wheel|admin)([[:space:]]|$)'; then
        level="sudoer"
    fi

    printf 'User=%s uid=%s level=%s Groups=%s' "$current_user" "$uid" "$level" "$groups"
}

# 收集常用开发工具的版本信息
# 输出: 工具版本字符串（如："git:git version 2.34.1; docker:Docker version 24.0.6; ..."）
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

        # 清理版本字符串
        version=$(printf '%s' "${version:-unknown}" | tr '\r\n' '  ' | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//')
        [ -z "$version" ] && version="unknown"

        result="$result$tool:$version; "
    done

    # 移除末尾的分号和空格
    result="${result%; }"
    printf '%s' "$result"
}

# 检测包管理器（支持缓存）
# 输出: 包管理器名称（apt, yum, dnf, pacman, zypper, brew, unknown）
_fuck_detect_pkg_manager() {
    _fuck_load_static_cache

    # 如果有缓存值则直接返回
    if [ -n "${_FUCK_CACHED_PKG_MANAGER:-}" ]; then
        printf '%s\n' "$_FUCK_CACHED_PKG_MANAGER"
        return 0
    fi

    local manager="unknown"

    # 按优先级检测包管理器
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

    # 缓存并返回结果
    _FUCK_CACHED_PKG_MANAGER="$manager"
    _fuck_mark_static_cache_dirty
    printf '%s\n' "$manager"
}

# 收集简化的系统信息并格式化为结构化字符串
# 输出: 用于 AI 处理的系统信息字符串
_fuck_collect_sysinfo_string() {
    local os_type kernel_name pkg_manager summary

    # 检测操作系统类型
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

    # 格式化为简单的结构化字符串
    printf -v summary 'OS=%s; PkgMgr=%s' "$os_type" "$pkg_manager"
    printf '%s\n' "$summary"
}

_fuck_json_escape() {
    local input="$1"
    # 使用 printf 正确处理控制字符
    printf '%s' "$input" | sed -e '
        # 首先转义反斜杠（必须是第一个）
        s/\\/\\\\/g
        # 转义双引号
        s/"/\\"/g
        # 转义控制字符（ASCII 0-31）
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
        printf '你是一个专业的 shell 脚本生成器。用户会提供他们的系统信息和一个命令。你的任务是返回一个可执行的、原始的 shell 脚本来完成他们的目标。脚本可以是多行的。不要提供任何解释、注释、markdown 格式（比如 ```bash）或 shebang（例如 #!/bin/bash）。只需要原始的脚本内容。用户的系统信息是：%s' "$sysinfo"
    else
        printf 'You are an expert shell script generator. A user will provide their system information and a prompt. Your task is to return a raw, executable shell script that accomplishes their goal. The script can be multi-line. Do not provide any explanation, comments, markdown formatting (like ```bash), or a shebang (e.g., #!/bin/bash). Just the raw script content. The user'"'"'s system info is: %s' "$sysinfo"
    fi
}

_fuck_extract_command_from_json() {
    local json_file="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$json_file" <<'PY2'
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
PY2
        return
    fi

    if command -v node >/dev/null 2>&1; then
        node - "$json_file" <<'JS2'
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
JS2
        return
    fi

    echo -e "$FUCK ${C_RED}无法解析模型返回的数据，请安装 python3 或 node。${C_RESET}" >&2
    return 1
}

_fuck_request_local_model() {
    local prompt="$1"
    local sysinfo="$2"
    local curl_timeout="$3"

    local api_key="${FUCK_OPENAI_API_KEY:-}"
    if [ -z "$api_key" ]; then
        echo -e "$FUCK ${C_RED}未配置本地 API Key，请在 ~/.fuck/config.sh 中设置 FUCK_OPENAI_API_KEY。${C_RESET}" >&2
        return 1
    fi

    local model="${FUCK_OPENAI_MODEL:-gpt-5-nano}"
    local api_base="${FUCK_OPENAI_API_BASE:-https://api.openai.com/v1}"
    api_base=${api_base%/}
    local api_url="$api_base/chat/completions"

    _fuck_debug "本地 API 基址: $api_base"
    _fuck_debug "本地模型: $model"

    local system_prompt
    system_prompt=$(_fuck_local_system_prompt "$sysinfo")

    local payload
    payload=$(printf '{ "model": "%s", "messages": [ {"role":"system","content":"%s"}, {"role":"user","content":"%s"} ], "max_tokens": 1024, "temperature": 0.2 }' \
        "$model" "$(_fuck_json_escape "$system_prompt")" "$(_fuck_json_escape "$prompt")")

    local tmp_json
    tmp_json=$(mktemp) || return 1

    if ! curl -fsS --max-time "$curl_timeout" "$api_url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" > "$tmp_json"; then
        echo -e "$FUCK ${C_RED}本地 API 请求失败。${C_RESET}" >&2
        cat "$tmp_json" >&2
        rm -f "$tmp_json"
        return 1
    fi

    local command_output
    if ! command_output=$(_fuck_extract_command_from_json "$tmp_json"); then
        rm -f "$tmp_json"
        echo -e "$FUCK ${C_RED}无法解析模型返回内容。${C_RESET}" >&2
        return 1
    fi

    rm -f "$tmp_json"
    printf '%s\n' "$command_output"
}

_fuck_request_worker_model() {
    local prompt="$1"
    local sysinfo="$2"
    local curl_timeout="$3"

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
        _fuck_spinner "$pid" >&2
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
        echo -e "$FUCK ${C_RED}无法连接到共享 Worker。${C_RESET}" >&2
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
        echo -e "$FUCK ${C_RED}共享 Worker 返回 HTTP $http_status。${C_RESET}" >&2
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

    echo -e "$FUCK ${C_YELLOW}共享体验额度已用光（每天最多 ${daily_limit} 次）。${C_RESET}" >&2
    case "$remaining" in
        ''|*[!0-9]*) ;;
        *)
            if [ "$remaining" -gt 0 ]; then
                echo -e "${C_DIM}今日剩余额度：$remaining 次。${C_RESET}" >&2
            fi
            ;;
    esac

    _fuck_ensure_config_exists
    _fuck_secure_config_file

    echo -e "${C_CYAN}解决方案：${C_RESET}运行 ${C_GREEN}fuck config${C_RESET}，在 ${C_GREEN}$CONFIG_FILE${C_RESET} 中设置 ${C_BOLD}FUCK_OPENAI_API_KEY${C_RESET}，必要时同时配置 ${C_BOLD}FUCK_OPENAI_MODEL${C_RESET}/${C_BOLD}FUCK_OPENAI_API_BASE${C_RESET}。" >&2
    echo -e "${C_CYAN}若你持有管理员免额密钥：${C_RESET}同样在该文件中配置 ${C_BOLD}FUCK_ADMIN_KEY${C_RESET}（需与 Worker 侧的 ADMIN_ACCESS_KEY 匹配）即可跳过共享额度限制。" >&2
    if [ -n "${EDITOR:-}" ]; then
        echo -e "${C_YELLOW}提示：${C_RESET}${EDITOR} \"$CONFIG_FILE\"" >&2
    fi
    echo -e "${C_DIM}安全提示：配置文件自动 chmod 600，仅限当前用户读取。${C_RESET}" >&2
}


# 判断是否为 true/yes/on 等
_fuck_truthy() {
    local value="${1:-}"
    local normalized
    normalized=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    case "$normalized" in
        1|true|yes|y|on|是|开|真)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 调试日志
_fuck_debug() {
    if _fuck_truthy "${FUCK_DEBUG:-0}"; then
        echo -e "${C_DIM}[调试] $*${C_RESET}" >&2
    fi
}

# Spinner 动画
_fuck_spinner() {
    local pid=$1
    local delay=0.1
    local -a frames=("|" "/" "-" "\\")
    local frame_count=${#frames[@]}
    local frame_idx=0
    
    # 隐藏光标
    tput civis 2>/dev/null || printf "\033[?25l"

    while kill -0 "$pid" 2>/dev/null; do
        printf " %s " "${frames[$frame_idx]}"
        frame_idx=$(( (frame_idx + 1) % frame_count ))
        sleep "$delay"
        printf "\b\b\b"
    done
    printf "   \b\b\b"
    
    # 恢复光标
    tput cnorm 2>/dev/null || printf "\033[?25h"
}

# --- 安全检测引擎 (Phase 2) ---

# 阻止级安全规则（最高严重性 - 拒绝执行）
# 格式：'模式|||原因'
if [ -z "${_FUCK_SECURITY_BLOCK_RULES:-}" ]; then
    readonly -a _FUCK_SECURITY_BLOCK_RULES=(
        '(^|[;&|[:space:]])rm[[:space:]]+-rf[[:space:]]+/([[:space:]]|$)|||检测到 rm -rf /，会直接删除根目录'
        'rm[[:space:]]+-rf[[:space:]]+/\*|||检测到 rm -rf /*，可能清空根目录'
        'rm[[:space:]]+-rf[[:space:]]+--no-preserve-root|||检测到 --no-preserve-root，风险极高'
        'rm[[:space:]]+-rf[[:space:]]+\.\*|||检测到 rm -rf .*，可能删除全部隐藏文件'
        '\bdd\b[^#\n]*\b(of|if)=/dev/|||检测到 dd 正在写入 /dev 设备'
        '\bmkfs(\.\w+)?\b|||检测到 mkfs/格式化操作'
        '\bfdisk\b|\bparted\b|\bformat\b|\bwipefs\b|\bshred\b|||检测到分区或磁盘擦除命令'
        ':\(\)\s*{\s*:\s*\|\s*:;\s*}\s*;?\s*:|||检测到 Fork 炸弹模式'
    )
fi

# 挑战级安全规则（需要明确用户确认）
# 格式：'模式|||原因'
if [ -z "${_FUCK_SECURITY_CHALLENGE_RULES:-}" ]; then
    readonly -a _FUCK_SECURITY_CHALLENGE_RULES=(
        'curl[^|]*\|\s*(bash|sh)|||curl 管道 bash/sh，可能远程执行脚本'
        'wget[^|]*\|\s*(bash|sh)|||wget 管道 bash/sh，可能远程执行脚本'
        '\bsource\s+https?://|||source 远程脚本'
        '\beval\b|\bexec\b|||使用 eval/exec 动态执行'
        '\$\([^)]*\)|||检测到 $(...) 命令替换'
        '`[^`]*`|||检测到反引号命令替换'
        '\b(sh|bash|env)\s+-c\b|||检测到 sh/bash -c 包装命令'
        '\bpython[0-9.]*\s+-c\b|||检测到 python -c 内联脚本'
        '(^|[;&|[:space:]])(cp|mv|rm|chmod|chown|sed|tee|cat)[^;&|]*\b/(etc|boot|sys|proc|dev)\b|||命令操作关键系统路径'
    )
fi

# 警告级安全规则（仅警告，用户可继续）
# 格式：'模式|||原因'
if [ -z "${_FUCK_SECURITY_WARN_RULES:-}" ]; then
    readonly -a _FUCK_SECURITY_WARN_RULES=(
        'rm[[:space:]]+-rf\b|||发现 rm -rf，执行前请再次确认'
        'chmod[[:space:]]+.*777\b|||检测到 chmod 777 权限'
        'sudo[[:space:]]+[^;&|]*rm[[:space:]]+-rf|||sudo rm -rf 风险'
        '>[[:space:]]*/(etc/(passwd|shadow|sudoers)|dev/sd[a-z]+)|||重定向输出到敏感系统文件'
    )
fi

# 从配置获取当前安全模式
# 输出："strict"、"balanced" 或 "off"
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

# 获取安全确认的默认挑战文本
# 输出：默认挑战短语
_fuck_security_default_challenge_text() {
    printf '我确认承担风险'
}

# 检查命令是否匹配安全白名单
# 参数：$1 - 要检查的命令
# 返回：0 如果在白名单中，1 否则
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

# 将安全级别转换为数值以便比较
# 参数：$1 - 安全级别（block/challenge/warn/ok）
# 输出：数值（3/2/1/0）
_fuck_security_level_value() {
    case "$1" in
        block) printf '3\n' ;;
        challenge) printf '2\n' ;;
        warn) printf '1\n' ;;
        *) printf '0\n' ;;
    esac
}

# 如果候选级别更严重则提升安全级别
# 参数：$1 - 当前级别，$2 - 候选级别
# 输出：更严重的级别
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

# 根据安全模式调整严重性级别
# 参数：$1 - 模式（strict/balanced/off），$2 - 严重性级别
# 输出：调整后的严重性级别
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

# 将命令与安全规则表匹配
# 参数：$1 - 命令，$2 - 规则表名称
# 输出：如果匹配则输出原因字符串
# 返回：0 如果匹配，1 否则
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

# 显示潜在危险命令的警告消息
# 参数：$1 - 警告原因
_fuck_security_warn_message() {
    local reason="$1"
    echo -e "${C_RED_BOLD}⚠️  安全警告：${C_RESET}${reason}" >&2
    echo -e "${C_YELLOW}请仔细审查，若确认可信可配置 FUCK_SECURITY_WHITELIST。${C_RESET}" >&2
}

# 显示被禁止命令的阻止消息
# 参数：$1 - 阻止原因
_fuck_security_block_message() {
    local reason="$1"
    echo -e "${C_RED_BOLD}⛔ 已阻止：${C_RESET}${reason}" >&2
    echo -e "${C_RED}执行被拒绝，可调整 FUCK_SECURITY_MODE 或加入白名单后重试。${C_RESET}" >&2
}

# 显示高风险命令的挑战消息
# 参数：$1 - 挑战原因，$2 - 需要的短语
_fuck_security_challenge_message() {
    local reason="$1"
    local phrase="$2"
    echo -e "${C_RED_BOLD}⚠️  高危挑战：${C_RESET}${reason}" >&2
    echo -e "${C_CYAN}如需继续，请输入下方短语：${C_RESET}" >&2
    echo -e "${C_BOLD}${phrase}${C_RESET}" >&2
}

# 提示用户输入安全挑战所需的短语
# 参数：$1 - 需要的短语
# 返回：0 如果短语匹配，1 否则
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

# 根据严重性级别处理安全决策
# 参数：$1 - 严重性级别，$2 - 原因，$3 - 命令
# 返回：0 允许执行，1 拒绝
_fuck_security_handle_decision() {
    local severity="$1"
    local reason="$2"
    local command="$3"

    case "$severity" in
        ""|ok|off)
            return 0
            ;;
        warn)
            _fuck_security_warn_message "${reason:-检测到潜在风险}"
            return 0
            ;;
        challenge)
            local phrase="${FUCK_SECURITY_CHALLENGE_TEXT:-$(_fuck_security_default_challenge_text)}"
            _fuck_security_challenge_message "${reason:-高危命令，请再次确认}" "$phrase"

            if _fuck_security_prompt_phrase "$phrase"; then
                echo -e "${C_GREEN}已通过安全挑战。${C_RESET}" >&2
                return 0
            fi

            echo -e "${C_RED}安全挑战失败，命令被取消。${C_RESET}" >&2
            return 1
            ;;
        block)
            _fuck_security_block_message "${reason:-命令被安全策略阻止}"
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# 评估命令安全性并返回严重性级别和原因
# 参数：$1 - 要评估的命令
# 输出："严重性|原因" 字符串
# 返回：始终返回 0（结果在输出中）
_fuck_security_evaluate_command() {
    local command="$1"
    local mode severity reason match promoted structural_reason

    mode=$(_fuck_security_mode)

    # 安全引擎已禁用
    if [ "$mode" = "off" ]; then
        printf 'off|安全引擎已关闭\n'
        return 0
    fi

    # 检查白名单
    if _fuck_security_is_whitelisted "$command"; then
        printf 'ok|命令命中白名单\n'
        return 0
    fi

    severity="ok"
    reason=""
    match=""

    # 检查阻止规则（最高优先级）
    if match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_BLOCK_RULES"); then
        severity="block"
        reason="$match"
    fi

    # 检查挑战规则（中等优先级）
    if [ "$severity" != "block" ] && match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_CHALLENGE_RULES"); then
        severity="challenge"
        reason="$match"
    fi

    # 检查警告规则（低优先级）
    if [ "$severity" = "ok" ] && match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_WARN_RULES"); then
        severity="warn"
        reason="$match"
    fi

    # 检查命令链接/管道（结构分析）
    if printf '%s' "$command" | grep -Eiq '(&&|\|\||;|\|)'; then
        structural_reason="检测到命令分隔符/管道"
        promoted=$(_fuck_security_promote "$severity" "warn")

        if [ "$promoted" != "$severity" ]; then
            severity="$promoted"
            reason="$structural_reason"
        elif [ -z "$reason" ]; then
            reason="$structural_reason"
        fi
    fi

    # 应用安全模式调整
    severity=$(_fuck_security_apply_mode "$mode" "$severity")

    printf '%s|%s\n' "$severity" "${reason:-当前命令未命中安全规则}"
}

# 向后兼容的遗留函数
# 参数：$1 - 要检查的命令
# 输出："严重性|原因" 字符串
_fuck_detect_dangerous_command() {
    _fuck_security_evaluate_command "$1"
}


# 确保配置文件存在
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
    _fuck_append_config_hint "FUCK_OPENAI_API_KEY" "本地 OpenAI 兼容 Key（推荐）" 'sk-...'
    _fuck_append_config_hint "FUCK_ADMIN_KEY" "管理员免额度密钥（仅分享给信任的人）" 'adm-...'
    _fuck_append_config_hint "FUCK_OPENAI_MODEL" "覆盖默认模型" 'gpt-4o-mini'
    _fuck_append_config_hint "FUCK_OPENAI_API_BASE" "自定义 API 基址" 'https://api.openai.com/v1'
    _fuck_append_config_hint "FUCK_ALIAS" "额外别名（不影响默认 fuck）" '运行'
    _fuck_append_config_hint "FUCK_AUTO_EXEC" "自动执行返回命令（危险操作）" 'false' 0
    _fuck_append_config_hint "FUCK_TIMEOUT" "请求超时时间（秒）" '30' 0
    _fuck_append_config_hint "FUCK_DEBUG" "是否输出调试信息" 'false' 0
    _fuck_append_config_hint "FUCK_DISABLE_DEFAULT_ALIAS" "禁用内置 fuck 别名" 'false' 0
    _fuck_append_config_hint "FUCK_SECURITY_MODE" "安全引擎模式：strict|balanced|off" 'balanced'
    _fuck_append_config_hint "FUCK_SECURITY_WHITELIST" "以逗号或换行分隔的信任命令片段" ''
    _fuck_append_config_hint "FUCK_SECURITY_CHALLENGE_TEXT" "高危命令需要输入的确认短语" '我确认承担风险'
}

_fuck_ensure_config_exists() {
    if [ -f "$CONFIG_FILE" ]; then
        _fuck_seed_config_placeholders
        _fuck_secure_config_file
        return
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat <<'CFG' > "$CONFIG_FILE"
# fuckits 配置示例
# 去掉行首的 #，改成你自己的值即可。

# 自建/自定义 Worker 入口
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# 本地 OpenAI 兼容 Key（强烈推荐）
# export FUCK_OPENAI_API_KEY="sk-..."

# 管理员专用免额度密钥（仅分享给信任的人）
# export FUCK_ADMIN_KEY="adm-..."

# 覆盖默认模型或 API 基址
# export FUCK_OPENAI_MODEL="gpt-4o-mini"
# export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# 额外别名（不会影响默认 fuck）
# export FUCK_ALIAS="运行"

# 自动执行返回命令（危险，谨慎开启）
# export FUCK_AUTO_EXEC=false

# 请求超时时间（秒）
# export FUCK_TIMEOUT=30

# 是否输出调试信息
# export FUCK_DEBUG=false

# 禁用内置 fuck 别名
# export FUCK_DISABLE_DEFAULT_ALIAS=false
CFG

    _fuck_seed_config_placeholders
    _fuck_secure_config_file
}

# 显示配置提示
_fuck_show_config_help() {
    _fuck_ensure_config_exists
    echo -e "${C_YELLOW}配置文件：${C_RESET} ${C_CYAN}$CONFIG_FILE${C_RESET}"
    if [ -n "${EDITOR:-}" ]; then
        echo -e "${C_YELLOW}可以使用：${C_RESET} ${C_CYAN}${EDITOR} $CONFIG_FILE${C_RESET}"
    else
        echo -e "${C_YELLOW}用任意编辑器打开该文件即可修改配置。${C_RESET}"
    fi
    echo -e "${C_CYAN}可用选项：${C_RESET}FUCK_API_ENDPOINT, FUCK_OPENAI_API_KEY, FUCK_ADMIN_KEY, FUCK_OPENAI_MODEL, FUCK_OPENAI_API_BASE, FUCK_ALIAS, FUCK_AUTO_EXEC, FUCK_TIMEOUT, FUCK_DEBUG, FUCK_DISABLE_DEFAULT_ALIAS"
    echo -e "${C_DIM}安全说明：配置文件会自动 chmod 600，防止 Key 泄露。${C_RESET}"
}

# 卸载脚本
_uninstall_script() {
    echo -e "${C_RED_BOLD}好好好！${C_RESET}${C_YELLOW}怎么着，要卸磨杀驴啊？行啊你个老六，我真谢谢你了。${C_RESET}"

    # 找配置文件
    local profile_file
    profile_file=$(_installer_detect_profile)
    local source_line="source $MAIN_SH"

    if [ "$profile_file" != "unknown_profile" ] && [ -f "$profile_file" ]; then
        if grep -qF "$source_line" "$profile_file"; then
            # 用 sed 把那几行删了，顺便备个份
            if sed --version >/dev/null 2>&1; then
                sed -i.bak "\|$source_line\|d" "$profile_file"
                sed -i.bak "\|# Added by fuckits installer\|d" "$profile_file"
            else
                sed -i.bak "" -e "\|$source_line\|d" "$profile_file"
                sed -i.bak "" -e "\|# Added by fuckits installer\|d" "$profile_file"
            fi
        fi
    else
        echo -e "${C_YELLOW}找不到 shell 配置文件，您可以手动删除相关配置。${C_RESET}"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi

    sleep 3
    echo -e "${C_GREEN}行，我先走一步，告辞。${C_CYAN}赶紧重启你那终端吧，不然会别名污染。${C_RESET}"
    sleep 3
    echo -e "${C_YELLOW}临别之际，献上一首小诗，祝您前程似锦：${C_RESET}"
    sleep 2
    echo -e "\n${C_RED}《诗经·彼阳》${C_RESET}"
    sleep 2
    echo -e "${C_YELLOW}彼阳若至，初升东曦。${C_RESET}"
    sleep 2
    echo -e "${C_YELLOW}绯雾飒蔽，似幕绡绸。${C_RESET}"
    sleep 3
    echo -e "${C_YELLOW}彼阳篝碧，雾霂涧滁。${C_RESET}"
    sleep 4
    echo -e "${C_YELLOW}赤石冬溪，似玛瑙潭。${C_RESET}"
    sleep 4
    echo -e "${C_YELLOW}彼阳晚意，暖梦似乐。${C_RESET}"
    sleep 3
    echo -e "${C_YELLOW}寐游浮沐，若雉飞舞。${C_RESET}"
}

# 跟 API 通信的主函数
# 参数就是要执行的命令
_fuck_execute_prompt() {
    # 如果用户只输入 "fuck uninstall"
    if [ "$1" = "uninstall" ] && [ "$#" -eq 1 ]; then
        _uninstall_script
        return 0
    fi

    # 如果用户输入 "fuck config"
    if [ "$1" = "config" ] && [ "$#" -eq 1 ]; then
        _fuck_show_config_help
        return 0
    fi

    if ! command -v curl &> /dev/null; then
        echo -e "$FUCK ${C_RED}'fuck' 命令需要 'curl'，请先安装 curl。${C_RESET}" >&2
        return 1
    fi

    if [ "$#" -eq 0 ]; then
        echo -e "$FUCK ${C_RED}请提供要执行的命令。${C_RESET}" >&2
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
        printf "${C_YELLOW}使用本地 API Key... ${C_RESET}"
        response=$(_fuck_request_local_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    else
        printf "${C_YELLOW}思考中💭 ${C_RESET}"
        response=$(_fuck_request_worker_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    fi

    printf "\r" # Clear the line before printing a newline
    echo ""

    if [ $exit_code -ne 0 ] || [ -z "$response" ]; then
        return $exit_code
    fi

    echo -e "${C_CYAN}为您生成了以下命令：${C_RESET}"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"
    printf '%s\n' "$response"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"

    # 安全检查危险命令
    local security_result security_level security_reason
    security_result=$(_fuck_detect_dangerous_command "$response")
    security_level=${security_result%%|*}
    security_reason=${security_result#*|}

    # 根据严重性级别处理安全决策
    if ! _fuck_security_handle_decision "$security_level" "$security_reason" "$response"; then
        echo -e "${C_RED}❌ 命令因安全策略被中止。${C_RESET}" >&2
        return 1
    fi

    local should_exec=false

    if _fuck_truthy "$auto_mode"; then
        echo -e "${C_YELLOW}⚡ 已开启自动执行模式，立即运行...${C_RESET}"
        should_exec=true
    else
        while true; do
            printf "${C_BOLD}是否执行？[Y/n] ${C_RESET}"
            local confirmation normalized
            if [ -r /dev/tty ]; then
                IFS= read -r confirmation < /dev/tty
            else
                read -r confirmation
            fi

            confirmation=$(printf '%s' "${confirmation:-}" | tr -d ' \t\r')
            normalized=$(printf '%s' "$confirmation" | tr '[:upper:]' '[:lower:]')

            case "$normalized" in
                ""|"y"|"yes"|"是")
                    should_exec=true
                    echo -e "${C_GREEN}✅ 执行中...${C_RESET}"
                    break
                    ;;
                "n"|"no"|"否")
                    should_exec=false
                    echo -e "${C_YELLOW}❌ 已取消。${C_RESET}" >&2
                    break
                    ;;
                *)
                    # Loop
                    ;;
            esac
        done
    fi

    if [ "$should_exec" = "true" ]; then
        eval "$response"
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo -e "${C_RED_BOLD}错误！${C_RED}命令执行失败，退出码 $exit_code。${C_RESET}" >&2
        fi
        return $exit_code
    else
        # "已取消。" 消息现在在循环内打印，
        # 所以如果 should_exec 为 false，直接返回 1 即可。
        return 1
    fi
}

# 定义别名（支持自定义别名）
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

# --- 核心逻辑结束 ---
EOF

# --- 核心逻辑 Heredoc 结束 ---

# 将内嵌核心逻辑写到文件中（安装/临时模式都会用到）
_fuck_write_core() {
    local target="$1"
    printf '%s\n' "$CORE_LOGIC" > "$target"
}

# 将核心逻辑载入当前 shell
_fuck_source_core() {
    local tmp_core
    tmp_core=$(mktemp)
    _fuck_write_core "$tmp_core"
    # shellcheck disable=SC1090
    source "$tmp_core"
    rm -f "$tmp_core"
}

# 将内嵌核心逻辑写入指定文件（安装与临时执行会用到）
_fuck_write_core() {
    local target="$1"
    printf '%s\n' "$CORE_LOGIC" > "$target"
}


# --- 安装函数 (由外部脚本运行) ---

# 找用户 shell 配置文件的辅助函数
_installer_detect_profile() {
    if [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [ -n "${SHELL:-}" ] && echo "$SHELL" | grep -q "bash"; then
        echo "$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        # 兼容 sh, ksh 等
        echo "$HOME/.profile"
    elif [ -f "$HOME/.zshrc" ]; then
        # SHELL 变量没设置时的备用方案
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        # SHELL 变量没设置时的备用方案
        echo "$HOME/.bashrc"
    else
        echo "unknown_profile"
    fi
}

# 主安装函数
_installer_secure_config_file() {
    if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}

_install_script() {
    echo -e "${C_BOLD}开始安装 fuckits...${C_RESET}"
    mkdir -p "$INSTALL_DIR"
    
    # 把核心逻辑写进 main.sh
    _fuck_write_core "$MAIN_SH"
    
    if [ $? -ne 0 ]; then
        echo -e "$FUCK ${C_RED}无法写入文件，请检查目录权限。${C_RESET}" >&2
        return 1
    fi

    # 如果没有配置文件则生成一个示例
    if [ ! -f "$CONFIG_FILE" ]; then
        cat <<'CFG' > "$CONFIG_FILE"
# fuckits 配置示例
# 去掉行首的 #，改成你自己的值即可。

# 自建/自定义 Worker 入口
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# 本地 OpenAI 兼容 Key（强烈推荐）
# export FUCK_OPENAI_API_KEY="sk-..."

# 覆盖默认模型或 API 基址
# export FUCK_OPENAI_MODEL="gpt-4o-mini"
# export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# 额外别名（不会影响默认 fuck）
# export FUCK_ALIAS="运行"

# 自动执行返回的命令（危险，谨慎开启）
# export FUCK_AUTO_EXEC=false

# 请求超时时间（秒）
# export FUCK_TIMEOUT=30

# 是否输出调试信息
# export FUCK_DEBUG=false

# 禁用内置 fuck 别名
# export FUCK_DISABLE_DEFAULT_ALIAS=false
CFG
        _installer_secure_config_file
    fi

    # 把 source 那行加到 shell 配置文件里
    local profile_file
    profile_file=$(_installer_detect_profile)
    
    if [ "$profile_file" = "unknown_profile" ]; then
        echo -e "$FUCK ${C_RED}找不到 .bashrc, .zshrc 或 .profile，无法自动配置。${C_RESET}" >&2
        echo -e "${C_YELLOW}请手动将以下内容添加到您的 shell 配置文件中：${C_RESET}" >&2
        echo -e "\n  ${C_CYAN}source $MAIN_SH${C_RESET}\n" >&2
        return
    fi
    
    local source_line="source $MAIN_SH"
    if ! grep -qF "$source_line" "$profile_file"; then
        # 保证文件最后有换行
        if [ -n "$(tail -c1 "$profile_file")" ]; then
            echo "" >> "$profile_file"
        fi
        echo "# Added by fuckits installer" >> "$profile_file"
        echo "$source_line" >> "$profile_file"
        echo -e "${C_GREEN}安装完成！${C_RESET}"
        echo -e "${C_YELLOW}请重启终端或执行 ${C_BOLD}source $profile_file${C_YELLOW} 以使更改生效。${C_RESET}"
        echo -e "\n${C_BOLD}--- 使用方法 ---${C_RESET}"
        echo -e "使用 ${C_RED_BOLD}fuck${C_RESET} 命令后跟您想执行的操作即可。"
        echo -e "示例:"
        echo -e "  ${C_CYAN}fuck install git${C_RESET}"
        echo -e "  ${C_CYAN}fuck uninstall git${C_RESET}"
        echo -e "  ${C_CYAN}fuck 找出当前目录所有大于10MB的文件${C_RESET}"
        echo -e "  ${C_RED_BOLD}fuck uninstall${C_RESET} ${C_GREEN}# 卸载 fuckits${C_RESET}"
        echo -e "  ${C_RED_BOLD}fuck config${C_RESET} ${C_GREEN}# 显示配置帮助${C_RESET}"
        echo -e "\n${C_YELLOW}记得重启终端以使用新命令！${C_RESET}"
    else
        echo -e "$FUCK ${C_YELLOW}检测到已安装，已为您更新脚本。${C_RESET}"
    fi
}


# --- 主脚本入口 ---

# 如果有参数传进来 (比如 "bash -s ...")
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
