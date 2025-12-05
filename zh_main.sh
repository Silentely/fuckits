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
_fuck_ensure_config_exists() {
    if [ -f "$CONFIG_FILE" ]; then
        return
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat <<'CFG' > "$CONFIG_FILE"
# fuckits 配置文件示例
# 去掉行首的 # 并修改为你想要的值即可。

# 自定义 API 入口（如自建 Worker）
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# 额外别名（默认提供 fuck）
# export FUCK_ALIAS="运行"

# 自动执行返回的命令，跳过确认（谨慎开启）
# export FUCK_AUTO_EXEC=false

# 请求超时时间（秒）
# export FUCK_TIMEOUT=30

# 是否打印调试信息
# export FUCK_DEBUG=false

# 不再自动注入默认别名
# export FUCK_DISABLE_DEFAULT_ALIAS=false
CFG
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
    echo -e "${C_CYAN}可用选项：${C_RESET}FUCK_API_ENDPOINT, FUCK_ALIAS, FUCK_AUTO_EXEC, FUCK_TIMEOUT, FUCK_DEBUG"
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
    
    local escaped_prompt
    escaped_prompt=$(_fuck_json_escape "$prompt")
    
    local escaped_sysinfo
    escaped_sysinfo=$(_fuck_json_escape "$sysinfo_string")

    # 构建 JSON
    local payload
    payload=$(printf '{ "sysinfo": "%s", "prompt": "%s" }' "$escaped_sysinfo" "$escaped_prompt")

    # 使用配置的 API 地址或默认地址
    local api_url="${FUCK_API_ENDPOINT:-$DEFAULT_API_ENDPOINT}"

    _fuck_debug "----------------------------------------"
    _fuck_debug "API URL: $api_url"
    _fuck_debug "Payload: $payload"
    _fuck_debug "Timeout: $curl_timeout"

    echo -ne "${C_YELLOW}思考中...${C_RESET} "
    
    local tmp_response
    tmp_response=$(mktemp)
    
    # 保存当前的 shell 选项
    local old_opts="$-"
    # 如果开启了 monitor 模式 (m)，则临时关闭，防止后台任务结束时打印 job control 信息
    if [[ "$old_opts" == *"m"* ]]; then
        set +m
    fi

    # 后台执行 curl
    (
        curl -fsS --max-time "$curl_timeout" -X POST "$api_url" \
            -H "Content-Type: application/json" \
            -d "$payload" > "$tmp_response" 2>&1
    ) &
    local pid=$!
    
    _fuck_spinner "$pid"
    
    if wait "$pid"; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # 恢复 monitor 模式
    if [[ "$old_opts" == *"m"* ]]; then
        set -m
    fi
    
    echo "" # Newline
    
    local response
    if [ -f "$tmp_response" ]; then
        response=$(cat "$tmp_response")
        rm -f "$tmp_response"
    else
        response=""
    fi

    _fuck_debug "Exit Code: $exit_code"
    _fuck_debug "Response Raw:\n$response"
    _fuck_debug "----------------------------------------"

    if [ $exit_code -ne 0 ] || [ -z "$response" ]; then
        echo -e "$FUCK ${C_RED}无法连接到 AI 服务或无响应。${C_RESET}" >&2
        if _fuck_truthy "${FUCK_DEBUG:-0}"; then
            echo -e "${C_DIM}[DEBUG] 详细错误信息:${C_RESET}" >&2
            echo -e "${C_DIM}$response${C_RESET}" >&2
        elif [ -n "$response" ]; then
             echo -e "${C_DIM}错误详情: $response${C_RESET}" >&2
        fi
        return 1
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
# fuckits 配置文件示例
# 去掉行首的 # 并修改为你想要的值即可。

# 自定义 API 入口（如自建 Worker）
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# 自动执行返回的命令，跳过确认（谨慎开启）
# export FUCK_AUTO_EXEC=false

# 请求超时时间（秒）
# export FUCK_TIMEOUT=30

# 是否打印调试信息
# export FUCK_DEBUG=false
CFG
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
