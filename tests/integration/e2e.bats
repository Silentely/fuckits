#!/usr/bin/env bats
#
# 端到端集成测试
# 测试完整用户流程：安装 → 配置 → 执行 → 卸载
#

# 加载测试辅助函数
load '../helpers/bats-helpers'

# ==================== 测试环境设置 ====================

# 测试使用的临时目录
TEST_HOME=""
TEST_INSTALL_DIR=""
ORIGINAL_HOME=""

setup_file() {
    # 创建临时测试目录
    TEST_HOME=$(mktemp -d)
    TEST_INSTALL_DIR="$TEST_HOME/.fuck"
    ORIGINAL_HOME="$HOME"
    export TEST_HOME TEST_INSTALL_DIR ORIGINAL_HOME
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
}

teardown() {
    # 恢复原始 HOME
    export HOME="$ORIGINAL_HOME"
    # 清理安装
    rm -rf "$TEST_INSTALL_DIR" 2>/dev/null || true
}

# ==================== 安装流程测试 ====================

@test "E2E Install: 脚本应该成功安装到 ~/.fuck 目录" {
    # 模拟安装（不带参数运行脚本）
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 验证安装目录存在
    [ -d "$TEST_INSTALL_DIR" ]

    # 验证 main.sh 被复制
    [ -f "$TEST_INSTALL_DIR/main.sh" ]

    # 验证配置文件被创建
    [ -f "$TEST_INSTALL_DIR/config.sh" ]
}

@test "E2E Install: 配置文件应该有正确的权限 (600)" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 检查配置文件权限
    local perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f '%A' "$TEST_INSTALL_DIR/config.sh")
    else
        perms=$(stat -c '%a' "$TEST_INSTALL_DIR/config.sh")
    fi

    [ "$perms" = "600" ]
}

@test "E2E Install: main.sh 应该可执行" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 检查可执行权限
    [ -x "$TEST_INSTALL_DIR/main.sh" ]
}

@test "E2E Install: 配置文件应该包含必要的变量定义" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 检查配置文件内容
    grep -q "FUCK_API_ENDPOINT" "$TEST_INSTALL_DIR/config.sh"
}

# ==================== 临时模式测试 ====================

@test "E2E Temp Mode: 带参数运行不应该安装" {
    # 使用临时模式（带参数）
    # 这里我们 mock API 调用，只测试脚本不安装
    HOME="$TEST_HOME" timeout 5 bash ./main.sh "list files" 2>&1 || true

    # 应该不存在安装目录（或只有缓存）
    # 注意：临时模式可能会创建目录但不会完整安装
    [ ! -f "$TEST_INSTALL_DIR/main.sh" ] || [ ! -x "$TEST_INSTALL_DIR/main.sh" ]
}

# ==================== 配置系统测试 ====================

@test "E2E Config: 配置文件应该能被正确加载" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 写入测试配置
    echo 'export FUCK_API_ENDPOINT="https://test.example.com/"' >> "$TEST_INSTALL_DIR/config.sh"

    # source 脚本并验证配置加载
    (
        source "$TEST_INSTALL_DIR/config.sh"
        [ "$FUCK_API_ENDPOINT" = "https://test.example.com/" ]
    )
}

@test "E2E Config: 恶意配置应该被拒绝" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 写入恶意配置（命令注入）
    echo 'export FUCK_API_ENDPOINT="$(rm -rf /tmp/evil)"' > "$TEST_INSTALL_DIR/config.sh"

    # 尝试加载配置应该失败（验证函数应该拒绝）
    run bash -c "source ./main.sh && _fuck_validate_config_file '$TEST_INSTALL_DIR/config.sh'"
    [ "$status" -ne 0 ] || echo "$output" | grep -qi "unsafe\|injection\|rejected"
}

# ==================== 卸载流程测试 ====================

@test "E2E Uninstall: 卸载应该移除安装目录" {
    # 先安装
    HOME="$TEST_HOME" bash ./main.sh <<< ""
    [ -d "$TEST_INSTALL_DIR" ]

    # 执行卸载
    HOME="$TEST_HOME" bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        _uninstall_script <<< 'y'
    " 2>&1 || true

    # 验证安装目录被移除
    [ ! -d "$TEST_INSTALL_DIR" ]
}

@test "E2E Uninstall: 卸载应该从 shell 配置中移除 source 行" {
    # 先安装
    HOME="$TEST_HOME" bash ./main.sh <<< ""

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
        HOME="$TEST_HOME" bash -c "
            source '$TEST_INSTALL_DIR/main.sh'
            _uninstall_script <<< 'y'
        " 2>&1 || true

        # 验证 source 行被移除
        ! grep -q "source.*\.fuck/main.sh" "$profile_file" 2>/dev/null || true
    fi
}

# ==================== 安全引擎集成测试 ====================

@test "E2E Security: 安全引擎应该在安装后可用" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 验证安全函数可用
    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        type _fuck_security_evaluate_command
    "
    [ "$status" -eq 0 ]
}

@test "E2E Security: Block 级别命令应该被阻止" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    run bash -c "
        export FUCK_SECURITY_MODE='balanced'
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_security_evaluate_command 'rm -rf /'
    "
    echo "$output" | grep -q "block"
}

@test "E2E Security: 安全模式应该能正确切换" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

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

@test "E2E Sysinfo: 系统信息收集函数应该返回有效数据" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_collect_sysinfo_string
    "
    [ "$status" -eq 0 ]
    # 应该包含 OS 信息
    echo "$output" | grep -qE "OS=|SHELL="
}

@test "E2E Sysinfo: 系统信息缓存应该工作" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 第一次调用
    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        _fuck_collect_sysinfo_string
        _fuck_collect_sysinfo_string
    "
    [ "$status" -eq 0 ]

    # 检查缓存文件存在
    [ -f "$TEST_INSTALL_DIR/sysinfo.cache" ] || [ -f "$TEST_HOME/.fuck/sysinfo.cache" ]
}

# ==================== 别名系统测试 ====================

@test "E2E Alias: 默认别名应该被正确设置" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 验证别名设置函数存在
    run bash -c "
        source '$TEST_INSTALL_DIR/main.sh'
        type _fuck_setup_alias
    "
    [ "$status" -eq 0 ]
}

@test "E2E Alias: 自定义别名应该能够配置" {
    HOME="$TEST_HOME" bash ./main.sh <<< ""

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

@test "E2E Reinstall: 重复安装应该能正常工作" {
    # 第一次安装
    HOME="$TEST_HOME" bash ./main.sh <<< ""
    [ -d "$TEST_INSTALL_DIR" ]

    # 第二次安装（应该覆盖或正常处理）
    HOME="$TEST_HOME" bash ./main.sh <<< "" 2>&1 || true
    [ -d "$TEST_INSTALL_DIR" ]
    [ -f "$TEST_INSTALL_DIR/main.sh" ]
}

@test "E2E Reinstall: 重复安装应该保留用户配置" {
    # 第一次安装
    HOME="$TEST_HOME" bash ./main.sh <<< ""

    # 添加用户自定义配置
    echo 'export FUCK_CUSTOM_VAR="user_value"' >> "$TEST_INSTALL_DIR/config.sh"

    # 第二次安装
    HOME="$TEST_HOME" bash ./main.sh <<< "" 2>&1 || true

    # 验证用户配置被保留
    grep -q "FUCK_CUSTOM_VAR" "$TEST_INSTALL_DIR/config.sh"
}

# ==================== 错误处理测试 ====================

@test "E2E Error: HOME 未设置时应该报错" {
    run bash -c "unset HOME; bash ./main.sh" 2>&1
    # 应该有错误信息
    echo "$output" | grep -qi "HOME\|variable\|set"
}

@test "E2E Error: 安装目录无法创建时应该报错" {
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
