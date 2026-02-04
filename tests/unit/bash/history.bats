#!/usr/bin/env bats
#
# Task 1.4: Command History and Favorites Tests
# Tests for history logging, viewing, searching, replay, and favorites management
#

load '../../helpers/bats-helpers'

# Test environment setup
setup() {
    # Create isolated test environment
    export TEST_HOME=$(mktemp -d)

    # IMPORTANT: Set HOME before sourcing main.sh
    # This allows main.sh to set readonly INSTALL_DIR correctly
    export HOME="$TEST_HOME"

    # Source main.sh (will detect BATS environment and return early)
    source ./main.sh

    # Create install directory
    mkdir -p "$INSTALL_DIR"
}

# Cleanup after each test
teardown() {
    rm -rf "$TEST_HOME"
    unset TEST_HOME
    # Don't unset INSTALL_DIR - it's readonly
}

# ==================== History File Initialization ====================

@test "History Init: should create history.json with correct structure" {
    local history_file="$INSTALL_DIR/history.json"

    run _fuck_init_history_file "$history_file"

    [ "$status" -eq 0 ]
    [ -f "$history_file" ]

    # Check file permissions (600)
    # macOS: stat -f "%OLp" returns "600"
    # Linux: stat -c "%a" may return "600" or "0600"
    local perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f "%OLp" "$history_file")
    else
        perms=$(stat -c "%a" "$history_file")
    fi
    # Strip leading zeros for comparison
    perms=$(echo "$perms" | sed 's/^0*//')
    [ "$perms" = "600" ]

    # Check JSON structure
    grep -q '"version": "1.0.0"' "$history_file"
    grep -q '"commands": \[\]' "$history_file"
    grep -q '"favorites": \[\]' "$history_file"
}

@test "History Init: should not overwrite existing history file" {
    local history_file="$INSTALL_DIR/history.json"

    # Create existing file with custom data
    cat > "$history_file" <<'EOF'
{
  "version": "1.0.0",
  "commands": [{"test": "data"}],
  "favorites": []
}
EOF

    run _fuck_init_history_file "$history_file"

    [ "$status" -eq 0 ]
    grep -q '"test": "data"' "$history_file"
}

# ==================== JQ Dependency Check ====================

@test "JQ Check: should pass if jq is installed" {
    # Skip if jq is not actually installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    run _fuck_check_jq
    [ "$status" -eq 0 ]
}

@test "JQ Check: should fail with helpful message if jq is missing" {
    # Mock command -v to simulate jq not being available
    # This works reliably across all environments without needing sudo
    run bash -c '
        # Override command builtin to simulate jq missing
        command() {
            if [[ "$1" == "-v" && "$2" == "jq" ]]; then
                return 1
            fi
            builtin command "$@"
        }
        export -f command
        source ./main.sh
        _fuck_check_jq
    '

    [ "$status" -eq 1 ]
    echo "$output" | grep -q "jq.*required"
}

# ==================== History Logging ====================

@test "History Log: should record command execution" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_log_history "install git" "apt install git" 0 5

    [ "$status" -eq 0 ]

    # Verify entry was added
    local count=$(jq '.commands | length' "$history_file")
    [ "$count" -eq 1 ]

    # Verify entry content
    jq -e '.commands[0].prompt == "install git"' "$history_file"
    jq -e '.commands[0].command == "apt install git"' "$history_file"
    jq -e '.commands[0].exitCode == 0' "$history_file"
    jq -e '.commands[0].duration == 5' "$history_file"
}

@test "History Log: should limit to 1000 commands" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    # Create a file with 1000 commands
    jq '.commands = [range(1000) | {prompt: "test", command: "echo", exitCode: 0, duration: 1, timestamp: "2024-01-01T00:00:00Z"}]' "$history_file" > "${history_file}.tmp"
    mv "${history_file}.tmp" "$history_file"

    # Add one more
    run _fuck_log_history "new command" "echo new" 0 1

    [ "$status" -eq 0 ]

    # Should still be 1000
    local count=$(jq '.commands | length' "$history_file")
    [ "$count" -eq 1000 ]

    # Newest should be at the end
    jq -e '.commands[-1].prompt == "new command"' "$history_file"
}

# ==================== History Viewing ====================

@test "History View: should display last N commands" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    # Add some test commands
    _fuck_log_history "test 1" "echo 1" 0 1
    _fuck_log_history "test 2" "echo 2" 0 2
    _fuck_log_history "test 3" "echo 3" 1 3

    run _fuck_history 2

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "test 2"
    echo "$output" | grep -q "test 3"
}

@test "History View: should show empty message when no history" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_history

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No command history"
}

# ==================== History Search ====================

@test "History Search: should find matching commands" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    _fuck_log_history "install git" "apt install git" 0 1
    _fuck_log_history "install nginx" "apt install nginx" 0 1
    _fuck_log_history "remove git" "apt remove git" 0 1

    run _fuck_history_search "install"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "install git"
    echo "$output" | grep -q "install nginx"
    ! echo "$output" | grep -q "remove git"
}

@test "History Search: should show message when no matches" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    _fuck_log_history "install git" "apt install git" 0 1

    run _fuck_history_search "nonexistent"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No matching commands"
}

# ==================== Favorite Management ====================

@test "Favorite Add: should require name and prompt" {
    # Redirect stderr to stdout to capture error messages
    run bash -c "export BATS_TEST_DIRNAME=/fake && export HOME='$TEST_HOME' && source ./main.sh && _fuck_favorite_add 2>&1"

    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

@test "Favorite List: should show empty message when no favorites" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_favorite_list

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No favorites yet"
}

@test "Favorite Run: should require index parameter" {
    run _fuck_favorite_run

    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

@test "Favorite Delete: should require index parameter" {
    run _fuck_favorite_delete

    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

# ==================== Command Routing ====================

@test "Routing: 'fuck history' should call _fuck_history" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_execute_prompt history

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No command history\|Recent commands"
}

@test "Routing: 'fuck history search' should call _fuck_history_search" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_execute_prompt history search test

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No matching commands\|Matching commands"
}

@test "Routing: 'fuck favorite' should show usage" {
    # Capture both stdout and stderr
    run bash -c "export BATS_TEST_DIRNAME=/fake && export HOME='$TEST_HOME' && source ./main.sh && _fuck_execute_prompt favorite 2>&1"

    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage.*favorite"
}

@test "Routing: 'fuck fav list' should work as alias" {
    # Skip if jq is not installed
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_execute_prompt fav list

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No favorites yet\|Favorite Commands"
}
