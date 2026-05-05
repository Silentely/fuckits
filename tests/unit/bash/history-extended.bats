#!/usr/bin/env bats
#
# Extended History & Favorite Tests
# 覆盖 _fuck_history_replay、_fuck_favorite_run、_fuck_favorite_delete
#

load '../../helpers/bats-helpers'

setup() {
    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    source ./main.sh
    mkdir -p "$INSTALL_DIR"
}

teardown() {
    rm -rf "$TEST_HOME"
    unset TEST_HOME
}

# ==================== history_replay ====================

@test "History Replay: should fail without index" {
    run _fuck_history_replay
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

@test "History Replay: should fail with non-numeric index" {
    run _fuck_history_replay "abc"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "invalid"
}

@test "History Replay: should fail with zero index" {
    run _fuck_history_replay "0"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "invalid"
}

@test "History Replay: should fail with negative index" {
    run _fuck_history_replay "-1"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "invalid"
}

@test "History Replay: should fail when history file missing" {
    run _fuck_history_replay "1"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "No command history"
}

@test "History Replay: should fail for out-of-range index" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"
    _fuck_log_history "test" "echo hello" 0 1

    run _fuck_history_replay "999"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "not found"
}

@test "History Replay: should display the command for valid index" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"
    _fuck_log_history "test" "echo hello" 0 1

    run _fuck_history_replay "1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "echo hello"
}

# ==================== favorite_run ====================

@test "Favorite Run: should fail without index" {
    run _fuck_favorite_run
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

@test "Favorite Run: should fail with non-numeric index" {
    run _fuck_favorite_run "abc"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "invalid"
}

@test "Favorite Run: should fail with zero index" {
    run _fuck_favorite_run "0"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "invalid"
}

@test "Favorite Run: should fail when history file missing" {
    run _fuck_favorite_run "1"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "No favorites"
}

@test "Favorite Run: should fail for out-of-range index" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_favorite_run "999"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "not found"
}

@test "Favorite Run: should execute a valid favorite" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    # 直接注入一条收藏记录（跳过 AI 调用）
    local entry
    entry=$(jq -n \
        --arg id "test_fav_1" \
        --arg name "Test Echo" \
        --arg prompt "say hello" \
        --arg command "echo hello_from_fav" \
        --arg created "2026-01-01T00:00:00Z" \
        '{id: $id, name: $name, prompt: $prompt, command: $command, created: $created}')

    jq ".favorites += [$entry]" "$history_file" > "${history_file}.tmp"
    command mv -f -- "${history_file}.tmp" "$history_file"

    run _fuck_favorite_run "1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "hello_from_fav"
}

# ==================== favorite_delete ====================

@test "Favorite Delete: should fail without index" {
    run _fuck_favorite_delete
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

@test "Favorite Delete: should fail when history file missing" {
    run _fuck_favorite_delete "1"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "No favorites"
}

@test "Favorite Delete: should fail for out-of-range index" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_favorite_delete "999"
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "not found"
}

@test "Favorite Delete: should delete a valid favorite" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    # 注入两条收藏
    local entry1 entry2
    entry1=$(jq -n --arg id "f1" --arg name "Fav1" --arg prompt "p1" --arg command "echo 1" --arg created "2026-01-01T00:00:00Z" '{id: $id, name: $name, prompt: $prompt, command: $command, created: $created}')
    entry2=$(jq -n --arg id "f2" --arg name "Fav2" --arg prompt "p2" --arg command "echo 2" --arg created "2026-01-01T00:00:00Z" '{id: $id, name: $name, prompt: $prompt, command: $command, created: $created}')

    jq ".favorites += [$entry1, $entry2]" "$history_file" > "${history_file}.tmp"
    command mv -f -- "${history_file}.tmp" "$history_file"

    # 删除第一条
    run _fuck_favorite_delete "1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "deleted"

    # 验证只剩一条
    local count=$(jq '.favorites | length' "$history_file")
    [ "$count" -eq 1 ]

    # 验证剩余的是 Fav2
    local remaining_name=$(jq -r '.favorites[0].name' "$history_file")
    [ "$remaining_name" = "Fav2" ]
}

@test "Favorite Delete: should show remaining favorites after deletion" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    local entry
    entry=$(jq -n --arg id "f1" --arg name "ToDelete" --arg prompt "p" --arg command "echo x" --arg created "2026-01-01T00:00:00Z" '{id: $id, name: $name, prompt: $prompt, command: $command, created: $created}')

    jq ".favorites += [$entry]" "$history_file" > "${history_file}.tmp"
    command mv -f -- "${history_file}.tmp" "$history_file"

    run _fuck_favorite_delete "1"
    [ "$status" -eq 0 ]

    # 再次列出应该为空
    run _fuck_favorite_list
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "No favorites yet"
}
