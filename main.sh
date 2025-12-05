#!/bin/bash
#
# This script is the installer and temporary runner for fuckit.sh
#
# --- RECOMMENDED SECURE USAGE ---
#
# 1. Download:
#    curl -o fuckit.sh https://fuckits.25500552.xyz
#
# 2. Inspect:
#    less fuckit.sh
#
# 3. Run (Install):
#    bash fuckit.sh
#
# 4. Run (Temporary):
#    bash fuckit.sh "your prompt"
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

# --- Begin Core Logic for fuckit.sh ---

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

    # --- Configuration ---
    if [ -z "${HOME:-}" ]; then
        # This part is for the temporary runner, which doesn't install,
        # but we need the variables defined to avoid unbound errors.
        # The install check will happen in the installer part of the script.
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

readonly DEFAULT_API_ENDPOINT="https://fuckits.25500552.xyz/"

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
_fuck_ensure_config_exists() {
    if [ -f "$CONFIG_FILE" ]; then
        return
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat <<'CFG' > "$CONFIG_FILE"
# fuckit.sh configuration
# Toggle the exports below to customise your experience.

# Custom API endpoint that points to your self-hosted worker
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

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
}

_fuck_show_config_help() {
    _fuck_ensure_config_exists
    echo -e "${C_YELLOW}Configuration file:${C_RESET} ${C_CYAN}$CONFIG_FILE${C_RESET}"
    if [ -n "${EDITOR:-}" ]; then
        echo -e "${C_YELLOW}Edit with:${C_RESET} ${C_CYAN}${EDITOR} \"$CONFIG_FILE\"${C_RESET}"
    else
        echo -e "${C_YELLOW}Open this file in your favourite editor to customise fuckit.sh.${C_RESET}"
    fi
    echo -e "${C_CYAN}Available toggles:${C_RESET} FUCK_API_ENDPOINT, FUCK_ALIAS, FUCK_AUTO_EXEC, FUCK_TIMEOUT, FUCK_DEBUG"
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
            sed -i.bak "|$source_line|d" "$profile_file"
            sed -i.bak "|# Added by fuckit.sh installer|d" "$profile_file"
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
    
    local escaped_prompt
    escaped_prompt=$(_fuck_json_escape "$prompt")
    
    local escaped_sysinfo
    escaped_sysinfo=$(_fuck_json_escape "$sysinfo_string")

    # Construct the JSON payload
    local payload
    payload=$(printf '{ "sysinfo": "%s", "prompt": "%s" }' "$escaped_sysinfo" "$escaped_prompt")

    # Use configured API endpoint or default
    local api_url="${FUCK_API_ENDPOINT:-$DEFAULT_API_ENDPOINT}"

    _fuck_debug "API URL: $api_url"
    _fuck_debug "Payload: $payload"

    echo -ne "${C_YELLOW}Thinking...${C_RESET}"
    
    local tmp_response
    tmp_response=$(mktemp)
    
    # Call API in background
    (
        curl -sS --max-time "$curl_timeout" -X POST "$api_url" \
            -H "Content-Type: application/json" \
            -d "$payload" > "$tmp_response" 2>&1
    ) &    local pid=$!
    
    _fuck_spinner "$pid"
    if wait "$pid"; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    echo "" # Newline after spinner

    local response
    if [ -f "$tmp_response" ]; then
        response=$(cat "$tmp_response")
        rm -f "$tmp_response"
    else
        response=""
    fi

    if [ $exit_code -ne 0 ] || [ -z "$response" ]; then
        echo -e "$FUCK ${C_RED}Couldn't reach the AI service or got empty response.${C_RESET}" >&2
        [ -n "$response" ] && echo -e "${C_DIM}$response${C_RESET}" >&2
        return 1
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
# fuckit.sh configuration
# Toggle the exports below to customise your experience.

# Custom API endpoint that points to your self-hosted worker
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# Skip confirmation prompts (use with caution!)
# export FUCK_AUTO_EXEC=0

# Override curl timeout (seconds)
# export FUCK_TIMEOUT=30

# Enable verbose debug logs
# export FUCK_DEBUG=0
CFG
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
        echo "# Added by fuckit.sh installer" >> "$profile_file"
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