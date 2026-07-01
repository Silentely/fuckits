#!/usr/bin/env bats
#
# Pollinations OAuth 功能测试
#

load '../../helpers/bats-helpers'

setup() {
    source ./main.sh
    export FUCK_SECURITY_MODE="balanced"
    # source runtime-common.sh to get _fuck_should_use_pollinations_api
    source ./scripts/runtime-common.sh

    # Ensure CONFIG_FILE directory exists (main.sh sets CONFIG_FILE=$HOME/.fuck/config.sh)
    mkdir -p "$(dirname "$CONFIG_FILE")"
    # Pre-create empty CONFIG_FILE to avoid _fuck_seed_config_placeholders bracket bug
    touch "$CONFIG_FILE"
}

teardown() {
    unset FUCK_OPENAI_API_KEY
    unset FUCK_OPENAI_API_BASE
    unset FUCK_POLLINATIONS_CLIENT_ID
    # Remove test config file if we created one
    rm -f "$CONFIG_FILE"
}

# ==================== OAuth 状态查询 ====================

@test "OAuth: status 无 key 时提示未配置" {
    unset FUCK_OPENAI_API_KEY
    unset FUCK_OPENAI_API_BASE
    run _fuck_pollinations_status
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "No API Key"
}

@test "OAuth: status 有普通 key 时显示本地 API" {
    export FUCK_OPENAI_API_KEY="sk-proj-abc123"
    export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"
    run _fuck_pollinations_status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Local API Key"
}

# ==================== OAuth 登出 ====================

@test "OAuth: logout 无配置文件时提示" {
    unset FUCK_OPENAI_API_KEY
    unset FUCK_OPENAI_API_BASE
    rm -f "$CONFIG_FILE"
    run _fuck_pollinations_logout
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Config file not found"
}

@test "OAuth: logout 非 Pollinations 配置时提示" {
    export FUCK_OPENAI_API_KEY="sk-proj-abc123"
    export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"
    cat > "$CONFIG_FILE" <<'EOF'
export FUCK_OPENAI_API_KEY="sk-proj-abc123"
export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"
EOF
    run _fuck_pollinations_logout
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Not using Pollinations"
}

@test "OAuth: logout 清除 Pollinations 配置" {
    export FUCK_OPENAI_API_KEY="sk_test_abc123"
    export FUCK_OPENAI_API_BASE="https://gen.pollinations.ai/v1"
    cat > "$CONFIG_FILE" <<'EOF'
export FUCK_OPENAI_API_KEY="sk_test_abc123"
export FUCK_OPENAI_API_BASE="https://gen.pollinations.ai/v1"
EOF
    run _fuck_pollinations_logout
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "cleared"
    # Verify config file no longer contains Pollinations lines
    ! grep -q 'gen.pollinations.ai' "$CONFIG_FILE"
}

# ==================== 凭据保存 ====================

@test "OAuth: save_credentials 创建配置文件" {
    rm -f "$CONFIG_FILE"
    run _fuck_pollinations_save_credentials "sk_test_token_123"
    [ "$status" -eq 0 ]
    [ -f "$CONFIG_FILE" ]
    grep -q 'FUCK_OPENAI_API_KEY="sk_test_token_123"' "$CONFIG_FILE"
    grep -q 'FUCK_OPENAI_API_BASE="https://gen.pollinations.ai/v1"' "$CONFIG_FILE"
}

@test "OAuth: save_credentials 设置环境变量" {
    rm -f "$CONFIG_FILE"
    _fuck_pollinations_save_credentials "sk_test_token_456"
    [ "$FUCK_OPENAI_API_KEY" = "sk_test_token_456" ]
    [ "$FUCK_OPENAI_API_BASE" = "https://gen.pollinations.ai/v1" ]
}

@test "OAuth: save_credentials 覆盖旧配置" {
    cat > "$CONFIG_FILE" <<'EOF'
# Old config
export FUCK_OPENAI_API_KEY="sk_old_key"
export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"
EOF
    _fuck_pollinations_save_credentials "sk_new_token_789"
    [ "$FUCK_OPENAI_API_KEY" = "sk_new_token_789" ]
    ! grep -q 'sk_old_key' "$CONFIG_FILE"
    grep -q 'sk_new_token_789' "$CONFIG_FILE"
}

# ==================== API 检测 ====================

@test "OAuth: _should_use_local_api 检测 Pollinations key" {
    export FUCK_OPENAI_API_KEY="sk_test_abc"
    export FUCK_OPENAI_API_BASE="https://gen.pollinations.ai/v1"
    run _fuck_should_use_local_api
    [ "$status" -eq 0 ]
}

@test "OAuth: _should_use_local_api 检测普通 key" {
    export FUCK_OPENAI_API_KEY="sk-proj-abc"
    export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"
    run _fuck_should_use_local_api
    [ "$status" -eq 0 ]
}

@test "OAuth: _should_use_local_api 拒绝无 key" {
    unset FUCK_OPENAI_API_KEY
    run _fuck_should_use_local_api
    [ "$status" -eq 1 ]
}

# ==================== Device Flow 错误处理 ====================

@test "OAuth: device_flow 处理网络错误" {
    _POLLINATIONS_DEVICE_API="https://invalid.example.com/api/device"
    run _fuck_pollinations_device_flow
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "Failed to connect\|连接"
}

@test "OAuth: device_flow 处理无效响应" {
    _POLLINATIONS_DEVICE_API="https://httpbin.org/status/400"
    run _fuck_pollinations_device_flow
    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "Invalid response\|无效响应\|Failed to connect\|连接"
}
