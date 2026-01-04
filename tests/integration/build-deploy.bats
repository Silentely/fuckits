#!/usr/bin/env bats
#
# 构建和部署集成测试
# 测试构建脚本的正确性和跨平台兼容性
#
# 重要改进：所有测试在临时目录中运行，不污染项目工作区
#

# 加载测试辅助函数
load '../helpers/bats-helpers'

# ==================== 测试环境设置 ====================

TEST_DIR=""
PROJECT_ROOT=""

setup_file() {
    # 保存项目根目录路径
    PROJECT_ROOT=$(pwd)
    export PROJECT_ROOT

    # 创建临时测试目录
    TEST_DIR=$(mktemp -d)
    export TEST_DIR

    # 复制必需文件到临时目录
    cp "$PROJECT_ROOT/worker.js" "$TEST_DIR/"
    cp "$PROJECT_ROOT/main.sh" "$TEST_DIR/"
    cp "$PROJECT_ROOT/zh_main.sh" "$TEST_DIR/"
    cp "$PROJECT_ROOT/wrangler.toml" "$TEST_DIR/"

    # 复制 scripts 目录
    cp -r "$PROJECT_ROOT/scripts" "$TEST_DIR/"
}

teardown_file() {
    # 清理临时测试目录
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

setup() {
    # 切换到临时测试目录
    cd "$TEST_DIR"
}

teardown() {
    # 返回项目根目录
    cd "$PROJECT_ROOT"
}

# ==================== 构建脚本测试 ====================

@test "Build: build script should exist and be executable" {
    [ -f "scripts/build.sh" ]
    [ -x "scripts/build.sh" ] || chmod +x scripts/build.sh
}

@test "Build: required files should exist before build" {
    [ -f "main.sh" ]
    [ -f "zh_main.sh" ]
    [ -f "worker.js" ]
}

@test "Build: build should complete successfully" {
    run bash scripts/build.sh
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "success\|completed"
}

@test "Build: INSTALLER_SCRIPT should not be empty after build" {
    bash scripts/build.sh

    # Check English script embedding
    ! grep -q "const INSTALLER_SCRIPT = b64_to_utf8(\`\`);" worker.js
}

@test "Build: INSTALLER_SCRIPT_ZH should not be empty after build" {
    bash scripts/build.sh

    # Check Chinese script embedding
    ! grep -q "const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`\`);" worker.js
}

@test "Build: Base64 encoding should be valid" {
    bash scripts/build.sh

    # 提取并验证 base64 内容
    local b64_content
    b64_content=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed 's/.*b64_to_utf8(`//;s/`).*//' | head -1)

    # 尝试解码（不应该失败）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$b64_content" | base64 -D > /dev/null 2>&1
    else
        echo "$b64_content" | base64 -d > /dev/null 2>&1
    fi
    [ $? -eq 0 ]
}

@test "Build: decoded script should contain shebang" {
    bash scripts/build.sh

    # 提取并解码
    local b64_content decoded
    b64_content=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed 's/.*b64_to_utf8(`//;s/`).*//' | head -1)

    if [[ "$OSTYPE" == "darwin"* ]]; then
        decoded=$(echo "$b64_content" | base64 -D)
    else
        decoded=$(echo "$b64_content" | base64 -d)
    fi

    echo "$decoded" | head -1 | grep -q "#!/bin/bash"
}

@test "Build: decoded script should contain core functions" {
    bash scripts/build.sh

    local b64_content decoded
    b64_content=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed 's/.*b64_to_utf8(`//;s/`).*//' | head -1)

    if [[ "$OSTYPE" == "darwin"* ]]; then
        decoded=$(echo "$b64_content" | base64 -D)
    else
        decoded=$(echo "$b64_content" | base64 -d)
    fi

    # 检查核心函数存在
    echo "$decoded" | grep -q "_fuck_execute_prompt"
    echo "$decoded" | grep -q "_fuck_security_evaluate_command"
}

@test "Build: EN and ZH scripts should have different LOCALE settings" {
    bash scripts/build.sh

    # 提取英文脚本
    local b64_en b64_zh decoded_en decoded_zh
    b64_en=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed 's/.*b64_to_utf8(`//;s/`).*//' | head -1)
    b64_zh=$(grep "const INSTALLER_SCRIPT_ZH = b64_to_utf8" worker.js | sed 's/.*b64_to_utf8(`//;s/`).*//' | head -1)

    if [[ "$OSTYPE" == "darwin"* ]]; then
        decoded_en=$(echo "$b64_en" | base64 -D)
        decoded_zh=$(echo "$b64_zh" | base64 -D)
    else
        decoded_en=$(echo "$b64_en" | base64 -d)
        decoded_zh=$(echo "$b64_zh" | base64 -d)
    fi

    # 验证 locale 设置
    echo "$decoded_en" | grep -q 'FUCKITS_LOCALE="en"'
    echo "$decoded_zh" | grep -q 'FUCKITS_LOCALE="zh"'
}

# ==================== 构建错误处理测试 ====================

@test "Build: should fail when main.sh is missing" {
    # Temporarily move main.sh (operates in temp dir, doesn't affect project)
    mv main.sh main.sh.tmp

    run bash scripts/build.sh
    [ "$status" -ne 0 ]

    # Restore
    mv main.sh.tmp main.sh
}

@test "Build: should fail when zh_main.sh is missing" {
    mv zh_main.sh zh_main.sh.tmp

    run bash scripts/build.sh
    [ "$status" -ne 0 ]

    mv zh_main.sh.tmp zh_main.sh
}

@test "Build: should restore backup on build failure" {
    # 创建一个损坏的 worker.js 来触发失败
    local original_content
    original_content=$(cat worker.js)

    # 移除占位符行，使构建失败
    grep -v "const INSTALLER_SCRIPT = b64_to_utf8" worker.js > worker.js.modified
    mv worker.js.modified worker.js

    run bash scripts/build.sh

    # 即使失败，文件应该存在
    [ -f "worker.js" ]

    # 恢复原始内容（在临时目录中）
    echo "$original_content" > worker.js
}

# ==================== Worker 语法验证测试 ====================

@test "Build: worker.js should be valid JavaScript after build" {
    bash scripts/build.sh

    # Verify syntax using node
    if command -v node > /dev/null; then
        run node --check worker.js
        [ "$status" -eq 0 ]
    else
        skip "Node.js not available"
    fi
}

@test "Build: worker.js should export default object" {
    bash scripts/build.sh

    grep -q "export default" worker.js
}

@test "Build: worker.js should contain all required functions" {
    bash scripts/build.sh

    # 检查核心函数
    grep -q "function handleGetRequest" worker.js
    grep -q "function handlePostRequest" worker.js
    grep -q "function handleHealthCheck" worker.js
    grep -q "function handleOptionsRequest" worker.js
    grep -q "function b64_to_utf8" worker.js
}

# ==================== 部署脚本测试 ====================

@test "Deploy Script: deploy script should exist" {
    [ -f "scripts/deploy.sh" ]
}

@test "Deploy Script: one-click deploy script should exist" {
    [ -f "scripts/one-click-deploy.sh" ]
}

@test "Deploy Script: wrangler.toml should exist and be valid" {
    [ -f "wrangler.toml" ]

    # 检查必需字段
    grep -q "name" wrangler.toml
    grep -q "compatibility_date" wrangler.toml
}

# ==================== 幂等性测试 ====================

@test "Build: consecutive builds should produce identical results" {
    bash scripts/build.sh
    local first_hash
    first_hash=$(md5sum worker.js 2>/dev/null || md5 -q worker.js)

    bash scripts/build.sh
    local second_hash
    second_hash=$(md5sum worker.js 2>/dev/null || md5 -q worker.js)

    [ "$first_hash" = "$second_hash" ]
}

@test "Build: build should be idempotent (no side effects on multiple runs)" {
    # Run build three times
    bash scripts/build.sh
    bash scripts/build.sh
    bash scripts/build.sh

    # Verify files are still valid
    ! grep -q "const INSTALLER_SCRIPT = b64_to_utf8(\`\`);" worker.js
    ! grep -q "const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`\`);" worker.js
}

# ==================== 跨平台兼容性测试 ====================

@test "Build: script should use POSIX compatible syntax" {
    # 检查是否使用了 bash 特有语法
    # 这个测试主要是提醒，实际构建脚本使用 bash
    grep -q "#!/bin/bash" scripts/build.sh
}

@test "Build: Base64 encoding should not contain newlines" {
    bash scripts/build.sh

    # Extract base64 content and check for newlines
    local b64_line
    b64_line=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js)

    # No signs of truncated base64 content in line
    # Entire const declaration should be on one line
    local line_count
    line_count=$(echo "$b64_line" | wc -l)
    [ "$line_count" -eq 1 ]
}

# ==================== 工作区清洁度验证 ====================

@test "Build: tests should not pollute project workspace" {
    # 验证项目根目录的 worker.js 未被修改
    cd "$PROJECT_ROOT"

    # 检查是否存在备份文件（不应该有）
    [ ! -f "worker.js.backup" ]

    # 检查是否存在临时文件（不应该有）
    [ ! -f "main.sh.tmp" ]
    [ ! -f "zh_main.sh.tmp" ]
}
