#!/bin/bash
#
# fuckits - 统一安装脚本（双语支持）
# 构建时自动生成 main.sh（英文）和 zh_main.sh（中文）
#

set -euo pipefail

# --- 构建时注入的默认语言 ---
# 构建脚本会替换这个值
_FUCKITS_BUILD_DEFAULT_LOCALE="zh"

# --- 防止 readonly 变量重复定义 ---
# 此守卫允许脚本被多次 source；子进程可能继承标记但不会继承普通变量。
FUCKITS_CONSTANTS_DEFINED=1

# --- 颜色定义 ---
[[ -z "${C_RESET+x}" ]] && readonly C_RESET='\033[0m'
[[ -z "${C_RED_BOLD+x}" ]] && readonly C_RED_BOLD='\033[1;31m'
[[ -z "${C_RED+x}" ]] && readonly C_RED='\033[0;31m'
[[ -z "${C_GREEN+x}" ]] && readonly C_GREEN='\033[0;32m'
[[ -z "${C_YELLOW+x}" ]] && readonly C_YELLOW='\033[0;33m'
[[ -z "${C_CYAN+x}" ]] && readonly C_CYAN='\033[0;36m'
[[ -z "${C_BOLD+x}" ]] && readonly C_BOLD='\033[1m'
[[ -z "${C_DIM+x}" ]] && readonly C_DIM='\033[2m'

# --- FUCK! ---
[[ -z "${FUCK+x}" ]] && readonly FUCK="${C_RED_BOLD}FUCK!${C_RESET}"
[[ -z "${FCKN+x}" ]] && readonly FCKN="${C_RED}F*CKING${C_RESET}"

# --- i18n 国际化系统 ---

# 当前语言（构建时可覆盖默认值）
_FUCKITS_LOCALE="${FUCKITS_LOCALE:-en}"

# 初始化翻译表
_i18n_init() {
    # 如果已初始化，跳过
    [[ "${_I18N_INITIALIZED:-0}" = "1" ]] && return 0

    _I18N_KEYS='msg.help.title
msg.help.usage
msg.help.commands
msg.help.options
msg.help.examples
msg.config.title
msg.config.edit_with
msg.config.open_file
msg.config.available_toggles
msg.config.pro_tip
msg.config.lock_info
msg.error.api_key_not_set
msg.error.api_request_failed
msg.error.parse_response_failed
msg.error.home_not_set
msg.status.thinking
msg.status.using_local_key
msg.status.here_is_result
msg.security.potentially_dangerous
msg.security.high_risk
msg.security.blocked
msg.security.confirm_risk
msg.update.new_version
msg.update.current
msg.update.up_to_date
msg.update.remote_version
msg.update.local_version
msg.lang.current
msg.lang.switched
msg.lang.invalid
msg.lang.detecting'
    _I18N_INITIALIZED=1
}

# 查询翻译文本；使用 case 保持 Bash 3.2 兼容，避免关联数组依赖。
# Arguments: $1=翻译键
_i18n_lookup() {
    case "$1" in
        msg.help.title) echo "AI natural language to shell command" ;;
        msg.help.usage) echo "Usage: fuck <your prompt>" ;;
        msg.help.commands) echo "Commands:" ;;
        msg.help.options) echo "Options:" ;;
        msg.help.examples) echo "Examples:" ;;
        msg.config.title) echo "Configuration" ;;
        msg.config.edit_with) echo "Edit with:" ;;
        msg.config.open_file) echo "Open this file in your favourite editor to customise fuckits." ;;
        msg.config.available_toggles) echo "Available toggles:" ;;
        msg.config.pro_tip) echo "Pro tip:" ;;
        msg.config.lock_info) echo "we lock CONFIG_FILE to chmod 600 so your API key stays local." ;;
        msg.error.api_key_not_set) echo "Local API key not configured. Set FUCK_OPENAI_API_KEY in ~/.fuck/config.sh." ;;
        msg.error.api_request_failed) echo "Local API request failed." ;;
        msg.error.parse_response_failed) echo "Unable to parse local model response." ;;
        msg.error.home_not_set) echo "Your HOME variable isn't set. I don't know where to install this shit. Set it yourself (e.g., export HOME=/root)." ;;
        msg.status.thinking) echo "Thinking... " ;;
        msg.status.using_local_key) echo "Using your local API key... " ;;
        msg.status.here_is_result) echo "Here is what I came up with:" ;;
        msg.security.potentially_dangerous) echo "Potentially dangerous command detected" ;;
        msg.security.high_risk) echo "High-risk command detected" ;;
        msg.security.blocked) echo "Command blocked by policy" ;;
        msg.security.confirm_risk) echo "I accept the risk" ;;
        msg.update.new_version) echo "New version available:" ;;
        msg.update.current) echo "current:" ;;
        msg.update.up_to_date) echo "is up to date." ;;
        msg.update.remote_version) echo "Remote version:" ;;
        msg.update.local_version) echo "Local version:" ;;
        msg.lang.current) echo "Current language:" ;;
        msg.lang.switched) echo "Language switched to:" ;;
        msg.lang.invalid) echo "Invalid language. Use 'en' or 'zh'." ;;
        msg.lang.detecting) echo "Detected system language:" ;;
        msg.help.title.zh) echo "AI 自然语言转 Shell 命令" ;;
        msg.help.usage.zh) echo "用法: fuck <你的需求>" ;;
        msg.help.commands.zh) echo "可用命令:" ;;
        msg.help.options.zh) echo "选项:" ;;
        msg.help.examples.zh) echo "示例:" ;;
        msg.config.title.zh) echo "配置" ;;
        msg.config.edit_with.zh) echo "可以使用：" ;;
        msg.config.open_file.zh) echo "用任意编辑器打开该文件即可修改配置。" ;;
        msg.config.available_toggles.zh) echo "可用选项：" ;;
        msg.config.pro_tip.zh) echo "安全说明：" ;;
        msg.config.lock_info.zh) echo "配置文件会自动 chmod 600，防止 Key 泄露。" ;;
        msg.error.api_key_not_set.zh) echo "未配置本地 API Key，请在 ~/.fuck/config.sh 中设置 FUCK_OPENAI_API_KEY。" ;;
        msg.error.api_request_failed.zh) echo "本地 API 请求失败。" ;;
        msg.error.parse_response_failed.zh) echo "无法解析本地模型响应。" ;;
        msg.error.home_not_set.zh) echo "HOME 变量未设置，无法确定安装位置。请自行设置（如 export HOME=/root）。" ;;
        msg.status.thinking.zh) echo "思考中... " ;;
        msg.status.using_local_key.zh) echo "正在使用本地 API Key... " ;;
        msg.status.here_is_result.zh) echo "这是我想出来的命令：" ;;
        msg.security.potentially_dangerous.zh) echo "检测到潜在风险" ;;
        msg.security.high_risk.zh) echo "高危命令，请再次确认" ;;
        msg.security.blocked.zh) echo "命令被安全策略阻止" ;;
        msg.security.confirm_risk.zh) echo "我确认承担风险" ;;
        msg.update.new_version.zh) echo "新版本可用：" ;;
        msg.update.current.zh) echo "当前：" ;;
        msg.update.up_to_date.zh) echo "已是最新。" ;;
        msg.update.remote_version.zh) echo "远程版本：" ;;
        msg.update.local_version.zh) echo "本地版本：" ;;
        msg.lang.current.zh) echo "当前语言：" ;;
        msg.lang.switched.zh) echo "语言已切换为：" ;;
        msg.lang.invalid.zh) echo "无效语言。请使用 'en' 或 'zh'。" ;;
        msg.lang.detecting.zh) echo "检测到系统语言：" ;;
        *) return 1 ;;
    esac
}

_i18n_has_key() {
    _i18n_lookup "$1" >/dev/null 2>&1
}

# 获取翻译文本
# Arguments: $1=翻译键
# Outputs: 翻译后的文本
_i18n_get() {
    local key="$1"

    # 确保翻译表已初始化
    [[ "${_I18N_INITIALIZED:-0}" != "1" ]] && _i18n_init

    # 先尝试获取当前语言的翻译
    local localized_key="${key}.${_FUCKITS_LOCALE}"
    if _i18n_lookup "$localized_key"; then
        return 0
    fi

    # 回退到基础键（英文）
    if _i18n_lookup "$key"; then
        return 0
    fi

    # 键不存在，返回键名
    echo "$key"
}

# 设置当前语言
# Arguments: $1=语言代码（en/zh）
_i18n_set_locale() {
    local locale="$1"
    case "$locale" in
        en|zh)
            _FUCKITS_LOCALE="$locale"
            export FUCKITS_LOCALE="$locale"
            ;;
        *)
            return 1
            ;;
    esac
}

# 自动检测系统语言
# Outputs: 检测到的语言代码
_i18n_detect_locale() {
    local sys_locale="${LANG:-${LC_ALL:-en_US.UTF-8}}"

    # 提取语言代码（取下划线前的部分，转小写）
    local lang_code
    lang_code=$(echo "${sys_locale%%_*}" | tr '[:upper:]' '[:lower:]')

    # 映射到支持的语言
    case "$lang_code" in
        zh|cn)
            echo "zh"
            ;;
        *)
            echo "en"
            ;;
    esac
}

# --- 语言初始化和切换 ---

# 兼容仅 source fuckits.sh 的测试场景；完整安装脚本会提供 _fuck_truthy
_fuck_lang_truthy() {
    if declare -F _fuck_truthy >/dev/null 2>&1; then
        _fuck_truthy "${1:-}"
        return $?
    fi

    local value
    value=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
    case "$value" in
        1|true|yes|y|on|是|开|真)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 确保语言配置可写；完整安装脚本会提供 _fuck_ensure_config_exists
_fuck_lang_ensure_config_exists() {
    [[ -n "${CONFIG_FILE:-}" ]] || return 1

    if declare -F _fuck_ensure_config_exists >/dev/null 2>&1; then
        _fuck_ensure_config_exists
        return $?
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        {
            echo "# fuckits configuration"
            echo "# Toggle the exports below to customise your experience."
        } > "$CONFIG_FILE"
    fi
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

# 初始化语言（自动检测 + 配置覆盖）
_fuck_init_locale() {
    # 优先级：环境变量 > 配置文件 > 构建默认语言 > 系统检测

    # 1. 首先检查环境变量
    if [[ -n "${FUCKITS_LOCALE:-}" ]]; then
        _FUCKITS_LOCALE="$FUCKITS_LOCALE"
    # 2. 然后检查配置文件
    elif [[ -n "${CONFIG_FILE:-}" ]] && [[ -f "$CONFIG_FILE" ]] && grep -q "^export FUCKITS_LOCALE=" "$CONFIG_FILE" 2>/dev/null; then
        local config_locale
        config_locale=$(grep "^export FUCKITS_LOCALE=" "$CONFIG_FILE" | tail -n 1 | cut -d'"' -f2)
        _FUCKITS_LOCALE="$config_locale"
    # 3. 然后使用构建时注入的默认语言
    elif [[ "$_FUCKITS_BUILD_DEFAULT_LOCALE" != "__BUILD_DEFAULT_LOCALE__" ]]; then
        _FUCKITS_LOCALE="$_FUCKITS_BUILD_DEFAULT_LOCALE"
    # 4. 最后自动检测系统语言
    else
        _FUCKITS_LOCALE=$(_i18n_detect_locale)
    fi

    export FUCKITS_LOCALE="$_FUCKITS_LOCALE"
}

# 初始化语言设置（在脚本加载时自动执行）
_fuck_init_locale

# 处理 --lang 命令
# Arguments: $1=语言代码（可选）
_fuck_handle_lang_command() {
    local target_locale="${1:-}"

    # 确保翻译表已初始化
    _i18n_init

    # 无参数：显示当前语言
    if [[ -z "$target_locale" ]]; then
        if _fuck_lang_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","locale":"%s"}\n' "$_FUCKITS_LOCALE"
        else
            local current_label
            current_label=$(_i18n_get "msg.lang.current")
            echo -e "${C_CYAN}${current_label}${C_RESET} ${C_BOLD}${_FUCKITS_LOCALE}${C_RESET}"
        fi
        return 0
    fi

    # 验证语言代码
    case "$target_locale" in
        en|zh)
            # 有效语言，执行切换
            _i18n_set_locale "$target_locale"

            # 持久化到配置文件；未配置 CONFIG_FILE 时仅更新当前进程语言
            if [[ -n "${CONFIG_FILE:-}" ]]; then
                _fuck_lang_ensure_config_exists
                if grep -q "^export FUCKITS_LOCALE=" "$CONFIG_FILE" 2>/dev/null; then
                    # 更新现有配置
                    sed -i.bak "s/^export FUCKITS_LOCALE=.*/export FUCKITS_LOCALE=\"$target_locale\"/" "$CONFIG_FILE"
                    rm -f "${CONFIG_FILE}.bak"
                else
                    # 添加新配置
                    echo "" >> "$CONFIG_FILE"
                    echo "# Language / 语言设置" >> "$CONFIG_FILE"
                    echo "export FUCKITS_LOCALE=\"$target_locale\"" >> "$CONFIG_FILE"
                fi
            fi

            # 输出结果
            if _fuck_lang_truthy "${_FUCK_JSON_MODE:-0}"; then
                printf '{"status":"ok","locale":"%s"}\n' "$target_locale"
            else
                local switched_label
                switched_label=$(_i18n_get "msg.lang.switched")
                echo -e "${C_GREEN}✅ ${switched_label}${C_RESET} ${C_BOLD}${target_locale}${C_RESET}"
            fi
            return 0
            ;;
        *)
            # 无效语言
            if _fuck_lang_truthy "${_FUCK_JSON_MODE:-0}"; then
                printf '{"status":"error","message":"Invalid language. Use en or zh."}\n'
            else
                local invalid_label
                invalid_label=$(_i18n_get "msg.lang.invalid")
                echo -e "${C_RED}❌ ${invalid_label}${C_RESET}" >&2
            fi
            return 1
            ;;
    esac
}

# --- 运行时配置默认值 ---
# 统一源码被测试直接 source 时，不一定经过旧安装器的顶部初始化。
if [[ -z "${INSTALL_DIR+x}" ]] || [[ -z "${MAIN_SH+x}" ]] || [[ -z "${CONFIG_FILE+x}" ]]; then
    if [[ -z "${HOME:-}" ]]; then
        msg_home=$(_i18n_get "msg.error.home_not_set")
        echo -e "\033[1;31mFUCK!\033[0m \033[0;31m${msg_home}\033[0m" >&2
        exit 1
    fi
    INSTALL_DIR="$HOME/.fuck"
    MAIN_SH="$INSTALL_DIR/main.sh"
    CONFIG_FILE="$INSTALL_DIR/config.sh"
    SCRIPT_VERSION='2.2.0'
fi

if [[ -z "${DEFAULT_API_ENDPOINT+x}" ]]; then
    DEFAULT_API_ENDPOINT="https://fuckits.25500552.xyz/"
fi

# --- 内联运行时共享函数（由 build.sh 从 scripts/runtime-common.sh 注入）---
#!/bin/bash
#
# Runtime common functions for fuckits
# Shared between main.sh (EN) and zh_main.sh (ZH)
# This file is sourced at runtime, not during build
#

_fuck_json_escape() {
    local input="$1"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$input" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read())[1:-1], end='')"
        return
    fi
    if command -v node >/dev/null 2>&1; then
        printf '%s' "$input" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>process.stdout.write(JSON.stringify(d).slice(1,-1)))"
        return
    fi
    # Minimal fallback: escape backslashes and double quotes only
    printf '%s' "$input" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g'
}

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

_fuck_security_level_value() {
    case "$1" in
        block) printf '3\n' ;;
        challenge) printf '2\n' ;;
        warn) printf '1\n' ;;
        *) printf '0\n' ;;
    esac
    return 0
}

_fuck_security_match_rule() {
    local command="$1"
    local table="$2"
    local -a rules=()

    # SECURITY NOTE: This eval is SAFE because:
    # - $table only receives hardcoded internal array names from callers within this script
    # - Valid values: _FUCK_SECURITY_BLOCK_RULES, _FUCK_SECURITY_CHALLENGE_RULES, _FUCK_SECURITY_WARN_RULES
    # - No user input can reach this variable; it's purely for dynamic array name resolution
    # - This pattern is a standard Bash idiom for indirect array access (Bash 3.x compatible)
    eval "rules=(\"\${${table}[@]}\")"

    local rule pattern reason
    for rule in "${rules[@]}"; do
        pattern=${rule%%|||*}
        reason=${rule#*|||}
        [[ -z "$pattern" ]] && continue

        if printf '%s' "$command" | grep -Eiq -- "$pattern"; then
            printf '%s\n' "$reason"
            return 0
        fi
    done

    return 1
}

_fuck_security_is_whitelisted() {
    local command="$1"
    local whitelist="${FUCK_SECURITY_WHITELIST:-}"

    if [[ -z "$whitelist" ]]; then
        return 1
    fi

    local normalized entry
    normalized=$(printf '%s' "$whitelist" | tr ',' '\n')

    while IFS= read -r entry; do
        entry=$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$entry" ]] && continue

        # 前缀匹配：命令必须以白名单条目开头（或完全相等）
        # 例如白名单 "ls" 匹配 "ls -la" 但不匹配 "vls"
        if [[ "$command" == "$entry" ]] || [[ "$command" == "$entry "* ]]; then
            return 0
        fi
    done <<< "$normalized"

    return 1
}

_fuck_security_mode() {
    local mode="${FUCK_SECURITY_MODE:-balanced}"
    mode=$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')

    case "$mode" in
        strict) printf 'strict\n' ;;
        off|disabled|none) printf 'off\n' ;;
        balanced|default|"") printf 'balanced\n' ;;
        *) printf 'balanced\n' ;;
    esac
    return 0
}

_fuck_mark_static_cache_dirty() {
    _FUCK_STATIC_CACHE_DIRTY=1
    return 0
}

_fuck_load_static_cache() {
    # Return early if cache is already loaded
    if [[ "${_FUCK_STATIC_CACHE_LOADED:-0}" -eq 1 ]]; then
        return 0
    fi

    _FUCK_STATIC_CACHE_LOADED=1

    # Source cache file if it exists
    if [[ -f "$FUCK_SYSINFO_CACHE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$FUCK_SYSINFO_CACHE_FILE" || true
    fi
}

_fuck_persist_static_cache() {
    # Only persist if cache is dirty
    if [[ "${_FUCK_STATIC_CACHE_DIRTY:-0}" -ne 1 ]]; then
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
    if command mv -f -- "$tmp_file" "$FUCK_SYSINFO_CACHE_FILE" 2>/dev/null; then
        _FUCK_STATIC_CACHE_DIRTY=0
        return 0
    else
        # Clean up temporary file on failure
        rm -f "$tmp_file"
        return 1
    fi
}

_fuck_audit_log() {
    # Check if audit logging is enabled
    if [[ "${FUCK_AUDIT_LOG:-false}" != "true" ]]; then
        return 0
    fi

    local event="$1"
    local command="$2"
    local exit_code="${3:--}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
    local log_file="${FUCK_AUDIT_LOG_FILE:-$INSTALL_DIR/.audit.log}"

    # Ensure log directory exists
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true

    # Sanitize command for logging (normalize newlines, escape delimiter, limit length)
    local sanitized_cmd
    local raw_len=${#command}
    sanitized_cmd=$(printf '%s' "$command" | tr '\r\n' '  ' | sed 's/|/\\|/g' | head -c 200)
    if [[ "$raw_len" -gt 200 ]]; then
        sanitized_cmd="${sanitized_cmd}..."
    fi

    # Write to log file (format: timestamp|user|event|exit_code|command)
    printf '%s|%s|%s|%s|%s\n' "${timestamp}" "${USER:-unknown}" "${event}" "${exit_code}" "${sanitized_cmd}" >> "$log_file" 2>/dev/null || true

    # Secure the log file
    chmod 600 "$log_file" 2>/dev/null || true
}

_fuck_detect_distro() {
    _fuck_load_static_cache

    # Return cached value if available
    if [[ -n "${_FUCK_CACHED_DISTRO:-}" ]]; then
        printf '%s\n' "$_FUCK_CACHED_DISTRO"
        return 0
    fi

    local kernel_name distro id version pretty family
    kernel_name=$(uname -s 2>/dev/null || printf 'unknown')
    distro="unknown"

    # macOS detection
    if [[ "$kernel_name" = "Darwin" ]]; then
        local product version
        product=$(sw_vers -productName 2>/dev/null || printf 'macOS')
        product=$(printf '%s' "$product" | tr -d '\r\n')
        version=$(sw_vers -productVersion 2>/dev/null || printf 'unknown')
        version=$(printf '%s' "$version" | tr -d '\r\n')
        distro="$product $version"
    # Linux detection using /etc/os-release
    elif [[ -r /etc/os-release ]]; then
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
        if [[ -n "$family" ]]; then
            distro="$family ${version:-}"
            if [[ -n "$pretty" ]]; then
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

_fuck_detect_pkg_manager() {
    _fuck_load_static_cache

    # Return cached value if available
    if [[ -n "${_FUCK_CACHED_PKG_MANAGER:-}" ]]; then
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

_fuck_get_architecture() {
    _fuck_load_static_cache

    # Return cached value if available
    if [[ -n "${_FUCK_CACHED_ARCH:-}" ]]; then
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

_fuck_get_kernel_version() {
    _fuck_load_static_cache

    # Return cached value if available
    if [[ -n "${_FUCK_CACHED_KERNEL:-}" ]]; then
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
                    [[ -n "$version" ]] && version="npm $version"
                    ;;
                kubectl)
                    version=$("$tool" version --client --short 2>/dev/null | head -n1)
                    ;;
            esac
        fi

        # Clean up version string
        version=$(printf '%s' "${version:-unknown}" | tr '\r\n' '  ' | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//')
        [[ -z "$version" ]] && version="unknown"

        result="$result$tool:$version; "
    done

    # Remove trailing semicolon and space
    result="${result%; }"
    printf '%s' "$result"
}

_fuck_append_config_hint() {
    local key="$1"
    local comment="$2"
    local sample="$3"
    local quoted="${4:-1}"
    [[ -f "$CONFIG_FILE" ]] || return
    if grep -Eq "^\\s*#?\\s*export\\s+$key" "$CONFIG_FILE"; then
        return
    fi

    local assignment
    if [[ "$quoted" = "1" ]]; then
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

_fuck_define_aliases() {
    local default_alias="fuck"

    if ! _fuck_truthy "${FUCK_DISABLE_DEFAULT_ALIAS:-0}"; then
        alias "$default_alias"='_fuck_execute_prompt'
    fi

    if [[ -n "${FUCK_ALIAS:-}" ]] && [[ "$FUCK_ALIAS" != "$default_alias" ]]; then
        alias "$FUCK_ALIAS"='_fuck_execute_prompt'
    fi
}

_fuck_detect_dangerous_command() {
    _fuck_security_evaluate_command "$1"
}

_fuck_local_system_prompt() {
    local sysinfo="$1"
    if [[ "$FUCKITS_LOCALE" = "zh" ]]; then
        printf '你是一个专业的 shell 命令生成器。用户会用自然语言描述他们想要完成的任务。你的任务是生成直接可执行的 shell 命令来完成用户的目标。

重要规则：
1. 用户输入是自然语言描述意图，不是命令参数。例如"列出目录"意思是执行 ls 命令，而不是 ls "列出目录"
2. 生成直接可执行的命令，不要生成带参数判断的脚本模板（如 if [[ $# -eq 0 ]）
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
2. Generate directly executable commands, not script templates with parameter handling (like if [[ $# -eq 0 ])
3. For simple tasks return single commands, complex tasks can be multi-line scripts
4. Do not provide any explanation, comments, markdown formatting (like ```bash), or a shebang (e.g., #!/bin/bash)

Examples:
- User says "list directory" → Output: ls
- User says "show detailed file list" → Output: ls -la
- User says "find files larger than 10MB" → Output: find . -type f -size +10M

The user'"'"'s system info is: %s' "$sysinfo"
    fi
}

_fuck_secure_config_file() {
    if [[ -f "$CONFIG_FILE" ]]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}

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

_fuck_security_prompt_phrase() {
    local phrase="$1"
    local input=""

    printf "%b> %b" "$C_BOLD" "$C_RESET" >&2

    if [[ -r /dev/tty ]]; then
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

_fuck_security_promote() {
    local current="$1"
    local candidate="$2"
    local current_val candidate_val

    current_val=$(_fuck_security_level_value "$current")
    candidate_val=$(_fuck_security_level_value "$candidate")

    if [[ "$candidate_val" -gt "$current_val" ]]; then
        printf '%s\n' "$candidate"
    else
        printf '%s\n' "$current"
    fi
}

_fuck_should_use_local_api() {
    if [[ -n "${FUCK_OPENAI_API_KEY:-}" ]]; then
        return 0
    fi
    return 1
}

# --- 以下为共享工具函数（从 main.sh/zh_main.sh 提取） ---

# 安全验证配置文件，防止代码注入
# 参数：$1 - 要验证的文件路径
# 返回：0 如果安全，1 如果不安全或出错
_fuck_validate_config_file() {
    local file="$1"

    # 文件必须存在且可读
    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        return 1
    fi

    # 检查文件权限 - 必须由当前用户拥有
    if [[ "$(stat -c '%u' "$file" 2>/dev/null || stat -f '%u' "$file" 2>/dev/null)" != "$(id -u)" ]]; then
        echo -e "${C_RED}Config file not owned by current user, refusing to source.${C_RESET}" >&2
        return 1
    fi

    local line_num=0
    local line

    # 预定义正则表达式变量（zsh 兼容性：变量形式避免特殊字符解析问题）
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

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # 跳过空行
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # 跳过注释行（以 # 开头，可有前导空白）
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # 检查危险的 shell 元字符和命令替换
        # 拒绝：$(), ``, $((), ;, &&, ||, | (管道), >, <, &, 换行转义
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
            echo -e "${C_RED}Unsafe config file: dangerous shell metacharacter at line $line_num${C_RESET}" >&2
            return 1
        fi

        # 只允许：export FUCK_*=... 或 FUCK_*=...（可有前导空白）
        # 也允许：export FUCKITS_LOCALE=...
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?(FUCK_[A-Z_]+|FUCKITS_LOCALE)= ]]; then
            continue
        fi

        # 拒绝其他任何内容
        _fuck_debug "Config validation failed at line $line_num: unrecognized pattern"
        echo -e "${C_RED}Unsafe config file: unrecognized pattern at line $line_num${C_RESET}" >&2
        return 1
    done < "$file"

    return 0
}

# 验证后安全地加载配置文件
# 参数：$1 - 要加载的文件路径
# 返回：0 如果成功加载，1 如果验证失败或文件不存在
_fuck_safe_source_config() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0  # 没有文件也没关系
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

# 找用户 shell 配置文件的辅助函数
_installer_detect_profile() {
    if [[ -n "${SHELL:-}" ]] && echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [[ -n "${SHELL:-}" ]] && echo "$SHELL" | grep -q "bash"; then
        echo "$HOME/.bashrc"
    elif [[ -f "$HOME/.profile" ]]; then
        # 兼容 sh, ksh 等
        echo "$HOME/.profile"
    elif [[ -f "$HOME/.zshrc" ]]; then
        # SHELL 变量没设置时的备用方案
        echo "$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        # SHELL 变量没设置时的备用方案
        echo "$HOME/.bashrc"
    else
        echo "unknown_profile"
    fi
}

# 收集用户信息包括权限级别
# 输出：用户信息字符串（如："User=john uid=1000 level=sudoer Groups=john adm sudo"）
_fuck_collect_user_info() {
    local current_user uid groups level
    current_user="${USER:-}"

    # 如果 USER 未设置则使用备用方法
    if [[ -z "$current_user" ]]; then
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
    if [[ "$uid" = "0" ]]; then
        level="root"
    elif printf '%s' "$groups" | grep -Eq '(^|[[:space:]])(sudo|wheel|admin)([[:space:]]|$)'; then
        level="sudoer"
    fi

    printf 'User=%s uid=%s level=%s Groups=%s' "$current_user" "$uid" "$level" "$groups"
}

# 从 JSON 文件中提取命令内容
# 参数：$1 - JSON 文件路径
# 返回：命令内容到 stdout
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

    echo -e "${C_RED}Cannot parse AI response: neither python3 nor node is available.${C_RESET}" >&2
    return 1
}

# Spinner 加载动画
# 参数：$1 - 进程 PID，$2 - 可选的前缀文本
_fuck_spinner() {
    local pid=$1
    local prefix="${2:-}"
    local delay=0.1
    local -a frames=("|" "/" "-" "\\")
    local frame_count=${#frames[@]}
    local frame_idx=0
    local has_prefix=0
    if [[ -n "$prefix" ]]; then
        has_prefix=1
    fi

    # 仅在 stderr 是终端时操作光标
    if [[ -t 2 ]]; then
        tput civis 2>/dev/null || printf "\033[?25l" >&2
    fi

    while kill -0 "$pid" 2>/dev/null; do
        if [[ "$has_prefix" -eq 1 ]]; then
            printf "\r%s%s" "$prefix" "${frames[$frame_idx]}"
        else
            printf " %s " "${frames[$frame_idx]}"
            printf "\b\b\b"
        fi
        frame_idx=$(( (frame_idx + 1) % frame_count ))
        sleep "$delay"
    done

    if [[ "$has_prefix" -eq 1 ]]; then
        printf "\r%s" "$prefix"
        tput el 2>/dev/null || printf "\033[K"
    else
        printf "   \b\b\b"
    fi

    if [[ -t 2 ]]; then
        tput cnorm 2>/dev/null || printf "\033[?25h" >&2
    fi
}

# 初始化历史文件
# 参数：$1 - 历史文件路径（可选，默认 $INSTALL_DIR/history.json）
_fuck_init_history_file() {
    local history_file="${1:-$INSTALL_DIR/history.json}"

    if [[ ! -f "$history_file" ]]; then
        cat > "$history_file" <<'HISTORY_EOF'
{
  "version": "1.0.0",
  "commands": [],
  "favorites": []
}
HISTORY_EOF
        chmod 600 "$history_file"
    fi
}

# 记录命令执行到历史
# 参数：$1 - 提示词，$2 - 命令，$3 - 退出码（可选），$4 - 耗时（可选）
_fuck_log_history() {
    local prompt="$1"
    local command="$2"
    local exit_code="${3:-0}"
    local duration="${4:-0}"

    local history_file="$INSTALL_DIR/history.json"

    # 检查 jq 是否可用
    if ! command -v jq &> /dev/null; then
        return 1
    fi

    # 初始化历史文件
    _fuck_init_history_file "$history_file"

    # 生成唯一 ID
    local cmd_id="cmd_$(date +%s)_$$"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "unknown")

    # 创建条目
    local entry
    entry=$(jq -n \
        --arg id "$cmd_id" \
        --arg timestamp "$timestamp" \
        --arg prompt "$prompt" \
        --arg command "$command" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        '{
            id: $id,
            timestamp: $timestamp,
            prompt: $prompt,
            command: $command,
            exitCode: $exit_code,
            duration: $duration
        }' 2>/dev/null)

    if [[ -z "$entry" ]]; then
        return 1
    fi

    # 追加到历史并限制为 1000 条（避免竞态条件）
    local temp_file="${history_file}.tmp"
    if jq ".commands += [$entry] | .commands |= .[-1000:]" "$history_file" > "$temp_file" 2>/dev/null; then
        command mv -f -- "$temp_file" "$history_file"
        chmod 600 "$history_file"
    else
        rm -f "$temp_file"
    fi
}

# --- 内联运行时共享函数结束 ---

_fuck_validate_config_file() {
    local file="$1"
    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        return 1
    fi
    if [[ "$(stat -c '%u' "$file" 2>/dev/null || stat -f '%u' "$file" 2>/dev/null)" != "$(id -u)" ]]; then
        echo -e "${C_RED}Config file not owned by current user, refusing to source.${C_RESET}" >&2
        return 1
    fi
    local line_num=0
    local line
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
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
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
            echo -e "${C_RED}Unsafe config file: dangerous shell metacharacter at line $line_num${C_RESET}" >&2
            return 1
        fi
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?(FUCK_[A-Z_]+|FUCKITS_LOCALE)= ]]; then
            continue
        fi
        echo -e "${C_RED}Unsafe config file: unrecognized pattern at line $line_num${C_RESET}" >&2
        return 1
    done < "$file"
    return 0
}

_fuck_safe_source_config() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
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

# --- 加载用户配置（带验证）---
_fuck_safe_source_config "$CONFIG_FILE"

# --- 系统信息收集 ---
# Cache file for static system information (persisted across runs)
# Only define if not already set (prevents read-only variable errors)
if [[ -z "${FUCK_SYSINFO_CACHE_FILE:-}" ]]; then
    readonly FUCK_SYSINFO_CACHE_FILE="$INSTALL_DIR/.sysinfo.cache"
fi
# Cache state tracking variables
_FUCK_STATIC_CACHE_LOADED=0
_FUCK_STATIC_CACHE_DIRTY=0

# Loads static system information from cache file
# Globals: _FUCK_STATIC_CACHE_LOADED, FUCK_SYSINFO_CACHE_FILE

# Marks static cache as dirty (needs to be persisted)
# Globals: _FUCK_STATIC_CACHE_DIRTY

# Persists static system information to cache file
# Globals: _FUCK_STATIC_CACHE_DIRTY, FUCK_SYSINFO_CACHE_FILE
# Returns: 0 on success, 1 on failure

# Detects the distribution/OS family with caching support
# Outputs: Distribution string (e.g., "Debian-based 12.04 (Ubuntu 24.04 LTS)")

# Gets kernel version information with caching
# Outputs: Kernel version string (e.g., "Linux 6.8.0-31-generic")

# Gets system architecture with caching
# Outputs: Architecture string (e.g., "x86_64", "arm64")

# Collects simplified system information as a structured string
# Outputs: System info string for AI processing
# Reuses cached _fuck_detect_distro and _fuck_detect_pkg_manager to avoid redundant detection
_fuck_collect_sysinfo_string() {
    local os_type pkg_manager

    # Use cached detection functions instead of duplicating OS detection logic
    local distro
    distro=$(_fuck_detect_distro 2>/dev/null)

    local kernel_name
    kernel_name=$(uname -s 2>/dev/null || printf 'unknown')

    case "$kernel_name" in
        Darwin)     os_type="macOS" ;;
        Linux)      os_type="${distro:-Linux}" ;;
        MINGW*|MSYS*|CYGWIN*) os_type="Windows" ;;
        *)          os_type="$kernel_name" ;;
    esac

    pkg_manager=$(_fuck_detect_pkg_manager 2>/dev/null)

    # Persist cache if new data was collected
    _fuck_persist_static_cache 2>/dev/null || true

    printf 'OS=%s; PkgMgr=%s\n' "$os_type" "$pkg_manager"
}

_fuck_request_local_model() {
    local prompt="$1"
    local sysinfo="$2"
    local curl_timeout="$3"

    local api_key="${FUCK_OPENAI_API_KEY:-}"
    if [[ -z "$api_key" ]]; then
        local msg_api_key
        msg_api_key=$(_i18n_get "msg.error.api_key_not_set")
        echo -e "$FUCK ${C_RED}${msg_api_key}${C_RESET}" >&2
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
    if [[ -n "$admin_key" ]]; then
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

    if [[ -t 2 ]]; then
        _fuck_spinner "$pid" "$spinner_label" >&2
    fi

    local curl_exit=0
    if ! wait "$pid"; then
        curl_exit=$?
    fi

    local http_status=""
    if [[ -f "$tmp_status" ]]; then
        http_status=$(tr -d '\r\n' < "$tmp_status")
        rm -f "$tmp_status"
    fi

    local response=""
    if [[ -f "$tmp_response" ]]; then
        response=$(cat "$tmp_response")
        rm -f "$tmp_response"
    fi

    if [[ $curl_exit -ne 0 ]]; then
        echo -e "$FUCK ${C_RED}Failed to reach the shared Worker.${C_RESET}" >&2
        if [[ -n "$response" ]]; then
            echo -e "${C_DIM}$response${C_RESET}" >&2
        fi
        return $curl_exit
    fi

    if [[ -z "$http_status" ]]; then
        http_status=0
    fi

    if [[ "$http_status" -eq 429 ]] && printf '%s' "$response" | grep -q 'DEMO_LIMIT_EXCEEDED'; then
        local limit
        limit=$(printf '%s' "$response" | sed -n 's/.*"limit":[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)
        local remaining
        remaining=$(printf '%s' "$response" | sed -n 's/.*"remaining":[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)
        [ -z "$limit" ]] && limit=10
        _fuck_notify_demo_limit "$limit" "$remaining"
        return 2
    fi

    if [[ "$http_status" -ge 400 ]] || [[ -z "$response" ]]; then
        echo -e "$FUCK ${C_RED}Shared Worker returned HTTP $http_status.${C_RESET}" >&2
        if [[ -n "$response" ]]; then
            echo -e "${C_DIM}$response${C_RESET}" >&2
        fi
        return 1
    fi

    printf '%s\n' "$response"
}

# Pollinations OAuth Device Flow
# 实现 RFC 8628 Device Authorization Grant
_POLLINATIONS_CLIENT_ID="${FUCK_POLLINATIONS_CLIENT_ID:-pk_1lgmLD1Fsk9N6ftr}"
_POLLINATIONS_DEVICE_API="https://enter.pollinations.ai/api/device"

_fuck_pollinations_device_flow() {
    local client_id="${_POLLINATIONS_CLIENT_ID}"

    # Step 1: 请求设备码
    local code_response
    local code_payload
    if [[ -n "$client_id" ]]; then
        code_payload=$(printf '{"client_id":"%s","scope":"generate"}' "$client_id")
    else
        code_payload='{"scope":"generate"}'
    fi

    code_response=$(curl -sS --max-time 10 \
        -X POST "${_POLLINATIONS_DEVICE_API}/code" \
        -H "Content-Type: application/json" \
        -d "$code_payload" 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$code_response" ]]; then
        echo -e "$FUCK ${C_RED}Failed to connect to Pollinations auth service.${C_RESET}" >&2
        return 1
    fi

    # 解析响应（不依赖 jq，使用 sed/grep）
    local device_code user_code verification_uri
    device_code=$(printf '%s' "$code_response" | grep -o '"device_code"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"device_code"[[:space:]]*:[[:space:]]*"//;s/"$//')
    user_code=$(printf '%s' "$code_response" | grep -o '"user_code"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"user_code"[[:space:]]*:[[:space:]]*"//;s/"$//')
    verification_uri=$(printf '%s' "$code_response" | grep -o '"verification_uri"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"verification_uri"[[:space:]]*:[[:space:]]*"//;s/"$//')

    if [[ -z "$device_code" ]] || [[ -z "$user_code" ]] || [[ -z "$verification_uri" ]]; then
        echo -e "$FUCK ${C_RED}Invalid response from Pollinations auth service.${C_RESET}" >&2
        echo -e "${C_DIM}$code_response${C_RESET}" >&2
        return 1
    fi

    # Step 2: 显示授权指引
    echo ""
    echo -e "${C_BOLD}Pollinations OAuth Authorization${C_RESET}"
    echo -e "${C_DIM}────────────────────────────────────────${C_RESET}"
    echo -e "1. Open in browser: ${C_CYAN}${verification_uri}${C_RESET}"
    echo -e "2. Enter code: ${C_GREEN}${C_BOLD}${user_code}${C_RESET}"
    echo -e "${C_DIM}────────────────────────────────────────${C_RESET}"
    echo -e "${C_DIM}Waiting for authorization... (up to 5 minutes)${C_RESET}"
    echo ""

    # Step 3: 轮询等待授权
    local max_attempts=60
    local attempt=0
    local poll_interval=5
    local token_response access_token

    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt + 1))
        sleep "$poll_interval"

        token_response=$(curl -sS --max-time 10 \
            -X POST "${_POLLINATIONS_DEVICE_API}/token" \
            -H "Content-Type: application/json" \
            -d "{\"device_code\":\"${device_code}\"}" 2>/dev/null)

        if [[ $? -ne 0 ]]; then
            echo -e "${C_YELLOW}Connection lost, retrying... ($attempt/$max_attempts)${C_RESET}" >&2
            continue
        fi

        # 检查是否授权成功
        if printf '%s' "$token_response" | grep -q '"access_token"'; then
            access_token=$(printf '%s' "$token_response" | grep -o '"access_token"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"access_token"[[:space:]]*:[[:space:]]*"//;s/"$//')

            if [[ -n "$access_token" ]]; then
                echo -e "${C_GREEN}✅ Authorization successful!${C_RESET}"
                echo ""
                # 保存凭据
                _fuck_pollinations_save_credentials "$access_token"
                return 0
            fi
        fi

        # 检查是否仍在等待
        if printf '%s' "$token_response" | grep -q 'authorization_pending'; then
            # 显示进度
            printf "\r${C_DIM}Waiting for authorization... (%d/%d)${C_RESET}" "$attempt" "$max_attempts" >&2
            continue
        fi

        # 检查是否被拒绝
        if printf '%s' "$token_response" | grep -q 'access_denied'; then
            echo "" >&2
            echo -e "${C_RED}❌ Authorization denied.${C_RESET}" >&2
            return 1
        fi

        # 检查是否过期
        if printf '%s' "$token_response" | grep -q 'expired'; then
            echo "" >&2
            echo -e "${C_RED}❌ Code expired, run fuck --oauth again${C_RESET}" >&2
            return 1
        fi

        # 其他错误
        echo "" >&2
        echo -e "${C_YELLOW}⚠️ Unknown response: $token_response${C_RESET}" >&2
        return 1
    done

    echo "" >&2
    echo -e "${C_RED}❌ Authorization timed out (5 min), run fuck --oauth again${C_RESET}" >&2
    return 1
}

# 保存 Pollinations 凭据到配置文件
_fuck_pollinations_save_credentials() {
    local access_token="$1"

    _fuck_ensure_config_exists

    # 移除旧的 Pollinations 配置（如果有）
    if [[ -f "$CONFIG_FILE" ]]; then
        # 使用临时文件安全地移除旧配置行
        local tmp_config
        tmp_config=$(mktemp) || return 1
        grep -v "^export FUCK_OPENAI_API_KEY=" "$CONFIG_FILE" | \
        grep -v "^export FUCK_OPENAI_API_BASE=" | \
        grep -v "^export FUCK_OPENAI_MODEL=" | \
        grep -v "^# Pollinations OAuth" > "$tmp_config" 2>/dev/null || true
        mv "$tmp_config" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi

    # 写入新配置
    {
        printf '\n# Pollinations OAuth (auto-configured by fuck --oauth)\n'
        printf 'export FUCK_OPENAI_API_KEY="%s"\n' "$access_token"
        printf 'export FUCK_OPENAI_API_BASE="https://gen.pollinations.ai/v1"\n'
        printf 'export FUCK_OPENAI_MODEL="openai"\n'
    } >> "$CONFIG_FILE"

    # 重新加载配置
    export FUCK_OPENAI_API_KEY="$access_token"
    export FUCK_OPENAI_API_BASE="https://gen.pollinations.ai/v1"
    export FUCK_OPENAI_MODEL="openai"

    echo -e "${C_GREEN}✅ Credentials saved to $CONFIG_FILE${C_RESET}"
    echo -e "${C_DIM}Use 'fuck --oauth status' to check auth status${C_RESET}"
}

# 查看 Pollinations OAuth 状态
_fuck_pollinations_status() {
    local api_key="${FUCK_OPENAI_API_KEY:-}"
    local api_base="${FUCK_OPENAI_API_BASE:-}"

    if [[ -z "$api_key" ]]; then
        echo -e "${C_YELLOW}No API Key configured${C_RESET}"
        echo -e "Run ${C_CYAN}fuck --oauth${C_RESET} to authorize"
        return 1
    fi

    echo -e "${C_BOLD}Pollinations OAuth Status${C_RESET}"
    echo -e "${C_DIM}────────────────────────────────────────${C_RESET}"

    # 检查是否是 Pollinations key
    if [[ "$api_key" == sk_* ]] && [[ "$api_base" == *"pollinations.ai"* ]]; then
        echo -e "Auth method: ${C_GREEN}Pollinations OAuth${C_RESET}"
        echo -e "API Base: ${C_CYAN}$api_base${C_RESET}"
        echo -e "Key 前缀: ${C_DIM}${api_key:0:6}...${C_RESET}"

        # 验证 key 有效性
        echo -e "\n${C_DIM}Validating key...${C_RESET}"
        local profile_response
        profile_response=$(curl -sS --max-time 10 \
            "https://gen.pollinations.ai/account/profile" \
            -H "Authorization: Bearer $api_key" 2>/dev/null)

        if [[ $? -eq 0 ]] && printf '%s' "$profile_response" | grep -q 'githubUsername'; then
            local username tier
            username=$(printf '%s' "$profile_response" | grep -o '"githubUsername"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"githubUsername"[[:space:]]*:[[:space:]]*"//;s/"$//')
            tier=$(printf '%s' "$profile_response" | grep -o '"tier"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"tier"[[:space:]]*:[[:space:]]*"//;s/"$//')
            echo -e "GitHub user: ${C_GREEN}${username:-unknown}${C_RESET}"
            echo -e "Tier: ${C_CYAN}${tier:-unknown}${C_RESET}"
        else
            echo -e "${C_YELLOW}⚠️ Unable to validate key (network issue or key expired)${C_RESET}"
        fi
    elif [[ -n "$api_key" ]]; then
        echo -e "Auth method: ${C_CYAN}Local API Key${C_RESET}"
        echo -e "API Base: ${C_CYAN}${api_base:-https://api.openai.com/v1}${C_RESET}"
        echo -e "Key 前缀: ${C_DIM}${api_key:0:6}...${C_RESET}"
    fi

    echo -e "${C_DIM}────────────────────────────────────────${C_RESET}"
}

# 清除 Pollinations OAuth 凭据
_fuck_pollinations_logout() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${C_YELLOW}Config file not found${C_RESET}"
        return 0
    fi

    # 检查是否是 Pollinations 配置
    local api_base="${FUCK_OPENAI_API_BASE:-}"
    if [[ "$api_base" != *"pollinations.ai"* ]]; then
        echo -e "${C_YELLOW}Not using Pollinations OAuth${C_RESET}"
        return 0
    fi

    # 移除 Pollinations 相关配置
    local tmp_config
    tmp_config=$(mktemp) || return 1
    grep -v "^export FUCK_OPENAI_API_KEY=" "$CONFIG_FILE" | \
    grep -v "^export FUCK_OPENAI_API_BASE=" | \
    grep -v "^export FUCK_OPENAI_MODEL=" | \
    grep -v "^# Pollinations OAuth" > "$tmp_config" 2>/dev/null || true
    mv "$tmp_config" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    # 清除环境变量
    unset FUCK_OPENAI_API_KEY
    unset FUCK_OPENAI_API_BASE
    unset FUCK_OPENAI_MODEL

    echo -e "${C_GREEN}✅ Pollinations OAuth credentials cleared${C_RESET}"
}

_fuck_notify_demo_limit() {
    local daily_limit="${1:-10}"
    local remaining="${2:-0}"

    echo -e "$FUCK ${C_YELLOW}Shared demo quota exhausted (${daily_limit} calls per day).${C_RESET}" >&2
    case "$remaining" in
        ''|*[!0-9]*) ;;
        *)
            if [[ "$remaining" -gt 0 ]]; then
                echo -e "${C_DIM}$remaining calls left for today.${C_RESET}" >&2
            fi
            ;;
    esac

    _fuck_ensure_config_exists
    _fuck_secure_config_file

    echo -e "${C_CYAN}Switch to your own key:${C_RESET} run ${C_GREEN}fuck --config${C_RESET} and set ${C_BOLD}FUCK_OPENAI_API_KEY${C_RESET} (plus optional ${C_BOLD}FUCK_OPENAI_MODEL${C_RESET}/${C_BOLD}FUCK_OPENAI_API_BASE${C_RESET})." >&2
    echo -e "${C_CYAN}Trusted maintainer override:${C_RESET} set ${C_BOLD}FUCK_ADMIN_KEY${C_RESET} if you were issued the worker's ADMIN_ACCESS_KEY to bypass the shared quota." >&2
    echo -e "${C_CYAN}Config path:${C_RESET} ${C_GREEN}$CONFIG_FILE${C_RESET}" >&2
    if [[ -n "${EDITOR:-}" ]]; then
        echo -e "${C_YELLOW}Hint:${C_RESET} ${EDITOR} \"$CONFIG_FILE\"" >&2
    fi
    echo -e "${C_DIM}Security:${C_RESET} the file permissions are locked to 600 so the key stays local." >&2
}

# Simple helper to parse boolean-like values

# Debug helper
_fuck_debug() {
    if _fuck_truthy "${FUCK_DEBUG:-0}"; then
        echo -e "${C_DIM}[debug] $*${C_RESET}" >&2
    fi
}

# Detects potentially dangerous commands and prints a warning
# --- 安全检测引擎（第二阶段）---

# Block-level security rules (highest severity - execution denied)
# Format: 'pattern|||reason'
# Note: Not using 'readonly' to ensure compatibility with function-scoped sourcing
if [[ -z "${_FUCK_SECURITY_BLOCK_RULES+x}" ]] || [[ ${#_FUCK_SECURITY_BLOCK_RULES[@]} -eq 0 ]] 2>/dev/null; then
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
if [[ -z "${_FUCK_SECURITY_CHALLENGE_RULES+x}" ]] || [[ ${#_FUCK_SECURITY_CHALLENGE_RULES[@]} -eq 0 ]] 2>/dev/null; then
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
if [[ -z "${_FUCK_SECURITY_WARN_RULES+x}" ]] || [[ ${#_FUCK_SECURITY_WARN_RULES[@]} -eq 0 ]] 2>/dev/null; then
    _FUCK_SECURITY_WARN_RULES=(
        'sudo[[:space:]]+[^;&|]*rm[[:space:]]+-rf|||sudo rm -rf detected'
        'rm[[:space:]]+-rf\b|||Recursive delete request detected'
        'chmod[[:space:]]+.*777\b|||World-writable permission change detected'
        '>[[:space:]]*/(etc/(passwd|shadow|sudoers)|dev/sd[a-z]+)|||Output redirection into sensitive system files'
    )
fi

# Gets the current security mode from configuration
# Outputs: "strict", "balanced", or "off"

# Gets the default challenge text for security confirmations
# Outputs: Default challenge phrase
_fuck_security_default_challenge_text() {
    printf 'I accept the risk'
}

# Checks if a command matches the security whitelist
# 使用前缀匹配而非子串匹配，避免白名单条目意外匹配不相关命令
# Arguments: $1 - command to check
# Returns: 0 if whitelisted, 1 otherwise

# Converts security level to numeric value for comparison
# Arguments: $1 - security level (block/challenge/warn/ok)
# Outputs: Numeric value (3/2/1/0)

# Promotes security level if candidate is more severe
# Arguments: $1 - current level, $2 - candidate level
# Outputs: The more severe level

# Applies security mode adjustments to severity level
# Arguments: $1 - mode (strict/balanced/off), $2 - severity level
# Outputs: Adjusted severity level

# Matches command against a security rule table
# Arguments: $1 - command, $2 - rule table name
# Outputs: Reason string if matched
# Returns: 0 if matched, 1 otherwise

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
            _fuck_audit_log "BLOCK" "$command"
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
    if [[ "$mode" = "off" ]]; then
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
    if [[ "$severity" != "block" ]] && match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_CHALLENGE_RULES"); then
        severity="challenge"
        reason="$match"
    fi

    # Check warn rules (low priority)
    if [[ "$severity" = "ok" ]] && match=$(_fuck_security_match_rule "$command" "_FUCK_SECURITY_WARN_RULES"); then
        severity="warn"
        reason="$match"
    fi

    # Check for command chaining/piping (structural analysis)
    if printf '%s' "$command" | grep -Eiq '(&&|\|\||;|\|)'; then
        structural_reason="Command chaining or piping detected"
        promoted=$(_fuck_security_promote "$severity" "warn")

        if [[ "$promoted" != "$severity" ]]; then
            severity="$promoted"
            reason="$structural_reason"
        elif [[ -z "$reason" ]]; then
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


# Ensure a config file exists to help users tweak the behaviour


_fuck_seed_config_placeholders() {
    [[ -f "$CONFIG_FILE" ]] || return
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
    _fuck_append_config_hint "FUCK_POLLINATIONS_CLIENT_ID" "Optional: Pollinations App Key for OAuth (pk_...)" ''
}

_fuck_ensure_config_exists() {
    if [[ -f "$CONFIG_FILE" ]]; then
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

# Pollinations OAuth (use 'fuck --oauth' to authorize)
# export FUCK_POLLINATIONS_CLIENT_ID="pk_..."

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

# --- Security Settings ---
# Security mode: strict, balanced (default), or off
# export FUCK_SECURITY_MODE="balanced"

# Whitelist trusted command patterns (comma-separated)
# export FUCK_SECURITY_WHITELIST="docker rm -f,rm -rf /tmp/safe-dir"

# --- Audit Logging ---
# Enable audit logging of all executed commands
# export FUCK_AUDIT_LOG=true

# Custom audit log file path (default: ~/.fuck/.audit.log)
# export FUCK_AUDIT_LOG_FILE="$HOME/.fuck/.audit.log"
CFG

    _fuck_seed_config_placeholders
    _fuck_secure_config_file
}

_fuck_show_config_help() {
    _fuck_ensure_config_exists
    echo -e "${C_YELLOW}Configuration file:${C_RESET} ${C_CYAN}$CONFIG_FILE${C_RESET}"
    if [[ -n "${EDITOR:-}" ]]; then
        echo -e "${C_YELLOW}Edit with:${C_RESET} ${C_CYAN}${EDITOR} \"$CONFIG_FILE\"${C_RESET}"
    else
        echo -e "${C_YELLOW}Open this file in your favourite editor to customise fuckits.${C_RESET}"
    fi
    echo -e "${C_CYAN}Available toggles:${C_RESET} FUCK_API_ENDPOINT, FUCK_OPENAI_API_KEY, FUCK_ADMIN_KEY, FUCK_OPENAI_MODEL, FUCK_OPENAI_API_BASE, FUCK_ALIAS, FUCK_AUTO_EXEC, FUCK_TIMEOUT, FUCK_DEBUG, FUCK_DISABLE_DEFAULT_ALIAS"
    echo -e "${C_DIM}Pro tip:${C_RESET} we lock ${CONFIG_FILE} to chmod 600 so your API key stays local."
}

# 显示帮助信息，列出所有可用子命令
_fuck_show_help() {
    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        printf '{"status":"ok","schema_version":1,"version":"%s","commands":[{"name":"--help","description":"Show this help message"},{"name":"--config","description":"Show configuration help"},{"name":"--version","description":"Show current version"},{"name":"--history","description":"View command history"},{"name":"--history search <keyword>","description":"Search command history"},{"name":"--history replay <index>","description":"Replay a history command"},{"name":"--favorite add <name> <prompt>","description":"Add a favorite command"},{"name":"--favorite list","description":"List all favorites"},{"name":"--favorite run <index>","description":"Execute a favorite command"},{"name":"--favorite delete <index>","description":"Delete a favorite"},{"name":"--update","description":"Update fuckits to the latest version"},{"name":"--uninstall","description":"Uninstall fuckits"},{"name":"--oauth","description":"Pollinations OAuth login/status/logout"}]}\n'
    else
        local msg_title
        msg_title=$(_i18n_get "msg.help.title")
        echo -e "${C_BOLD}fuckits${C_RESET} ${C_DIM}v${SCRIPT_VERSION}${C_RESET} — ${msg_title}"
        echo ""
        echo -e "${C_YELLOW}Usage:${C_RESET} fuck <your prompt>"
        echo ""
        echo -e "${C_CYAN}Commands:${C_RESET} (use -- prefix)"
        echo -e "  ${C_BOLD}--help${C_RESET}                       Show this help message"
        echo -e "  ${C_BOLD}--config${C_RESET}                     Show configuration help"
        echo -e "  ${C_BOLD}--version${C_RESET}                    Show current version"
        echo -e "  ${C_BOLD}--history${C_RESET}                    View recent command history"
        echo -e "  ${C_BOLD}--history search <keyword>${C_RESET}   Search command history"
        echo -e "  ${C_BOLD}--history replay <index>${C_RESET}     Replay a history command"
        echo -e "  ${C_BOLD}--favorite${C_RESET} (fav)             Manage favorite commands"
        echo -e "  ${C_BOLD}--update${C_RESET}                     Update fuckits to the latest version"
        echo -e "  ${C_BOLD}--uninstall${C_RESET}                  Uninstall fuckits"
        echo -e "  ${C_BOLD}--oauth${C_RESET} (auth)               Pollinations OAuth authorization"
        echo ""
        echo -e "${C_DIM}Options:${C_RESET}"
        echo -e "  ${C_BOLD}--json${C_RESET}                     Output in JSON format"
        echo ""
        echo -e "${C_DIM}Examples:${C_RESET}"
        echo -e "  fuck find all files larger than 10MB"
        echo -e "  fuck install git"
        echo -e "  fuck --config"
    fi
}

# 从脚本文件中提取版本号
# Arguments: $1=脚本文件路径
# Outputs: 版本号字符串
_fuck_get_script_version() {
    local file="$1"
    grep -o "SCRIPT_VERSION='[^']*'" "$file" 2>/dev/null | head -1 | sed "s/SCRIPT_VERSION='//;s/'//" | tr -cd '0-9a-zA-Z._-'
}

# 写入核心逻辑到文件（安装脚本内部版本，供 _fuck_update_script 使用）
# 注意：安装后此函数存在于 ~/.fuck/main.sh 中
_fuck_write_core() {
    local target="$1"
    if [[ -n "${CORE_LOGIC:-}" ]]; then
        printf '%s\n' "$CORE_LOGIC" > "$target"
    elif [[ "$target" == "${MAIN_SH:-}" ]] && [[ -r "${BASH_SOURCE[0]:-}" ]]; then
        # 本地直接运行生成脚本安装时，CORE_LOGIC 不存在，复制当前脚本自身。
        cp "${BASH_SOURCE[0]}" "$target"
    else
        # 安装上下文中 CORE_LOGIC 不可用，从 API 获取
        local api_url="${FUCK_API_ENDPOINT:-${DEFAULT_API_ENDPOINT:-https://fuckits.25500552.xyz/}}"
        curl -sS --max-time 10 "${api_url%/}" > "$target" 2>/dev/null
    fi
    if grep -q '2.2.0' "$target" 2>/dev/null; then
        local _pkg
        for _pkg in "$(dirname "$target")/../../package.json" "${_FC_SCRIPT_DIR:-}/../../package.json"; do
            if [[ -f "$_pkg" ]] && command -v node > /dev/null 2>&1; then
                local _ver
                _ver=$(node -e "console.log(require('$_pkg').version)" 2>/dev/null) || true
                if [[ -n "$_ver" ]]; then
                    sed -i.bak "s/2.2.0/${_ver}/g" "$target" && rm -f "${target}.bak"
                    break
                fi
            fi
        done
    fi
}

# 自更新：检查远程版本并更新本地安装
# 仅在已安装模式下可用
_fuck_update_script() {
    # 检查是否已安装（非临时模式）
    if [[ ! -f "$MAIN_SH" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"error","schema_version":1,"code":"NOT_INSTALLED","message":"fuckits is not installed. Run the installer first."}\n'
        else
            echo -e "${C_RED}❌ fuckits is not installed. Run the installer first.${C_RESET}" >&2
        fi
        return 1
    fi

    local api_url="${FUCK_API_ENDPOINT:-${DEFAULT_API_ENDPOINT:-https://fuckits.25500552.xyz/}}"
    local health_url="${api_url%/}/health"

    # 获取远程版本
    local remote_version
    remote_version=$(curl -sS --fail --max-time 5 "$health_url" 2>/dev/null | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"version"[[:space:]]*:[[:space:]]*"//;s/"$//' | tr -cd '0-9a-zA-Z._-') || true

    if [[ -z "$remote_version" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"error","schema_version":1,"code":"CHECK_FAILED","message":"Failed to check remote version"}\n'
        else
            echo -e "${C_RED}❌ Failed to check remote version. Check your network connection.${C_RESET}" >&2
        fi
        return 1
    fi

    # 获取本地版本
    local local_ver
    local_ver=$(_fuck_get_script_version "$MAIN_SH") || true

    # 版本对比
    if [[ "$local_ver" = "$remote_version" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","schema_version":1,"message":"Already up to date","version":"%s"}\n' "$local_ver"
        else
            echo -e "${C_GREEN}✅ Version ${local_ver} is up to date.${C_RESET}"
        fi
        return 0
    fi

    # 执行更新
    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        # 原子性替换：先写临时文件，验证后再替换
        local tmp_update
        tmp_update=$(mktemp) || { echo -e "${C_RED}❌ Failed to create temporary file.${C_RESET}" >&2; return 1; }
        _fuck_write_core "$tmp_update"
        chmod +x "$tmp_update"
        local new_ver
        new_ver=$(_fuck_get_script_version "$tmp_update") || true
        if [[ -n "$new_ver" ]] && [[ "$new_ver" = "$remote_version" ]]; then
            if mv -f "$tmp_update" "$MAIN_SH"; then
                printf '{"status":"ok","schema_version":1,"message":"Updated successfully","from":"%s","to":"%s"}\n' "$local_ver" "$new_ver"
            else
                rm -f "$tmp_update"
                printf '{"status":"error","schema_version":1,"code":"UPDATE_FAILED","message":"Failed to replace script file"}\n'
            fi
        else
            rm -f "$tmp_update"
            printf '{"status":"error","schema_version":1,"code":"UPDATE_FAILED","message":"Version mismatch after update: got %s, expected %s"}\n' "$new_ver" "$remote_version"
        fi
    else
        echo -e "${C_YELLOW}📦 Local: ${C_BOLD}${local_ver}${C_RESET}${C_YELLOW} → Remote: ${C_BOLD}${remote_version}${C_RESET}"
        echo -e "${C_CYAN}Updating...${C_RESET}"

        # 原子性替换：先写临时文件，验证后再替换
        local tmp_update
        tmp_update=$(mktemp) || { echo -e "${C_RED}❌ Failed to create temporary file.${C_RESET}" >&2; return 1; }
        _fuck_write_core "$tmp_update"
        chmod +x "$tmp_update"

        local new_ver
        new_ver=$(_fuck_get_script_version "$tmp_update") || true
        if [[ -n "$new_ver" ]] && [[ "$new_ver" = "$remote_version" ]]; then
            if mv -f "$tmp_update" "$MAIN_SH"; then
                echo -e "${C_GREEN}✅ Updated to version ${new_ver}.${C_RESET}"
                # 重新加载脚本以恢复 alias 和函数定义
                source "$MAIN_SH" 2>/dev/null
                echo -e "${C_GREEN}🔄 Auto-reloaded. fuck command is ready.${C_RESET}"
            else
                rm -f "$tmp_update"
                echo -e "${C_RED}❌ Failed to replace script file. The update was not applied.${C_RESET}" >&2
            fi
        else
            rm -f "$tmp_update"
            echo -e "${C_YELLOW}⚠️ Installed version ${new_ver}, expected ${remote_version}. Try running the installer:${C_RESET}"
            echo -e "${C_CYAN}  curl -sS ${api_url} | bash${C_RESET}"
        fi
    fi
}

# Check if jq is available
_fuck_check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${C_RED}❌ 'jq' is required for history functionality but not found.${C_RESET}" >&2
        echo -e "${C_YELLOW}Install it with:${C_RESET}" >&2
        echo -e "  ${C_CYAN}# macOS${C_RESET}" >&2
        echo -e "  ${C_DIM}brew install jq${C_RESET}" >&2
        echo -e "  ${C_CYAN}# Ubuntu/Debian${C_RESET}" >&2
        echo -e "  ${C_DIM}sudo apt-get install jq${C_RESET}" >&2
        echo -e "  ${C_CYAN}# CentOS/RHEL${C_RESET}" >&2
        echo -e "  ${C_DIM}sudo yum install jq${C_RESET}" >&2
        return 1
    fi
    return 0
}

# View command history
_fuck_history() {
    local count="${1:-20}"
    local history_file="$INSTALL_DIR/history.json"

    if ! _fuck_check_jq; then
        return 1
    fi

    # Validate count is a positive integer
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -le 0 ]]; then
        echo -e "${C_RED}❌ Invalid count: must be a positive integer.${C_RESET}" >&2
        return 1
    fi

    if [[ ! -f "$history_file" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","schema_version":1,"version":"1.0.0","total":0,"commands":[]}\n'
        else
            echo -e "${C_YELLOW}📜 No command history yet.${C_RESET}"
            echo -e "${C_DIM}Commands will be logged automatically as you use 'fuck'.${C_RESET}"
        fi
        return 0
    fi

    local total_count
    total_count=$(jq '.commands | length' "$history_file" 2>/dev/null || echo "0")

    if [[ "$total_count" -eq 0 ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","schema_version":1,"version":"1.0.0","total":0,"commands":[]}\n'
        else
            echo -e "${C_YELLOW}📜 No command history yet.${C_RESET}"
        fi
        return 0
    fi

    # JSON 模式：输出结构化 JSON
    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        jq -n --argjson count "$count" --slurpfile data "$history_file" \
            '{status: "ok", schema_version: 1, version: $data[0].version, total: ($data[0].commands | length), count: $count, commands: ($data[0].commands | reverse | .[0:$count])}' \
            2>/dev/null || printf '{"status":"error","schema_version":1,"code":"HISTORY_PARSE_FAILED","message":"Failed to parse history file"}\n'
        return 0
    fi

    echo -e "${C_CYAN}📜 Last $count commands:${C_RESET}"
    echo ""

    # Output plain text from jq, add colors in bash to avoid jq escape issues
    # Use --argjson to safely pass numeric parameter
    jq -r --argjson count "$count" '.commands[-$count:] | reverse | to_entries[] |
        "[\(.key + 1)] \(.value.timestamp[0:19]) | \(.value.prompt) → \(.value.command)"' \
        "$history_file" 2>/dev/null | while IFS= read -r line; do
        echo -e "${C_DIM}${line}${C_RESET}"
    done

    echo ""
    echo -e "${C_DIM}Total: $total_count commands${C_RESET}"
    echo -e "${C_DIM}Tip: Use 'fuck --history search <keyword>' to search${C_RESET}"
}

# Search command history
_fuck_history_search() {
    local keyword="$1"
    local history_file="$INSTALL_DIR/history.json"

    if [[ -z "$keyword" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"error","schema_version":1,"code":"MISSING_KEYWORD","message":"Please provide a search keyword. Usage: fuck --history search <keyword>"}\n'
        else
            echo -e "${C_RED}❌ Please provide a search keyword.${C_RESET}" >&2
            echo -e "${C_YELLOW}Usage:${C_RESET} fuck --history search <keyword>" >&2
        fi
        return 1
    fi

    if ! _fuck_check_jq; then
        return 1
    fi

    if [[ ! -f "$history_file" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","schema_version":1,"keyword":"%s","total":0,"commands":[]}\n' "$(_fuck_json_escape "$keyword")"
        else
            echo -e "${C_YELLOW}📜 No command history yet.${C_RESET}"
        fi
        return 0
    fi

    # JSON 模式：输出结构化 JSON
    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        local json_results
        json_results=$(jq --arg keyword "$keyword" '{
            status: "ok",
            schema_version: 1,
            keyword: $keyword,
            total: ([.commands[] | select((.prompt | tostring | contains($keyword)) or (.command | tostring | contains($keyword)))] | length),
            commands: [.commands[] | select((.prompt | tostring | contains($keyword)) or (.command | tostring | contains($keyword)))]
        }' "$history_file" 2>/dev/null)
        if [[ -n "$json_results" ]]; then
            printf '%s\n' "$json_results"
        else
            printf '{"status":"ok","schema_version":1,"keyword":"%s","total":0,"commands":[]}\n' "$(_fuck_json_escape "$keyword")"
        fi
        return 0
    fi

    echo -e "${C_CYAN}🔍 Searching for: \"$keyword\"${C_RESET}"
    echo ""

    # Output plain text from jq, add colors in bash
    # Use --arg to safely pass keyword parameter
    local results
    results=$(jq -r --arg keyword "$keyword" '.commands[] |
        select((.prompt | tostring | contains($keyword)) or (.command | tostring | contains($keyword))) |
        "\(.timestamp[0:19]) | \(.prompt) → \(.command)"' \
        "$history_file" 2>/dev/null)

    if [[ -z "$results" ]]; then
        echo -e "${C_YELLOW}No matching commands found.${C_RESET}"
        return 0
    fi

    echo "$results" | while IFS= read -r line; do
        echo -e "${C_DIM}${line}${C_RESET}"
    done
}

# Replay a command from history
_fuck_history_replay() {
    local index="${1:-}"
    local history_file="$INSTALL_DIR/history.json"

    if [[ -z "$index" ]]; then
        echo -e "${C_RED}❌ Please provide a command index.${C_RESET}" >&2
        echo -e "${C_YELLOW}Usage:${C_RESET} fuck --history replay <index>" >&2
        echo -e "${C_DIM}Tip: Use 'fuck --history' to see available commands${C_RESET}" >&2
        return 1
    fi

    # Validate index is a positive integer
    if ! [[ "$index" =~ ^[0-9]+$ ]] || [[ "$index" -le 0 ]]; then
        echo -e "${C_RED}❌ Invalid index: must be a positive integer.${C_RESET}" >&2
        return 1
    fi

    if ! _fuck_check_jq; then
        return 1
    fi

    if [[ ! -f "$history_file" ]]; then
        echo -e "${C_RED}❌ No command history found.${C_RESET}" >&2
        return 1
    fi

    # Convert 1-based index to 0-based (counting from end)
    local array_index=$((index - 1))

    local cmd
    cmd=$(jq -r ".commands[-$index].command" "$history_file" 2>/dev/null)

    if [[ -z "$cmd" ]] || [[ "$cmd" = "null" ]]; then
        echo -e "${C_RED}❌ Command index $index not found.${C_RESET}" >&2
        return 1
    fi

    echo -e "${C_CYAN}🔄 Replaying command:${C_RESET} $cmd"
    echo ""

    # Security check before execution
    local security_result
    security_result=$(_fuck_security_evaluate_command "$cmd")
    local security_level="${security_result%%|*}"
    local security_reason="${security_result#*|}"

    if ! _fuck_security_handle_decision "$security_level" "$security_reason" "$cmd"; then
        echo -e "${C_RED}❌ Command blocked by security policy.${C_RESET}" >&2
        return 1
    fi

    # Execute the command in a subshell to limit scope
    bash -c "$cmd"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo -e "$FUCK ${C_RED}Command failed with exit code $exit_code.${C_RESET}" >&2
    fi

    return $exit_code
}

# --- Favorite Commands Functions (Task 1.4) ---

# Add a command to favorites
_fuck_favorite_add() {
    local name="${1:-}"
    local prompt="${2:-}"

    if [[ -z "$name" ]] || [[ -z "$prompt" ]]; then
        echo -e "${C_RED}❌ Both name and prompt are required.${C_RESET}" >&2
        echo -e "${C_YELLOW}Usage:${C_RESET} fuck --favorite add <name> <prompt>" >&2
        echo -e "${C_YELLOW}Example:${C_RESET} fuck --favorite add \"Update System\" \"update all packages\"" >&2
        return 1
    fi

    if ! _fuck_check_jq; then
        return 1
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    # Generate command using AI
    echo -e "${C_CYAN}🤖 Generating command for: \"$prompt\"${C_RESET}"

    # Call the main execute function to get the command (but don't execute it)
    # We'll temporarily capture the response
    local sysinfo_string
    sysinfo_string=$(_fuck_collect_sysinfo_string)

    local response=""
    local exit_code=0
    if _fuck_should_use_local_api; then
        response=$(_fuck_request_local_model "$prompt" "$sysinfo_string" "${FUCK_TIMEOUT:-30}")
        exit_code=$?
    else
        local spinner_label="Generating... "
        printf '%s' "$spinner_label"
        response=$(_fuck_request_worker_model "$prompt" "$sysinfo_string" "${FUCK_TIMEOUT:-30}" "$spinner_label")
        exit_code=$?
        echo ""
    fi

    if [[ $exit_code -ne 0 ]] || [[ -z "$response" ]]; then
        echo -e "${C_RED}❌ Failed to generate command.${C_RESET}" >&2
        return 1
    fi

    # Generate unique ID
    local fav_id="fav_$(date +%s)_$$"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || echo "unknown")

    # Create favorite entry
    local entry
    entry=$(jq -n \
        --arg id "$fav_id" \
        --arg name "$name" \
        --arg prompt "$prompt" \
        --arg command "$response" \
        --arg created "$timestamp" \
        '{
            id: $id,
            name: $name,
            prompt: $prompt,
            command: $command,
            created: $created
        }' 2>/dev/null)

    if [[ -z "$entry" ]]; then
        echo -e "${C_RED}❌ Failed to create favorite entry.${C_RESET}" >&2
        return 1
    fi

    # Append to favorites
    local temp_file="${history_file}.tmp"
    if jq ".favorites += [$entry]" "$history_file" > "$temp_file" 2>/dev/null; then
        command mv -f -- "$temp_file" "$history_file"
        chmod 600 "$history_file"  # Ensure permissions after mv
        echo -e "${C_GREEN}✅ Added to favorites: \"$name\"${C_RESET}"
        echo -e "${C_DIM}Command: $response${C_RESET}"
        return 0
    else
        echo -e "${C_RED}❌ Failed to save favorite.${C_RESET}" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# List all favorite commands
_fuck_favorite_list() {
    local history_file="$INSTALL_DIR/history.json"

    if ! _fuck_check_jq; then
        return 1
    fi

    if [[ ! -f "$history_file" ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","schema_version":1,"total":0,"favorites":[]}\n'
        else
            echo -e "${C_YELLOW}⭐ No favorites yet.${C_RESET}"
            echo -e "${C_DIM}Add favorites with: fuck --favorite add <name> <prompt>${C_RESET}"
        fi
        return 0
    fi

    local total_count
    total_count=$(jq '.favorites | length' "$history_file" 2>/dev/null || echo "0")

    if [[ "$total_count" -eq 0 ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"ok","schema_version":1,"total":0,"favorites":[]}\n'
        else
            echo -e "${C_YELLOW}⭐ No favorites yet.${C_RESET}"
            echo -e "${C_DIM}Add favorites with: fuck --favorite add <name> <prompt>${C_RESET}"
        fi
        return 0
    fi

    # JSON 模式：输出结构化 JSON
    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        jq '{status: "ok", schema_version: 1, total: (.favorites | length), favorites: [.favorites | to_entries[] | {index: (.key + 1), name: .value.name, prompt: .value.prompt, command: .value.command, created: .value.created}]}' \
            "$history_file" 2>/dev/null || printf '{"status":"error","schema_version":1,"code":"FAVORITES_PARSE_FAILED","message":"Failed to parse favorites"}\n'
        return 0
    fi

    echo -e "${C_CYAN}⭐ Favorite Commands:${C_RESET}"
    echo ""

    jq -r '.favorites | to_entries[] |
        "'"${C_BOLD}"'\(.key + 1)) '"${C_RESET}"'\(.value.name)\n   '"${C_DIM}"'Prompt: \(.value.prompt)'"${C_RESET}"'\n   '"${C_DIM}"'Command: \(.value.command)'"${C_RESET}"'\n"' \
        "$history_file" 2>/dev/null | while IFS= read -r line; do
        echo -e "$line"
    done

    echo -e "${C_DIM}Total: $total_count favorites${C_RESET}"
    echo -e "${C_DIM}Tip: Use 'fuck --favorite run <number>' to execute${C_RESET}"
}

# Execute a favorite command
_fuck_favorite_run() {
    local index="${1:-}"
    local history_file="$INSTALL_DIR/history.json"

    if [[ -z "$index" ]]; then
        echo -e "${C_RED}❌ Please provide a favorite index.${C_RESET}" >&2
        echo -e "${C_YELLOW}Usage:${C_RESET} fuck --favorite run <index>" >&2
        echo -e "${C_DIM}Tip: Use 'fuck --favorite list' to see available favorites${C_RESET}" >&2
        return 1
    fi

    # Validate index is a positive integer
    if ! [[ "$index" =~ ^[0-9]+$ ]] || [[ "$index" -le 0 ]]; then
        echo -e "${C_RED}❌ Invalid index: must be a positive integer.${C_RESET}" >&2
        return 1
    fi

    if ! _fuck_check_jq; then
        return 1
    fi

    if [[ ! -f "$history_file" ]]; then
        echo -e "${C_RED}❌ No favorites found.${C_RESET}" >&2
        return 1
    fi

    # Convert 1-based index to 0-based array index
    local array_index=$((index - 1))

    local cmd
    cmd=$(jq -r ".favorites[$array_index].command" "$history_file" 2>/dev/null)

    if [[ -z "$cmd" ]] || [[ "$cmd" = "null" ]]; then
        echo -e "${C_RED}❌ Favorite #$index not found.${C_RESET}" >&2
        return 1
    fi

    local fav_name
    fav_name=$(jq -r ".favorites[$array_index].name" "$history_file" 2>/dev/null)

    echo -e "${C_CYAN}⭐ Executing favorite: \"$fav_name\"${C_RESET}"
    echo -e "${C_DIM}Command: $cmd${C_RESET}"
    echo ""

    # Security check before execution
    local security_result
    security_result=$(_fuck_security_evaluate_command "$cmd")
    local security_level="${security_result%%|*}"
    local security_reason="${security_result#*|}"

    if ! _fuck_security_handle_decision "$security_level" "$security_reason" "$cmd"; then
        echo -e "${C_RED}❌ Command blocked by security policy.${C_RESET}" >&2
        return 1
    fi

    # Execute the command in a subshell to limit scope
    bash -c "$cmd"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo -e "$FUCK ${C_RED}Command failed with exit code $exit_code.${C_RESET}" >&2
    fi

    return $exit_code
}

# Delete a favorite command
_fuck_favorite_delete() {
    local index="${1:-}"
    local history_file="$INSTALL_DIR/history.json"

    if [[ -z "$index" ]]; then
        echo -e "${C_RED}❌ Please provide a favorite index to delete.${C_RESET}" >&2
        echo -e "${C_YELLOW}Usage:${C_RESET} fuck --favorite delete <index>" >&2
        return 1
    fi

    if ! _fuck_check_jq; then
        return 1
    fi

    if [[ ! -f "$history_file" ]]; then
        echo -e "${C_RED}❌ No favorites found.${C_RESET}" >&2
        return 1
    fi

    # Convert 1-based index to 0-based array index
    local array_index=$((index - 1))

    local fav_name
    fav_name=$(jq -r ".favorites[$array_index].name" "$history_file" 2>/dev/null)

    if [[ -z "$fav_name" ]] || [[ "$fav_name" = "null" ]]; then
        echo -e "${C_RED}❌ Favorite #$index not found.${C_RESET}" >&2
        return 1
    fi

    echo -e "${C_YELLOW}🗑️  Deleting favorite: \"$fav_name\"${C_RESET}"

    # Remove the favorite
    local temp_file="${history_file}.tmp"
    if jq "del(.favorites[$array_index])" "$history_file" > "$temp_file" 2>/dev/null; then
        command mv -f -- "$temp_file" "$history_file"
        echo -e "${C_GREEN}✅ Favorite deleted.${C_RESET}"
        return 0
    else
        echo -e "${C_RED}❌ Failed to delete favorite.${C_RESET}" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# Uninstalls the script
_uninstall_script() {
    echo -e "$FUCK ${C_YELLOW}So you're kicking me out? Fine.${C_RESET}"

    # Find the profile file
    local profile_file
    profile_file=$(_installer_detect_profile)
    local source_line="source $MAIN_SH"

    if [[ "$profile_file" != "unknown_profile" ]] && [[ -f "$profile_file" ]]; then
        if grep -qF "$source_line" "$profile_file"; then
            # 使用 awk 按整行过滤，避免 GNU/BSD sed 分隔符差异。
            local tmp_profile="${profile_file}.fuckits.tmp"
            awk -v source_line="$source_line" \
                '$0 != source_line && $0 != "# Added by fuckits installer"' \
                "$profile_file" > "$tmp_profile"
            mv "$tmp_profile" "$profile_file"
        fi
    else
        echo -e "${C_YELLOW}Could not find a shell profile file to modify. Your problem now.${C_RESET}"
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi

    echo -e "$FUCK ${C_GREEN}I'm gone. Don't come crying back.${C_RESET}"
    echo -e "${C_CYAN}Now restart your damn shell.${C_RESET}"
}

# 显示不支持的命令错误
_fuck_show_unsupported_command() {
    local cmd="$1"

    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        printf '{"status":"error","schema_version":1,"code":"UNSUPPORTED_COMMAND","message":"Unknown command: --%s. Use --help to see available commands."}\n' "$cmd"
    else
        echo -e "${C_RED}❌ Unknown command: ${C_BOLD}--${cmd}${C_RESET}" >&2
        echo -e "${C_YELLOW}Use ${C_BOLD}fuck --help${C_RESET}${C_YELLOW} to see available commands.${C_RESET}" >&2
    fi
}

# 检查远程版本（使用缓存避免后台进程通知）
_fuck_check_remote_version_async() {
    local cache_file="${INSTALL_DIR:-$HOME/.fuck}/.version_check_cache"
    local cache_ttl=3600  # 缓存 1 小时
    local now
    now=$(date +%s 2>/dev/null) || return 0

    # 检查缓存是否有效
    if [[ -f "$cache_file" ]]; then
        local cached_time cached_version
        cached_time=$(head -1 "$cache_file" 2>/dev/null) || true
        cached_version=$(tail -1 "$cache_file" 2>/dev/null) || true
        if [[ -n "$cached_time" ]] && [[ $((now - cached_time)) -lt $cache_ttl ]]; then
            if [[ -n "$cached_version" ]] && [[ "$cached_version" != "$SCRIPT_VERSION" ]]; then
                echo "" >&2
                echo -e "${C_YELLOW}📦 New version available: ${C_BOLD}${cached_version}${C_RESET}${C_YELLOW} (current: ${C_BOLD}${SCRIPT_VERSION}${C_RESET}${C_YELLOW})${C_RESET}" >&2
                echo -e "${C_CYAN}Run ${C_BOLD}fuck --update${C_RESET}${C_CYAN} to update.${C_RESET}" >&2
            fi
            return 0
        fi
    fi

    # 缓存过期，同步检查（有 3 秒超时）
    local api_url="${FUCK_API_ENDPOINT:-${DEFAULT_API_ENDPOINT:-https://fuckits.25500552.xyz/}}"
    local health_url="${api_url%/}/health"
    local remote_version
    remote_version=$(curl -sS --max-time 3 "$health_url" 2>/dev/null | grep -o '"version":"[^"]*"' | head -1 | sed 's/"version":"//;s/"//' | tr -cd '0-9a-zA-Z._-') || true

    # 写入缓存
    mkdir -p "$(dirname "$cache_file")" 2>/dev/null
    printf '%s\n%s\n' "$now" "$remote_version" > "$cache_file" 2>/dev/null

    if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo "" >&2
        echo -e "${C_YELLOW}📦 New version available: ${C_BOLD}${remote_version}${C_RESET}${C_YELLOW} (current: ${C_BOLD}${SCRIPT_VERSION}${C_RESET}${C_YELLOW})${C_RESET}" >&2
        echo -e "${C_CYAN}Run ${C_BOLD}fuck --update${C_RESET}${C_CYAN} to update.${C_RESET}" >&2
    fi
}

# 路由子命令：--help, --config, --version, --update, --uninstall, --history, --favorite
# Returns: 0 如果已处理子命令，1 如果不是子命令（继续主流程）
_fuck_route_subcommands() {
    local arg1="${1:-}"

    # 只要第一个参数以 -- 开头，就作为本地命令处理
    if [[ "$arg1" == --* ]]; then
        local cmd="${arg1#--}"  # 移除 -- 前缀

        case "$cmd" in
            help|h)
                _fuck_show_help
                _fuck_check_remote_version_async
                return 0
                ;;
            config)
                if [[ "$#" -gt 1 ]]; then
                    echo -e "${C_YELLOW}Note:${C_RESET} '--config' doesn't take arguments." >&2
                fi
                _fuck_show_config_help
                return 0
                ;;
            version|v)
                if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
                    printf '{"status":"ok","schema_version":1,"version":"%s"}\n' "${SCRIPT_VERSION}"
                else
                    echo "fuckits ${SCRIPT_VERSION}"
                fi
                return 0
                ;;
            update)
                _fuck_update_script
                return 0
                ;;
            uninstall)
                if [[ "$#" -gt 1 ]]; then
                    echo -e "${C_YELLOW}Note:${C_RESET} '--uninstall' doesn't take arguments." >&2
                fi
                _uninstall_script
                return 0
                ;;
            oauth|auth)
                shift
                case "${1:-}" in
                    status)
                        _fuck_pollinations_status
                        return 0
                        ;;
                    logout)
                        _fuck_pollinations_logout
                        return 0
                        ;;
                    "")
                        _fuck_pollinations_device_flow
                        return 0
                        ;;
                    *)
                        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
                            printf '{"status":"error","schema_version":1,"code":"INVALID_SUBCOMMAND","message":"Usage: fuck --oauth [status|logout]"}\n'
                        else
                            echo -e "${C_YELLOW}Usage:${C_RESET} fuck --oauth [status|logout]" >&2
                            echo -e "  ${C_DIM}(no args)${C_RESET}   Start OAuth device flow" >&2
                            echo -e "  ${C_DIM}status${C_RESET}     Show current auth status" >&2
                            echo -e "  ${C_DIM}logout${C_RESET}     Clear stored credentials" >&2
                        fi
                        return 0
                        ;;
                esac
                ;;
            history)
                shift
                case "${1:-}" in
                    search)  _fuck_history_search "${2:-}" ; return 0 ;;
                    replay)  _fuck_history_replay "${2:-}" ; return 0 ;;
                    *)       _fuck_history "${1:-}" ; return 0 ;;
                esac
                ;;
            favorite|fav)
                shift
                case "${1:-}" in
                    add)           _fuck_favorite_add "${2:-}" "${3:-}" ; return 0 ;;
                    list|ls)       _fuck_favorite_list ; return 0 ;;
                    run|exec)      _fuck_favorite_run "${2:-}" ; return 0 ;;
                    delete|del|rm) _fuck_favorite_delete "${2:-}" ; return 0 ;;
                    *)
                        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
                            printf '{"status":"error","schema_version":1,"code":"INVALID_SUBCOMMAND","message":"Usage: fuck --favorite <add|list|run|delete>"}\n'
                        else
                            echo -e "${C_YELLOW}Usage:${C_RESET} fuck --favorite <add|list|run|delete>" >&2
                            echo -e "  ${C_DIM}add <name> <prompt>${C_RESET}     Add a new favorite command"
                            echo -e "  ${C_DIM}list${C_RESET}                    List all favorites"
                            echo -e "  ${C_DIM}run <index>${C_RESET}             Execute a favorite"
                            echo -e "  ${C_DIM}delete <index>${C_RESET}          Delete a favorite"
                        fi
                        return 0
                        ;;
                esac
                ;;
            *)
                # 不支持的 -- 命令
                _fuck_show_unsupported_command "$cmd"
                return 0
                ;;
        esac
    fi

    return 1  # 不是 -- 命令，继续主流程（发送到 API）
}

# 发送 AI 请求并显示结果
# Arguments: $1=prompt, $2=sysinfo, $3=timeout
# Outputs: 命令到 stdout
# Returns: 0 成功，非 0 失败
_fuck_run_ai_request() {
    local prompt="$1"
    local sysinfo_string="$2"
    local curl_timeout="$3"

    local response="" exit_code=0
    if _fuck_should_use_local_api; then
        echo -ne "${C_YELLOW}Using your local API key...${C_RESET} " >&2
        response=$(_fuck_request_local_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    else
        local msg_thinking spinner_label
        msg_thinking=$(_i18n_get "msg.status.thinking")
        spinner_label="$msg_thinking"
        printf '%s' "$spinner_label" >&2
        response=$(_fuck_request_worker_model "$prompt" "$sysinfo_string" "$curl_timeout" "$spinner_label")
        exit_code=$?
    fi

    echo "" >&2

    if [[ $exit_code -ne 0 ]] || [[ -z "$response" ]]; then
        return $exit_code
    fi

    echo -e "${C_CYAN}Here is what I came up with:${C_RESET}" >&2
    echo -e "${C_DIM}----------------------------------------${C_RESET}" >&2
    printf '%s\n' "$response" >&2
    echo -e "${C_DIM}----------------------------------------${C_RESET}" >&2

    printf '%s' "$response"
}

# 安全检查 → 用户确认 → 执行命令 → 记录历史
# Arguments: $1=prompt, $2=response, $3=auto_mode, $4=start_time
# Returns: 命令执行的退出码
_fuck_confirm_and_execute() {
    local prompt="$1"
    local response="$2"
    local auto_mode="$3"
    local start_time="$4"

    # 安全检查
    local security_result security_level security_reason
    security_result=$(_fuck_detect_dangerous_command "$response")
    security_level=${security_result%%|*}
    security_reason=${security_result#*|}

    if ! _fuck_security_handle_decision "$security_level" "$security_reason" "$response"; then
        echo -e "${C_RED}❌ Command aborted due to security policy.${C_RESET}" >&2
        return 1
    fi

    # 用户确认
    local should_exec=false
    if _fuck_truthy "$auto_mode"; then
        echo -e "${C_YELLOW}⚡ Auto-exec enabled. Running...${C_RESET}"
        should_exec=true
    else
        while true; do
            printf "${C_BOLD}Execute? [Y/n] ${C_RESET}"
            local confirmation normalized
            if [[ -r /dev/tty ]]; then
                IFS= read -r confirmation < /dev/tty
            else
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
                    _fuck_audit_log "ABORT" "$response"
                    echo -e "${C_YELLOW}❌ Aborted.${C_RESET}" >&2
                    break
                    ;;
                *) ;;
            esac
        done
    fi

    if [[ "$should_exec" != "true" ]]; then
        return 1
    fi

    # 执行命令
    # SECURITY NOTE: 现有保护层：
    # 1. 服务端清洗 (sanitizeCommand)
    # 2. 本地安全引擎: 21 条正则规则 (8 block + 9 challenge + 4 warn)
    # 3. 用户确认提示 (除非 FUCK_AUTO_EXEC=true)
    bash -c "$response"
    local exit_code=$?

    _fuck_audit_log "EXEC" "$response" "$exit_code"

    # 记录历史
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    _fuck_log_history "$prompt" "$response" "$exit_code" "$duration"

    if [[ $exit_code -ne 0 ]]; then
        echo -e "$FUCK ${C_RED}Command failed with exit code $exit_code.${C_RESET}" >&2
    fi
    return $exit_code
}

# 主入口：联系 API 并执行命令
_fuck_execute_prompt() {
    # 解析 --json 标志（从参数中提取并移除）
    local _FUCK_JSON_MODE=0
    local _args=()
    for _arg in "$@"; do
        if [[ "$_arg" = "--json" ]]; then
            _FUCK_JSON_MODE=1
        else
            _args+=("$_arg")
        fi
    done
    set -- "${_args[@]}"

    # --- 语言切换命令 ---
    if [[ "${1:-}" == "--lang" ]] || [[ "${1:-}" == "--locale" ]]; then
        _fuck_handle_lang_command "${2:-}"
        return $?
    fi

    # 路由子命令
    _fuck_route_subcommands "$@" && return 0

    if ! command -v curl &> /dev/null; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"error","schema_version":1,"code":"MISSING_DEPENDENCY","message":"curl is required but not installed"}\n'
        else
            echo -e "$FUCK ${C_RED}'fuck' command needs 'curl'. Please install it.${C_RESET}" >&2
        fi
        return 1
    fi

    if [[ "$#" -eq 0 ]]; then
        if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
            printf '{"status":"error","schema_version":1,"code":"MISSING_PROMPT","message":"No prompt provided. Usage: fuck <prompt> [--json]"}\n'
        else
            echo -e "$FUCK ${C_RED}You forgot to ask me what to do.${C_RESET}" >&2
        fi
        return 1
    fi

    local prompt="$*"
    local auto_mode="${FUCK_AUTO_EXEC:-0}"
    local curl_timeout="${FUCK_TIMEOUT:-30}"
    local sysinfo_string
    sysinfo_string=$(_fuck_collect_sysinfo_string)

    local start_time
    start_time=$(date +%s)

    # 发送 AI 请求
    local response
    response=$(_fuck_run_ai_request "$prompt" "$sysinfo_string" "$curl_timeout") || return $?

    # JSON 模式：输出命令但不执行
    if _fuck_truthy "${_FUCK_JSON_MODE:-0}"; then
        local escaped_cmd
        escaped_cmd=$(_fuck_json_escape "$response")
        printf '{"status":"ok","schema_version":1,"command":"%s","prompt":"%s"}\n' "$escaped_cmd" "$(_fuck_json_escape "$prompt")"
        return 0
    fi

    # 安全检查 → 确认 → 执行 → 历史记录
    _fuck_confirm_and_execute "$prompt" "$response" "$auto_mode" "$start_time"
}

# Define the alias for interactive use (supports custom aliases)

_fuck_define_aliases

# --- 核心逻辑结束 ---

# --- 安装器函数（由外层脚本运行）---

# Main installation function
_installer_secure_config_file() {
        if [[ -f "$CONFIG_FILE" ]]; then
        chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    fi
}

# 检查远程版本并与本地版本对比
# 从 /health 端点获取远程版本，静默失败
_fuck_check_remote_version() {
    local api_url="${FUCK_API_ENDPOINT:-${DEFAULT_API_ENDPOINT:-https://fuckits.25500552.xyz/}}"
    local health_url="${api_url%/}/health"
    local remote_version
    remote_version=$(curl -sS --max-time 5 "$health_url" 2>/dev/null | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"version"[[:space:]]*:[[:space:]]*"//;s/"$//' | tr -cd '0-9a-zA-Z._-') || true

    if [[ -z "$remote_version" ]]; then
        return 0
    fi

    if [[ "$remote_version" != "$SCRIPT_VERSION" ]]; then
        echo -e "${C_YELLOW}📦 Remote version: ${C_BOLD}${remote_version}${C_RESET}${C_YELLOW} | Local version: ${C_BOLD}${SCRIPT_VERSION}${C_RESET}"
        echo -e "${C_CYAN}Run 'curl -sS ${api_url} | bash' to update.${C_RESET}"
    else
        echo -e "${C_GREEN}✅ Version ${SCRIPT_VERSION} is up to date.${C_RESET}"
    fi
}

# --- 初始化阶段独立版本（_install_script 依赖）---
# _fuck_source_core() 尚未运行，runtime-common.sh 不可用
_installer_detect_profile() {
    if [[ -n "${SHELL:-}" ]] && echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [[ -n "${SHELL:-}" ]] && echo "$SHELL" | grep -q "bash"; then
        echo "$HOME/.bashrc"
    elif [[ -f "$HOME/.profile" ]]; then
        echo "$HOME/.profile"
    elif [[ -f "$HOME/.zshrc" ]]; then
        echo "$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
    else
        echo "unknown_profile"
    fi
}

_install_script() {
    mkdir -p "$INSTALL_DIR"

    local local_ver=""
    local remote_ver=""
    local api_url="${FUCK_API_ENDPOINT:-${DEFAULT_API_ENDPOINT:-https://fuckits.25500552.xyz/}}"

    # 已安装时：先对比版本，相同则跳过更新
    if [[ -f "$MAIN_SH" ]]; then
        local_ver=$(grep -o "SCRIPT_VERSION='[^']*'" "$MAIN_SH" 2>/dev/null | head -1 | sed "s/SCRIPT_VERSION='//;s/'//") || true
        remote_ver=$(curl -sS --max-time 5 "${api_url%/}/health" 2>/dev/null | grep -o '"version":"[^"]*"' | head -1 | sed 's/"version":"//;s/"//') || true

        if [[ -n "$local_ver" ]] && [[ -n "$remote_ver" ]] && [[ "$local_ver" = "$remote_ver" ]]; then
            echo -e "${C_GREEN}✅ Version ${local_ver} is up to date. No update needed.${C_RESET}"
            return 0
        fi

        if [[ -n "$local_ver" ]] && [[ -n "$remote_ver" ]]; then
            echo -e "${C_YELLOW}📦 Local: ${C_BOLD}${local_ver}${C_RESET}${C_YELLOW} → Remote: ${C_BOLD}${remote_ver}${C_RESET}"
            echo -e "${C_CYAN}Updating...${C_RESET}"
        fi

        # 更新：删除旧脚本（保留配置和历史记录）
        rm -f "$MAIN_SH"
    fi

    echo -e "$FCKN ${C_BOLD}Alright, let's get this shit installed...${C_RESET}"

    # Write the embedded core logic to the main.sh file
    _fuck_write_core "$MAIN_SH"

    if [[ $? -ne 0 ]]; then
        echo -e "$FUCK ${C_RED}Can't write to the file. Check your damn permissions.${C_RESET}" >&2
        return 1
    fi

    # 验证写入的文件包含正确的版本号
    local _installed_ver
    _installed_ver=$(grep -o "SCRIPT_VERSION='[^']*'" "$MAIN_SH" 2>/dev/null | head -1 | sed "s/SCRIPT_VERSION='//;s/'//") || true
    if [[ -n "$_installed_ver" ]] && [[ "$_installed_ver" != "$remote_ver" ]] && [[ -n "$remote_ver" ]]; then
        echo -e "${C_YELLOW}⚠️ Installed version ${_installed_ver} differs from remote ${remote_ver}, retrying...${C_RESET}" >&2
        rm -f "$MAIN_SH"
        _fuck_write_core "$MAIN_SH"
        chmod +x "$MAIN_SH"
    fi

    # Make main.sh executable
    chmod +x "$MAIN_SH"

    # Create a default config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
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

# Pollinations OAuth (use 'fuck --oauth' to authorize)
# export FUCK_POLLINATIONS_CLIENT_ID="pk_..."

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
    
    if [[ "$profile_file" = "unknown_profile" ]]; then
        echo -e "$FUCK ${C_RED}I can't find .bashrc, .zshrc, or .profile. You're on your own.${C_RESET}" >&2
        echo -e "${C_YELLOW}Manually add this line to whatever startup file you use:${C_RESET}" >&2
        echo -e "\n  ${C_CYAN}source $MAIN_SH${C_RESET}\n" >&2
        return
    fi
    
    local source_line="source $MAIN_SH"
    if ! grep -qF "$source_line" "$profile_file"; then
        # Ensure the file ends with a newline before we add our lines
        if [[ -n "$(tail -c1 "$profile_file")" ]]; then
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
        echo -e "  ${C_CYAN}fuck --uninstall git${C_RESET}"
        echo -e "  ${C_CYAN}fuck find all files larger than 10MB in the current directory${C_RESET}"
        echo -e "  ${C_RED_BOLD}fuck --uninstall${C_RESET} ${C_GREEN}# Uninstalls ${C_RESET}${C_RED}fuck${C_RESET}${C_GREEN} itself${C_RESET}"
        echo -e "  ${C_RED_BOLD}fuck config${C_RESET} ${C_GREEN}# Show configuration help${C_RESET}"
        echo -e "\n${C_BOLD}--- HISTORY & FAVORITES (Task 1.4) ---${C_RESET}"
        echo -e "  ${C_CYAN}fuck --history${C_RESET} ${C_GREEN}# View recent commands${C_RESET}"
        echo -e "  ${C_CYAN}fuck --history search <keyword>${C_RESET} ${C_GREEN}# Search history${C_RESET}"
        echo -e "  ${C_CYAN}fuck --favorite add <name> <prompt>${C_RESET} ${C_GREEN}# Save a favorite${C_RESET}"
        echo -e "  ${C_CYAN}fuck --favorite list${C_RESET} ${C_GREEN}# List all favorites${C_RESET}"
        echo -e "\n${C_YELLOW}📦 Note: History features require 'jq' (JSON processor)${C_RESET}"
        echo -e "  Install it with: ${C_CYAN}brew install jq${C_RESET} (macOS)"
        echo -e "                   ${C_CYAN}apt install jq${C_RESET} (Ubuntu/Debian)"
        echo -e "\n${C_YELLOW}Remember to restart your shell to begin!${C_RESET}"
    else
        echo -e "$FUCK ${C_GREEN}Script updated successfully.${C_RESET}"
    fi
}


# --- 脚本主入口 ---
# 被 source 时只加载函数；直接执行时再进入安装或命令执行流程。
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "$#" -gt 0 ]]; then
        if [[ "$1" = "install" ]] && [[ "$#" -eq 1 ]]; then
            _install_script
            exit 0
        fi

        _fuck_execute_prompt "$@"
    else
        _install_script
    fi
fi
