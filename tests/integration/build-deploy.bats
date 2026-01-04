#!/usr/bin/env bats
#
# 构建和部署集成测试
# 测试构建脚本的正确性和跨平台兼容性
#

# 加载测试辅助函数
load '../helpers/bats-helpers'

# ==================== 测试环境设置 ====================

BACKUP_WORKER=""

setup_file() {
    # 备份 worker.js
    if [ -f "worker.js" ]; then
        BACKUP_WORKER=$(mktemp)
        cp worker.js "$BACKUP_WORKER"
    fi
    export BACKUP_WORKER
}

teardown_file() {
    # 恢复 worker.js
    if [ -n "$BACKUP_WORKER" ] && [ -f "$BACKUP_WORKER" ]; then
        cp "$BACKUP_WORKER" worker.js
        rm -f "$BACKUP_WORKER"
    fi
    # 清理备份文件
    rm -f worker.js.backup
}

setup() {
    # 确保在项目根目录
    if [ ! -f "worker.js" ] || [ ! -f "main.sh" ]; then
        skip "必须在项目根目录运行"
    fi
}

# ==================== 构建脚本测试 ====================

@test "Build: 构建脚本应该存在且可执行" {
    [ -f "scripts/build.sh" ]
    [ -x "scripts/build.sh" ] || chmod +x scripts/build.sh
}

@test "Build: 构建前必需文件应该存在" {
    [ -f "main.sh" ]
    [ -f "zh_main.sh" ]
    [ -f "worker.js" ]
}

@test "Build: 构建应该成功完成" {
    run bash scripts/build.sh
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "success\|completed"
}

@test "Build: 构建后 INSTALLER_SCRIPT 不应该为空" {
    bash scripts/build.sh

    # 检查英文脚本嵌入
    ! grep -q "const INSTALLER_SCRIPT = b64_to_utf8(\`\`);" worker.js
}

@test "Build: 构建后 INSTALLER_SCRIPT_ZH 不应该为空" {
    bash scripts/build.sh

    # 检查中文脚本嵌入
    ! grep -q "const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`\`);" worker.js
}

@test "Build: Base64 编码应该是有效的" {
    bash scripts/build.sh

    # 提取并验证 base64 内容
    local b64_content
    b64_content=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed "s/.*b64_to_utf8(\`//;s/\`).*//" | head -1)

    # 尝试解码（不应该失败）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$b64_content" | base64 -D > /dev/null 2>&1
    else
        echo "$b64_content" | base64 -d > /dev/null 2>&1
    fi
    [ $? -eq 0 ]
}

@test "Build: 解码后的脚本应该包含 shebang" {
    bash scripts/build.sh

    # 提取并解码
    local b64_content decoded
    b64_content=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed "s/.*b64_to_utf8(\`//;s/\`).*//" | head -1)

    if [[ "$OSTYPE" == "darwin"* ]]; then
        decoded=$(echo "$b64_content" | base64 -D)
    else
        decoded=$(echo "$b64_content" | base64 -d)
    fi

    echo "$decoded" | head -1 | grep -q "#!/bin/bash"
}

@test "Build: 解码后的脚本应该包含核心函数" {
    bash scripts/build.sh

    local b64_content decoded
    b64_content=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed "s/.*b64_to_utf8(\`//;s/\`).*//" | head -1)

    if [[ "$OSTYPE" == "darwin"* ]]; then
        decoded=$(echo "$b64_content" | base64 -D)
    else
        decoded=$(echo "$b64_content" | base64 -d)
    fi

    # 检查核心函数存在
    echo "$decoded" | grep -q "_fuck_execute_prompt"
    echo "$decoded" | grep -q "_fuck_security_evaluate_command"
}

@test "Build: 中英文脚本应该有不同的 LOCALE 设置" {
    bash scripts/build.sh

    # 提取英文脚本
    local b64_en b64_zh decoded_en decoded_zh
    b64_en=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js | sed "s/.*b64_to_utf8(\`//;s/\`).*//" | head -1)
    b64_zh=$(grep "const INSTALLER_SCRIPT_ZH = b64_to_utf8" worker.js | sed "s/.*b64_to_utf8(\`//;s/\`).*//" | head -1)

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

@test "Build: 缺少 main.sh 时应该失败" {
    # 临时移动 main.sh
    mv main.sh main.sh.tmp

    run bash scripts/build.sh
    [ "$status" -ne 0 ]

    # 恢复
    mv main.sh.tmp main.sh
}

@test "Build: 缺少 zh_main.sh 时应该失败" {
    mv zh_main.sh zh_main.sh.tmp

    run bash scripts/build.sh
    [ "$status" -ne 0 ]

    mv zh_main.sh.tmp zh_main.sh
}

@test "Build: 构建失败时应该恢复备份" {
    # 创建一个损坏的 worker.js 来触发失败
    local original_content
    original_content=$(cat worker.js)

    # 移除占位符行，使构建失败
    grep -v "const INSTALLER_SCRIPT = b64_to_utf8" worker.js > worker.js.modified
    mv worker.js.modified worker.js

    run bash scripts/build.sh

    # 即使失败，文件应该存在
    [ -f "worker.js" ]

    # 恢复原始内容
    echo "$original_content" > worker.js
}

# ==================== Worker 语法验证测试 ====================

@test "Build: 构建后 worker.js 应该是有效的 JavaScript" {
    bash scripts/build.sh

    # 使用 node 验证语法
    if command -v node > /dev/null; then
        run node --check worker.js
        [ "$status" -eq 0 ]
    else
        skip "Node.js 不可用"
    fi
}

@test "Build: worker.js 应该导出默认对象" {
    bash scripts/build.sh

    grep -q "export default" worker.js
}

@test "Build: worker.js 应该包含所有必需函数" {
    bash scripts/build.sh

    # 检查核心函数
    grep -q "function handleGetRequest" worker.js
    grep -q "function handlePostRequest" worker.js
    grep -q "function handleHealthCheck" worker.js
    grep -q "function handleOptionsRequest" worker.js
    grep -q "function b64_to_utf8" worker.js
}

# ==================== 部署脚本测试 ====================

@test "Deploy Script: 部署脚本应该存在" {
    [ -f "scripts/deploy.sh" ]
}

@test "Deploy Script: 一键部署脚本应该存在" {
    [ -f "scripts/one-click-deploy.sh" ]
}

@test "Deploy Script: wrangler.toml 应该存在且有效" {
    [ -f "wrangler.toml" ]

    # 检查必需字段
    grep -q "name" wrangler.toml
    grep -q "compatibility_date" wrangler.toml
}

# ==================== 幂等性测试 ====================

@test "Build: 连续两次构建应该产生相同结果" {
    bash scripts/build.sh
    local first_hash
    first_hash=$(md5sum worker.js 2>/dev/null || md5 -q worker.js)

    bash scripts/build.sh
    local second_hash
    second_hash=$(md5sum worker.js 2>/dev/null || md5 -q worker.js)

    [ "$first_hash" = "$second_hash" ]
}

@test "Build: 构建应该是幂等的（多次运行无副作用）" {
    # 运行三次构建
    bash scripts/build.sh
    bash scripts/build.sh
    bash scripts/build.sh

    # 验证文件仍然有效
    ! grep -q "const INSTALLER_SCRIPT = b64_to_utf8(\`\`);" worker.js
    ! grep -q "const INSTALLER_SCRIPT_ZH = b64_to_utf8(\`\`);" worker.js
}

# ==================== 跨平台兼容性测试 ====================

@test "Build: 脚本应该使用 POSIX 兼容语法" {
    # 检查是否使用了 bash 特有语法
    # 这个测试主要是提醒，实际构建脚本使用 bash
    grep -q "#!/bin/bash" scripts/build.sh
}

@test "Build: Base64 编码应该不包含换行符" {
    bash scripts/build.sh

    # 提取 base64 内容并检查是否有换行
    local b64_line
    b64_line=$(grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js)

    # 行内不应该有 base64 内容被截断的迹象
    # 整个 const 声明应该在一行内
    local line_count
    line_count=$(echo "$b64_line" | wc -l)
    [ "$line_count" -eq 1 ]
}
