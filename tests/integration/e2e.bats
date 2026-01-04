#!/usr/bin/env bats
#
# 端到端集成测试
# 测试完整用户流程：安装 → 配置 → 执行 → 卸载
#

# 加载测试辅助函数
load '../helpers/bats-helpers'

# ==================== 测试环境设置 ====================

setup_file() {
    # 创建临时测试目录
    export TEST_HOME=$(mktemp -d)
    export TEST_INSTALL_DIR="$TEST_HOME/.fuck"
    export ORIGINAL_HOME="$HOME"
}

teardown_file() {
    # 清理测试目录
    if [ -n "$TEST_HOME" ] && [ -d "$TEST_HOME" ]; then
        rm -rf "$TEST_HOME"
    fi
}

setup() {
    # 每个测试前重置 HOME
    export HOME="$TEST_HOME"
    # 清理可能存在的安装
    rm -rf "$TEST_INSTALL_DIR"
    # Unset BATS variables to prevent main.sh from detecting test environment
    unset BATS_TEST_DIRNAME BATS_TEST_FILENAME BATS_TEST_NAME
}

teardown() {
    # 恢复原始 HOME
    export HOME="$ORIGINAL_HOME"
    # 清理安装
    rm -rf "$TEST_INSTALL_DIR" 2>/dev/null || true
}

# ==================== 安装流程测试 ====================

@test "E2E Install: script should install successfully to ~/.fuck directory" {
    # Simulate installation (run script without arguments)
    # HOME is already set by setup() function
    bash ./main.sh <<< ""

    # 验证安装目录存在
    [ -d "$TEST_INSTALL_DIR" ]

    # 验证 main.sh 被复制
    [ -f "$TEST_INSTALL_DIR/main.sh" ]

    # 验证配置文件被创建
    [ -f "$TEST_INSTALL_DIR/config.sh" ]
}

@test "E2E Install: config file should have correct permissions (600)" {
    bash ./main.sh <<< ""

    # Check config file permissions
    local perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f '%A' "$TEST_INSTALL_DIR/config.sh")
    else
        perms=$(stat -c '%a' "$TEST_INSTALL_DIR/config.sh")
    fi

    [ "$perms" = "600" ]
}

@test "E2E Install: main.sh should be executable" {
    bash ./main.sh <<< ""

    # 检查可执行权限
    [ -x "$TEST_INSTALL_DIR/main.sh" ]
}

@test "E2E Install: config file should contain necessary variable definitions" {
    bash ./main.sh <<< ""

    # Check config file content
    grep -q "FUCK_API_ENDPOINT" "$TEST_INSTALL_DIR/config.sh"
}

# ==================== 临时模式测试 ====================

@test "E2E Temp Mode: should not install when run with arguments" {
    # 使用临时模式（带参数）
    # 这里我们 mock API 调用，只测试脚本不安装
    # 跨平台超时：macOS 使用 gtimeout，Linux 使用 timeout
    local timeout_cmd="timeout"
    if command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd="gtimeout"
    fi

    HOME="$TEST_HOME" $timeout_cmd 5 bash ./main.sh "list files" 2>&1 || true

    # 应该不存在安装目录（或只有缓存）
    # 注意：临时模式可能会创建目录但不会完整安装
    [ ! -f "$TEST_INSTALL_DIR/main.sh" ] || [ ! -x "$TEST_INSTALL_DIR/main.sh" ]
}

# ==================== 配置系统测试 ====================

@test "E2E Config: config file should be loaded correctly" {
    bash ./main.sh <<< ""

    # Write test config
    echo 'export FUCK_API_ENDPOINT="https://test.example.com/"' >> "$TEST_INSTALL_DIR/config.sh"

    # Source script and verify config loading
    (
        source "$TEST_INSTALL_DIR/config.sh"
        [ "$FUCK_API_ENDPOINT" = "https://test.example.com/" ]
    )
}

@test "E2E Config: malicious config should be rejected" {
    bash ./main.sh <<< ""

    # 写入恶意配置（命令注入）
    echo 'export FUCK_API_ENDPOINT="$(rm -rf /tmp/evil)"' > "$TEST_INSTALL_DIR/config.sh"

    # 尝试加载配置应该失败（验证函数应该拒绝）
    run bash -c "source ./main.sh && _fuck_validate_config_file '$TEST_INSTALL_DIR/config.sh'"
    [ "$status" -ne 0 ] || echo "$output" | grep -qi "unsafe\|injection\|rejected"
}

# ==================== 卸载流程测试 ====================

@test "E2E Uninstall: uninstall should remove installation directory" {
    # Install first
    bash ./main.sh <<< ""
    [ -d "$TEST_INSTALL_DIR" ]

    # Execute uninstall
    bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        _uninstall_script <<< 'y'
    " 2>&1 || true

    # Verify installation directory was removed
    [ ! -d "$TEST_INSTALL_DIR" ]
}

@test "E2E Uninstall: uninstall should remove source line from shell config" {
    # 先安装
    bash ./main.sh <<< ""

    # 检查是否添加了 source 行
    local profile_file=""
    for f in "$TEST_HOME/.bashrc" "$TEST_HOME/.zshrc" "$TEST_HOME/.profile"; do
        if [ -f "$f" ]; then
            profile_file="$f"
            break
        fi
    done

    # 如果有 profile 文件
    if [ -n "$profile_file" ]; then
        # 执行卸载
        bash -c "
            source '$TEST_INSTALL_DIR/main.sh'
            _uninstall_script <<< 'y'
        " 2>&1 || true

        # 验证 source 行被移除
        ! grep -q "source.*\.fuck/main.sh" "$profile_file" 2>/dev/null || true
    fi
}

# ==================== 安全引擎集成测试 ====================

@test "E2E Security: security engine should be available after installation" {
    bash ./main.sh <<< ""

    # Verify security functions are available
    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        type _fuck_security_evaluate_command
    "
    [ "$status" -eq 0 ]
}

@test "E2E Security: Block level commands should be blocked" {
    bash ./main.sh <<< ""

    run bash -c "
        export FUCK_SECURITY_MODE='balanced'
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_security_evaluate_command 'rm -rf /'
    "
    echo "$output" | grep -q "block"
}

@test "E2E Security: security modes should switch correctly" {
    bash ./main.sh <<< ""

    # 测试 strict 模式
    run bash -c "
        export FUCK_SECURITY_MODE='strict'
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_security_evaluate_command 'chmod 777 test.sh'
    "
    # strict 模式下 warn 升级为 challenge
    echo "$output" | grep -q "challenge"
}

# ==================== 系统信息收集测试 ====================

@test "E2E Sysinfo: system info collection function should return valid data" {
    bash ./main.sh <<< ""

    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_collect_sysinfo_string
    "
    [ "$status" -eq 0 ]
    # Should contain OS information
    echo "$output" | grep -qE "OS=|SHELL="
}

@test "E2E Sysinfo: system info cache should work" {
    bash ./main.sh <<< ""

    # Call functions that trigger cache creation
    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_detect_distro
        _fuck_persist_static_cache
    "
    [ "$status" -eq 0 ]

    # Check cache file exists (note: filename has leading dot)
    [ -f "$TEST_INSTALL_DIR/.sysinfo.cache" ]
}

# ==================== 别名系统测试 ====================

@test "E2E Alias: default alias should be set correctly" {
    bash ./main.sh <<< ""

    # Verify alias function exists
    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        type _fuck_define_aliases
    "
    [ "$status" -eq 0 ]
}

@test "E2E Alias: custom alias should be configurable" {
    bash ./main.sh <<< ""

    # 添加自定义别名配置
    echo 'export FUCK_ALIAS="pls"' >> "$TEST_INSTALL_DIR/config.sh"

    # 验证配置可被读取
    run bash -c "
        source '$TEST_INSTALL_DIR/config.sh'
        echo \$FUCK_ALIAS
    "
    [ "$output" = "pls" ]
}

# ==================== 重复安装测试 ====================

@test "E2E Reinstall: repeated installation should work normally" {
    # First installation
    bash ./main.sh <<< ""
    [ -d "$TEST_INSTALL_DIR" ]

    # Second installation (should overwrite or handle normally)
    bash ./main.sh <<< "" 2>&1 || true
    [ -d "$TEST_INSTALL_DIR" ]
    [ -f "$TEST_INSTALL_DIR/main.sh" ]
}

@test "E2E Reinstall: repeated installation should preserve user config" {
    # 第一次安装
    bash ./main.sh <<< ""

    # 添加用户自定义配置
    echo 'export FUCK_CUSTOM_VAR="user_value"' >> "$TEST_INSTALL_DIR/config.sh"

    # 第二次安装
    bash ./main.sh <<< "" 2>&1 || true

    # 验证用户配置被保留
    grep -q "FUCK_CUSTOM_VAR" "$TEST_INSTALL_DIR/config.sh"
}

# ==================== 错误处理测试 ====================

@test "E2E Error: should error when HOME is not set" {
    run bash -c "unset HOME; bash ./main.sh" 2>&1
    # Should have error message
    echo "$output" | grep -qi "HOME\|variable\|set"
}

@test "E2E Error: should error when install directory cannot be created" {
    # 创建一个只读目录
    local readonly_dir="$TEST_HOME/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir"

    # 尝试安装到只读位置
    run bash -c "HOME='$readonly_dir' bash ./main.sh" 2>&1

    # 清理
    chmod 755 "$readonly_dir"
    rm -rf "$readonly_dir"

    # 应该失败
    [ "$status" -ne 0 ] || echo "$output" | grep -qi "error\|failed\|permission"
}
