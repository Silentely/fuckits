#!/usr/bin/env bats
#
# language.bats - 语言检测和切换测试
# 测试语言初始化、切换命令和配置持久化
#

# 加载测试辅助工具
load '../../helpers/bats-helpers'

# 每个测试前加载 fuckits.sh
setup() {
    # 从新的统一源码加载
    source ./fuckits.sh
    # 清理环境变量
    unset FUCKITS_LOCALE
    unset FUCK_DEBUG
    unset _FUCK_JSON_MODE
    # 使用临时配置文件，避免污染真实用户配置
    CONFIG_FILE="${BATS_TEST_TMPDIR}/config.sh"
    # 强制使用英文
    _FUCKITS_LOCALE="en"
    # 清理翻译表
    unset _I18N_TABLE
    declare -gA _I18N_TABLE=()
}

# ==================== 语言初始化测试 ====================

@test "language: 初始化时自动检测中文系统" {
    LANG="zh_CN.UTF-8"
    _fuck_init_locale
    [[ "$_FUCKITS_LOCALE" == "zh" ]]
}

@test "language: 初始化时自动检测英文系统" {
    LANG="en_US.UTF-8"
    _fuck_init_locale
    [[ "$_FUCKITS_LOCALE" == "en" ]]
}

@test "language: 环境变量覆盖系统语言" {
    LANG="en_US.UTF-8"
    FUCKITS_LOCALE="zh"
    _fuck_init_locale
    [[ "$_FUCKITS_LOCALE" == "zh" ]]
}

@test "language: 环境变量优先级最高" {
    LANG="zh_CN.UTF-8"
    FUCKITS_LOCALE="en"
    _fuck_init_locale
    [[ "$_FUCKITS_LOCALE" == "en" ]]
}

# ==================== 语言切换命令测试 ====================

@test "language: 显示当前语言（英文）" {
    _i18n_init
    _FUCKITS_LOCALE="en"
    run _fuck_handle_lang_command ""
    [[ "$output" == *"en"* ]]
}

@test "language: 显示当前语言（中文）" {
    _i18n_init
    _FUCKITS_LOCALE="zh"
    run _fuck_handle_lang_command ""
    [[ "$output" == *"zh"* ]]
}

@test "language: 切换到有效语言" {
    _i18n_init
    _fuck_handle_lang_command "zh"
    [[ "$_FUCKITS_LOCALE" == "zh" ]]
}

@test "language: 切换语言后翻译正确" {
    _i18n_init
    _fuck_handle_lang_command "zh"
    result=$(_i18n_get "msg.help.title")
    [[ "$result" == *"AI 自然语言"* ]]
}

@test "language: 切换语言会持久化到配置文件" {
    _i18n_init
    _fuck_handle_lang_command "zh"
    grep -q '^export FUCKITS_LOCALE="zh"$' "$CONFIG_FILE"
}

@test "language: 切换到无效语言返回错误" {
    _i18n_init
    run _fuck_handle_lang_command "fr"
    [[ "$status" -eq 1 ]]
}

@test "language: 无效语言输出错误消息" {
    _i18n_init
    run _fuck_handle_lang_command "fr"
    [[ "$output" == *"Invalid language"* ]] || [[ "$output" == *"无效语言"* ]]
}

# ==================== JSON 模式测试 ====================

@test "language: JSON 模式显示当前语言" {
    _i18n_init
    _FUCKITS_LOCALE="en"
    _FUCK_JSON_MODE=1
    run _fuck_handle_lang_command ""
    [[ "$output" == *'"locale":"en"'* ]]
}

@test "language: JSON 模式切换语言" {
    _i18n_init
    _FUCK_JSON_MODE=1
    run _fuck_handle_lang_command "zh"
    [[ "$output" == *'"locale":"zh"'* ]]
    [[ "$output" == *'"status":"ok"'* ]]
}

@test "language: JSON 模式无效语言" {
    _i18n_init
    _FUCK_JSON_MODE=1
    run _fuck_handle_lang_command "fr"
    [[ "$output" == *'"status":"error"'* ]]
}
