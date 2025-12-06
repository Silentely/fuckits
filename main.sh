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

# Load user configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

if [ -z "${DEFAULT_API_ENDPOINT+x}" ]; then
    readonly DEFAULT_API_ENDPOINT="https://fuckits.25500552.xyz/"
fi

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

# Detects the package manager
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

# Collects system info as a simple string
_fuck_collect_sysinfo_string() {
    local pkg_manager
    pkg_manager=$(_fuck_detect_pkg_manager)
    # The server-side LLM prompt will need to parse this string
    echo "OS: $(uname -s), Arch: $(uname -m), Shell: ${SHELL:-unknown}, PkgMgr: $pkg_manager, CWD: $(pwd)"
}

# Escapes a string for use in a JSON payload
_fuck_json_escape() {
    # Basic escape for quotes, backslashes, and control characters
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

    local model="${FUCK_OPENAI_API_MODEL:-gpt-4-turbo}"
    local api_base="${FUCK_OPENAI_API_BASE:-https://api.openai.com/v1}"
    api_base=${api_base%/}
    local api_url="$api_base/chat/completions"

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
    local delay=0.1
    local spinstr='|/-\'
    
    # Hide cursor
    tput civis 2>/dev/null || printf "\033[?25l"

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    
    # Show cursor
    tput cnorm 2>/dev/null || printf "\033[?25h"
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

    cat <<CFG >> "$CONFIG_FILE"

# $comment
$assignment
CFG
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
        echo -ne "${C_YELLOW}Thinking...${C_RESET} "
        response=$(_fuck_request_worker_model "$prompt" "$sysinfo_string" "$curl_timeout")
        exit_code=$?
    fi

    echo ""

    if [ $exit_code -ne 0 ] || [ -z "$response" ]; then
        return $exit_code
    fi

    # --- User Confirmation (as requested) ---
    echo -e "${C_CYAN}Here is what I came up with:${C_RESET}"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"
    echo -e "${C_GREEN}${response}${C_RESET}"
    echo -e "${C_DIM}----------------------------------------${C_RESET}"
    
    # Check if auto-exec mode is enabled
    local should_exec=false
    if _fuck_truthy "$auto_mode"; then
        echo -e "${C_YELLOW}⚡ Auto-exec enabled. Running...${C_RESET}"
        should_exec=true
    else
        # Interactive confirmation
        while true; do
            printf "${C_BOLD}Execute? [Y/n] ${C_RESET}"
            local confirmation
            if [ -r /dev/tty ]; then
                read -r -n 1 confirmation < /dev/tty
                echo "" # Newline
            else
                # Fallback for no TTY
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
                    # Loop again
                    ;;
            esac
        done
    fi

    if [ "$should_exec" = "true" ]; then
        # Execute the response from the server and check its exit code
        if eval "$response"; then
            echo -e "${C_GREEN}Done.${C_RESET}"
        else
            local exit_code=$?
            echo -e "$FUCK ${C_RED}Command failed with exit code $exit_code.${C_RESET}" >&2
            return $exit_code
        fi
    else
        echo -e "${C_YELLOW}Aborted.${C_RESET}" >&2
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
_install_script() {
    echo -e "$FCKN ${C_BOLD}Alright, let's get this shit installed...${C_RESET}"
    mkdir -p "$INSTALL_DIR"
    
    # Write the embedded core logic to the main.sh file
    echo "$CORE_LOGIC" > "$MAIN_SH"
    
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
        _fuck_secure_config_file
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

# If arguments are passed (e.g., "bash -s ...")
if [ "$#" -gt 0 ]; then
    # Temporary Mode
    # Evaluate the core logic to define functions in this shell
    eval "$CORE_LOGIC"
    # Call the main function directly (alias won't work here)
    _fuck_execute_prompt "$@"
else
    # Install Mode
    _install_script
fi
