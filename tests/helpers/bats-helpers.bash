#!/usr/bin/env bash
#
# Bats 测试辅助函数
# 专门用于 fuckits 项目的测试工具
#

# 辅助函数：提取安全引擎评估结果
# 输入：_fuck_security_evaluate_command 的输出 "severity|reason"
# 输出：severity 或 reason
extract_severity() {
    local result="$1"
    echo "${result%%|*}"
}

extract_reason() {
    local result="$1"
    echo "${result#*|}"
}

# 辅助函数：模拟危险命令并验证安全检测
# 用法：test_security_rule "rm -rf /" "block" "Recursive delete"
test_security_rule() {
    local command="$1"
    local expected_severity="$2"
    local expected_reason_pattern="$3"

    local result severity reason
    result=$(_fuck_security_evaluate_command "$command")
    severity=$(extract_severity "$result")
    reason=$(extract_reason "$result")

    # 验证严重性级别
    if [ "$severity" != "$expected_severity" ]; then
        echo "Security check failed for: $command"
        echo "Expected severity: $expected_severity"
        echo "Actual severity: $severity"
        echo "Reason: $reason"
        return 1
    fi

    # 验证原因包含预期模式
    if ! echo "$reason" | grep -qi "$expected_reason_pattern"; then
        echo "Reason doesn't match pattern for: $command"
        echo "Expected pattern: $expected_reason_pattern"
        echo "Actual reason: $reason"
        return 1
    fi

    return 0
}

# 辅助函数：测试安全模式切换
test_security_mode() {
    local mode="$1"
    export FUCK_SECURITY_MODE="$mode"
    local result
    result=$(_fuck_security_mode)

    if [ "$result" != "$mode" ]; then
        echo "Security mode mismatch"
        echo "Expected: $mode"
        echo "Actual: $result"
        return 1
    fi

    return 0
}

# 辅助函数：创建测试白名单
create_test_whitelist() {
    export FUCK_SECURITY_WHITELIST="$1"
}

# 辅助函数：清除测试白名单
clear_test_whitelist() {
    unset FUCK_SECURITY_WHITELIST
}

# 辅助函数：验证配置文件权限
verify_config_permissions() {
    local config_file="$1"
    local perms

    if [ ! -f "$config_file" ]; then
        echo "Config file not found: $config_file"
        return 1
    fi

    perms=$(stat -c '%a' "$config_file" 2>/dev/null || stat -f '%A' "$config_file" 2>/dev/null)

    if [ "$perms" != "600" ]; then
        echo "Config file has wrong permissions: $perms (expected 600)"
        return 1
    fi

    return 0
}

# 辅助函数：模拟系统信息收集
mock_system_info() {
    _fuck_collect_sysinfo_string() {
        echo "OS=TestOS; PkgMgr=test"
    }
    export -f _fuck_collect_sysinfo_string
}

# 辅助函数：验证 JSON 格式
validate_json() {
    local json="$1"

    if command -v python3 >/dev/null 2>&1; then
        echo "$json" | python3 -m json.tool >/dev/null 2>&1
        return $?
    elif command -v node >/dev/null 2>&1; then
        echo "$json" | node -e "JSON.parse(require('fs').readFileSync(0, 'utf-8'))" >/dev/null 2>&1
        return $?
    else
        echo "No JSON validator available (python3 or node required)"
        return 1
    fi
}

# 辅助函数：生成测试 base64 字符串
generate_test_base64() {
    local content="$1"
    echo -n "$content" | base64
}

# 辅助函数：验证 base64 解码
verify_base64_decode() {
    local encoded="$1"
    local expected="$2"
    local decoded

    decoded=$(echo "$encoded" | base64 -d 2>/dev/null || echo "$encoded" | base64 -D 2>/dev/null)

    if [ "$decoded" != "$expected" ]; then
        echo "Base64 decode mismatch"
        echo "Expected: $expected"
        echo "Actual: $decoded"
        return 1
    fi

    return 0
}
