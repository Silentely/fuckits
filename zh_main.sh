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

    # --- 配置 ---
    if [ -z "${HOME:-}" ]; then
        # 这部分是给临时运行模式用的，它不安装任何东西
        # 但我们还是需要定义这些变量，免得脚本报错
        # 安装程序部分会进行真正的检查
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

# 检测包管理器
_fuck_detect_pkg_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# 把系统信息整成一个字符串
_fuck_collect_sysinfo_string() {
    local pkg_manager
    pkg_manager=$(_fuck_detect_pkg_manager)
    # 服务端的 LLM 得能看懂这个字符串
    echo "OS: $(uname -s), Arch: $(uname -m), Shell: ${SHELL:-unknown}, PkgMgr: $pkg_manager, CWD: $(pwd)"
}

# JSON 转义，免得出问题
_fuck_json_escape() {
    # 就转义那几个特殊字符
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\"/g' -e 's/\n/\\n/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g'
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
        printf 'You are an expert shell script generator. A user will provide their system information and a prompt. Your task is to return a raw, executable shell script that accomplishes their goal. The script can be multi-line. Do not provide any explanation, comments, markdown formatting (like ```bash), or a shebang (e.g., #!/bin/bash). Just the raw script content. The user\'s system info is: %s' "$sysinfo"
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

    local model="${FUCK_OPENAI_API_MODEL:-gpt-4-turbo}"
    local api_base="${FUCK_OPENAI_API_BASE:-https://api.openai.com/v1}"
    api_base=${api_base%/}
    local api_url="$api_base/chat/completions"

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

    _fuck_spinner "$pid"

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
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    # 隐藏光标
    tput civis 2>/dev/null || printf "\033[?25l"

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " %c " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    printf "   \b\b\b"
    
    # 恢复光标
    tput cnorm 2>/dev/null || printf "\033[?25h"
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

    cat <<CFG >> "$CONFIG_FILE"

# $comment
$assignment
CFG
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
        echo -ne "${C_YELLOW}使用本地 API Key...${C_RESET} "
        response=$(_fuck_request_local_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    else
        echo -ne "${C_YELLOW}思考中...${C_RESET} "
        response=$(_fuck_request_worker_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    fi

    echo ""

    if [ $exit_code -ne 0 ] || [ -z "$response" ]; then
        return $exit_code
    fi

    # --- 用户确认 ---
    echo -e "${C_CYAN}为您生成了以下命令：${C_RESET}"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"
    echo -e "${C_GREEN}${response}${C_RESET}"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"

    local should_exec=false
    if _fuck_truthy "$auto_mode"; then
        echo -e "${C_YELLOW}⚡ 已开启自动执行模式，立即运行...${C_RESET}"
        should_exec=true
    else
        while true; do
            printf "${C_BOLD}是否执行？[Y/n] ${C_RESET}"
            local confirmation
            if [ -r /dev/tty ]; then
                read -r -n 1 confirmation < /dev/tty
                echo "" # Newline
            else
                read -r confirmation
            fi

            case "$confirmation" in
                [yY]|"")
                    should_exec=true
                    break
                    ;;
                [nN])
                    should_exec=false
                    break
                    ;;
                *)
                    # Loop
                    ;;
            esac
        done
    fi

    if [ "$should_exec" = "true" ]; then
        # 执行服务器返回的命令并检查退出码
        if eval "$response"; then
            echo -e "${C_GREEN}执行完成。${C_RESET}"
        else
            local exit_code=$?
            echo -e "${C_RED_BOLD}错误！${C_RED}命令执行失败，退出码 $exit_code。${C_RESET}" >&2
            return $exit_code
        fi
    else
        echo -e "${C_YELLOW}已取消。${C_RESET}" >&2
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
_install_script() {
    echo -e "${C_BOLD}开始安装 fuckits...${C_RESET}"
    mkdir -p "$INSTALL_DIR"
    
    # 把核心逻辑写进 main.sh
    echo "$CORE_LOGIC" > "$MAIN_SH"
    
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
        _fuck_secure_config_file
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
    # 临时模式
    # 运行核心逻辑，定义函数
    eval "$CORE_LOGIC"
    # 直接调用主函数 (别名在这儿不好使)
    _fuck_execute_prompt "$@"
else
    # 安装模式
    _install_script
fi
