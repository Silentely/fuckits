#!/usr/bin/env bats
#
# help 和 update 子命令测试
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
    unset -f curl 2>/dev/null || true
}

# ==================== Help 命令测试 ====================

@test "Help: fuck --help should display usage information" {
    run _fuck_execute_prompt --help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"config"* ]]
    [[ "${output}" == *"history"* ]]
    [[ "${output}" == *"favorite"* ]]
    [[ "${output}" == *"uninstall"* ]]
    [[ "${output}" == *"version"* ]]
    [[ "${output}" == *"update"* ]]
}

@test "Help: --help with --json should return valid JSON with required fields" {
    run _fuck_execute_prompt --json --help
    [ "$status" -eq 0 ]
    # 验证 JSON 结构：必须包含 status、schema_version、commands
    [[ "${output}" == *'"status":"ok"'* ]]
    [[ "${output}" == *'"schema_version"'* ]]
    [[ "${output}" == *'"commands"'* ]]
    [[ "${output}" == *'"name":"--help"'* ]]
    [[ "${output}" == *'"name":"--config"'* ]]
    [[ "${output}" == *'"name":"--update"'* ]]
}

# ==================== Update 命令测试 ====================

@test "Update: should fail when main.sh does not exist" {
    # MAIN_SH 指向的文件在 setup() 中未创建，模拟未安装
    run _fuck_update_script
    [ "$status" -ne 0 ]
    [[ "${output}" == *"not installed"* ]] || [[ "${output}" == *"尚未安装"* ]]
}

@test "Update: should report up to date when version matches" {
    # 创建模拟已安装环境
    local fake_main="$INSTALL_DIR/main.sh"
    echo "SCRIPT_VERSION='99.99.99'" > "$fake_main"
    chmod +x "$fake_main"

    # Mock curl 返回相同版本
    curl() {
        echo '{"version":"99.99.99"}'
    }
    export -f curl

    run _fuck_update_script

    unset -f curl 2>/dev/null || true

    [ "$status" -eq 0 ]
    [[ "${output}" == *"up to date"* ]] || [[ "${output}" == *"已是最新"* ]]
}

@test "Update: --json flag should return JSON output" {
    local fake_main="$INSTALL_DIR/main.sh"
    echo "SCRIPT_VERSION='99.99.99'" > "$fake_main"
    chmod +x "$fake_main"

    curl() {
        echo '{"version":"99.99.99"}'
    }
    export -f curl

    export _FUCK_JSON_MODE=1
    run _fuck_update_script

    unset -f curl 2>/dev/null || true

    [ "$status" -eq 0 ]
    # 验证输出包含 JSON 标记
    [[ "${output}" == *'"status":"ok"'* ]] || [[ "${output}" == *'"status": "ok"'* ]]
}

@test "Update: should fail when remote version check fails" {
    local fake_main="$INSTALL_DIR/main.sh"
    echo "SCRIPT_VERSION='1.0.0'" > "$fake_main"
    chmod +x "$fake_main"

    # Mock curl 返回空（模拟网络失败）
    curl() {
        return 1
    }
    export -f curl

    run _fuck_update_script
    [ "$status" -ne 0 ]
    [[ "${output}" == *"Failed"* ]] || [[ "${output}" == *"失败"* ]]
}

@test "Update: should fail when remote returns invalid response" {
    local fake_main="$INSTALL_DIR/main.sh"
    echo "SCRIPT_VERSION='1.0.0'" > "$fake_main"
    chmod +x "$fake_main"

    # Mock curl 返回非 JSON 内容
    curl() {
        echo "<html>Error</html>"
    }
    export -f curl

    run _fuck_update_script
    [ "$status" -ne 0 ]
}

# ==================== zh_main.sh 测试 ====================

@test "zh_main Help: fuck --help should display Chinese usage information" {
    # 在子进程中 source zh_main.sh，传 --help 参数走 execute 路径
    # 避免与 main.sh 的 readonly 变量冲突
    run bash -c '
        export HOME="'"$TEST_HOME"'"
        source ./zh_main.sh --help
    '
    [ "$status" -eq 0 ]
    # 应包含中文
    [[ "${output}" == *"可用命令"* ]] || [[ "${output}" == *"帮助"* ]]
}

@test "zh_main Update: should fail when not installed" {
    # 在子进程中 source zh_main.sh，它会检测到 BATS 环境并提前返回
    # 然后手动调用 _fuck_update_script
    run bash -c '
        export HOME="'"$TEST_HOME"'"
        source ./zh_main.sh
        type _fuck_update_script >/dev/null 2>&1
        _fuck_update_script
    '
    [ "$status" -ne 0 ]
}
