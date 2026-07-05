#!/bin/bash
#
# fuckits - 统一安装脚本（双语支持）
# 构建时自动生成 main.sh（英文）和 zh_main.sh（中文）
#

set -euo pipefail

# --- 防止 readonly 变量重复定义 ---
# 此守卫允许脚本被多次 source（例如在测试中）
if [[ -z "${FUCKITS_CONSTANTS_DEFINED:-}" ]]; then
    # 标记常量已定义（export 使子 shell 可见）
    export FUCKITS_CONSTANTS_DEFINED=1

    # --- 颜色定义 ---
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

fi  # readonly 常量守卫结束

# --- i18n 国际化系统 ---

# 当前语言（构建时可覆盖默认值）
_FUCKITS_LOCALE="${FUCKITS_LOCALE:-en}"

# 翻译表（关联数组）
declare -gA _I18N_TABLE=()

# 初始化翻译表
_i18n_init() {
    # 如果已初始化，跳过
    [[ ${#_I18N_TABLE[@]} -gt 0 ]] && return 0

    # --- 英文翻译 ---
    _I18N_TABLE[msg.help.title]="AI natural language to shell command"
    _I18N_TABLE[msg.help.usage]="Usage: fuck <your prompt>"
    _I18N_TABLE[msg.help.commands]="Commands:"
    _I18N_TABLE[msg.help.options]="Options:"
    _I18N_TABLE[msg.help.examples]="Examples:"
    _I18N_TABLE[msg.config.title]="Configuration"
    _I18N_TABLE[msg.config.edit_with]="Edit with:"
    _I18N_TABLE[msg.config.open_file]="Open this file in your favourite editor to customise fuckits."
    _I18N_TABLE[msg.config.available_toggles]="Available toggles:"
    _I18N_TABLE[msg.config.pro_tip]="Pro tip:"
    _I18N_TABLE[msg.config.lock_info]="we lock CONFIG_FILE to chmod 600 so your API key stays local."
    _I18N_TABLE[msg.error.api_key_not_set]="Local API key not configured. Set FUCK_OPENAI_API_KEY in ~/.fuck/config.sh."
    _I18N_TABLE[msg.error.api_request_failed]="Local API request failed."
    _I18N_TABLE[msg.error.parse_response_failed]="Unable to parse local model response."
    _I18N_TABLE[msg.error.home_not_set]="Your HOME variable isn't set. I don't know where to install this shit. Set it yourself (e.g., export HOME=/root)."
    _I18N_TABLE[msg.status.thinking]="Thinking... "
    _I18N_TABLE[msg.status.using_local_key]="Using your local API key... "
    _I18N_TABLE[msg.status.here_is_result]="Here is what I came up with:"
    _I18N_TABLE[msg.security.potentially_dangerous]="Potentially dangerous command detected"
    _I18N_TABLE[msg.security.high_risk]="High-risk command detected"
    _I18N_TABLE[msg.security.blocked]="Command blocked by policy"
    _I18N_TABLE[msg.security.confirm_risk]="I accept the risk"
    _I18N_TABLE[msg.update.new_version]="New version available:"
    _I18N_TABLE[msg.update.current]="current:"
    _I18N_TABLE[msg.update.up_to_date]="is up to date."
    _I18N_TABLE[msg.update.remote_version]="Remote version:"
    _I18N_TABLE[msg.update.local_version]="Local version:"
    _I18N_TABLE[msg.lang.current]="Current language:"
    _I18N_TABLE[msg.lang.switched]="Language switched to:"
    _I18N_TABLE[msg.lang.invalid]="Invalid language. Use 'en' or 'zh'."
    _I18N_TABLE[msg.lang.detecting]="Detected system language:"

    # --- 中文翻译 ---
    _I18N_TABLE[msg.help.title.zh]="AI 自然语言转 Shell 命令"
    _I18N_TABLE[msg.help.usage.zh]="用法: fuck <你的需求>"
    _I18N_TABLE[msg.help.commands.zh]="可用命令:"
    _I18N_TABLE[msg.help.options.zh]="选项:"
    _I18N_TABLE[msg.help.examples.zh]="示例:"
    _I18N_TABLE[msg.config.title.zh]="配置"
    _I18N_TABLE[msg.config.edit_with.zh]="可以使用："
    _I18N_TABLE[msg.config.open_file.zh]="用任意编辑器打开该文件即可修改配置。"
    _I18N_TABLE[msg.config.available_toggles.zh]="可用选项："
    _I18N_TABLE[msg.config.pro_tip.zh]="安全说明："
    _I18N_TABLE[msg.config.lock_info.zh]="配置文件会自动 chmod 600，防止 Key 泄露。"
    _I18N_TABLE[msg.error.api_key_not_set.zh]="未配置本地 API Key，请在 ~/.fuck/config.sh 中设置 FUCK_OPENAI_API_KEY。"
    _I18N_TABLE[msg.error.api_request_failed.zh]="本地 API 请求失败。"
    _I18N_TABLE[msg.error.parse_response_failed.zh]="无法解析本地模型响应。"
    _I18N_TABLE[msg.error.home_not_set.zh]="HOME 变量未设置，无法确定安装位置。请自行设置（如 export HOME=/root）。"
    _I18N_TABLE[msg.status.thinking.zh]="思考中... "
    _I18N_TABLE[msg.status.using_local_key.zh]="正在使用本地 API Key... "
    _I18N_TABLE[msg.status.here_is_result.zh]="这是我想出来的命令："
    _I18N_TABLE[msg.security.potentially_dangerous.zh]="检测到潜在风险"
    _I18N_TABLE[msg.security.high_risk.zh]="高危命令，请再次确认"
    _I18N_TABLE[msg.security.blocked.zh]="命令被安全策略阻止"
    _I18N_TABLE[msg.security.confirm_risk.zh]="我确认承担风险"
    _I18N_TABLE[msg.update.new_version.zh]="新版本可用："
    _I18N_TABLE[msg.update.current.zh]="当前："
    _I18N_TABLE[msg.update.up_to_date.zh]="已是最新。"
    _I18N_TABLE[msg.update.remote_version.zh]="远程版本："
    _I18N_TABLE[msg.update.local_version.zh]="本地版本："
    _I18N_TABLE[msg.lang.current.zh]="当前语言："
    _I18N_TABLE[msg.lang.switched.zh]="语言已切换为："
    _I18N_TABLE[msg.lang.invalid.zh]="无效语言。请使用 'en' 或 'zh'。"
    _I18N_TABLE[msg.lang.detecting.zh]="检测到系统语言："
}

# 获取翻译文本
# Arguments: $1=翻译键
# Outputs: 翻译后的文本
_i18n_get() {
    local key="$1"

    # 确保翻译表已初始化
    [[ ${#_I18N_TABLE[@]} -eq 0 ]] && _i18n_init

    # 先尝试获取当前语言的翻译
    local localized_key="${key}.${_FUCKITS_LOCALE}"
    if [[ -n "${_I18N_TABLE[$localized_key]+x}" ]]; then
        echo "${_I18N_TABLE[$localized_key]}"
        return 0
    fi

    # 回退到基础键（英文）
    if [[ -n "${_I18N_TABLE[$key]+x}" ]]; then
        echo "${_I18N_TABLE[$key]}"
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
    # 优先级：环境变量 > 配置文件 > 系统检测
    if [[ -n "${FUCKITS_LOCALE:-}" ]]; then
        # 环境变量已设置，直接使用
        _FUCKITS_LOCALE="$FUCKITS_LOCALE"
    elif [[ -n "${CONFIG_FILE:-}" ]] && [[ -f "$CONFIG_FILE" ]] && grep -q "^export FUCKITS_LOCALE=" "$CONFIG_FILE" 2>/dev/null; then
        # 从配置文件读取
        local config_locale
        config_locale=$(grep "^export FUCKITS_LOCALE=" "$CONFIG_FILE" | tail -n 1 | cut -d'"' -f2)
        _FUCKITS_LOCALE="$config_locale"
    else
        # 自动检测系统语言
        _FUCKITS_LOCALE=$(_i18n_detect_locale)
    fi

    export FUCKITS_LOCALE="$_FUCKITS_LOCALE"
}

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
