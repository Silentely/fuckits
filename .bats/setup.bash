#!/usr/bin/env bash
#
# Bats 测试全局设置
# 用于 bash 脚本测试的通用配置和辅助函数
#
# 功能：
# - 设置测试环境变量
# - 提供通用测试辅助函数
# - 加载 bats-support 和 bats-assert
#

# 加载 bats 扩展
load_bats_extensions() {
    # 尝试从 node_modules 加载
    if [ -f "node_modules/bats-support/load.bash" ]; then
        load "node_modules/bats-support/load.bash"
    fi

    if [ -f "node_modules/bats-assert/load.bash" ]; then
        load "node_modules/bats-assert/load.bash"
    fi
}

# 设置测试环境
setup_test_env() {
    # 创建临时测试目录
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$TEST_HOME"

    # 临时修改 HOME 变量（测试期间）
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_HOME"

    # 设置测试配置路径
    export INSTALL_DIR="$TEST_HOME/.fuck"
    export CONFIG_FILE="$INSTALL_DIR/config.sh"
    export MAIN_SH="$INSTALL_DIR/main.sh"
}

# 清理测试环境
teardown_test_env() {
    # 恢复原始 HOME
    if [ -n "${ORIGINAL_HOME:-}" ]; then
        export HOME="$ORIGINAL_HOME"
    fi

    # 清理临时目录
    if [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# 加载主脚本用于测试
load_main_script() {
    # Source main.sh 到当前环境
    if [ -f "main.sh" ]; then
        # 仅加载核心逻辑部分（跳过安装逻辑）
        source main.sh
    else
        echo "Error: main.sh not found" >&2
        return 1
    fi
}

# 创建测试配置文件
create_test_config() {
    mkdir -p "$INSTALL_DIR"
    cat > "$CONFIG_FILE" <<'EOF'
# Test configuration
export FUCK_API_ENDPOINT="https://test.example.com/"
export FUCK_OPENAI_API_KEY="test-key"
export FUCK_DEBUG=false
export FUCK_AUTO_EXEC=false
EOF
}

# Mock curl 命令用于测试
mock_curl_success() {
    local response="$1"
    curl() {
        echo "$response"
        return 0
    }
    export -f curl
}

mock_curl_failure() {
    curl() {
        return 1
    }
    export -f curl
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 辅助函数：运行并捕获输出
run_and_capture() {
    local output
    output=$("$@" 2>&1)
    echo "$output"
}
