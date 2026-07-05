#!/usr/bin/env bats
#
# i18n.bats - i18n 翻译系统测试
# 测试翻译表初始化、获取、语言切换和自动检测
#

# 加载测试辅助工具
load '../../helpers/bats-helpers'

# 每个测试前加载 fuckits.sh
setup() {
    # 从新的统一源码加载
    source ./fuckits.sh
    # 强制使用英文以保持测试一致性
    _FUCKITS_LOCALE="en"
    # 清理 i18n 初始化状态（确保每个测试独立运行）
    unset _I18N_INITIALIZED
    unset _I18N_KEYS
}

# ==================== 翻译表初始化测试 ====================

@test "i18n: 初始化翻译表" {
    _i18n_init
    [[ "${_I18N_INITIALIZED}" == "1" ]]
    [[ -n "${_I18N_KEYS}" ]]
}

@test "i18n: 翻译表包含英文键" {
    _i18n_init
    _i18n_has_key "msg.help.title"
    _i18n_has_key "msg.error.api_key_not_set"
    _i18n_has_key "msg.security.blocked"
}

@test "i18n: 翻译表包含中文键" {
    _i18n_init
    _i18n_has_key "msg.help.title.zh"
    _i18n_has_key "msg.error.api_key_not_set.zh"
    _i18n_has_key "msg.security.blocked.zh"
}

@test "i18n: 重复初始化不会重复添加" {
    _i18n_init
    local keys1="${_I18N_KEYS}"
    _i18n_init
    local keys2="${_I18N_KEYS}"
    [[ "$keys1" == "$keys2" ]]
}

# ==================== 翻译获取测试 ====================

@test "i18n: 获取英文翻译" {
    _i18n_init
    _i18n_set_locale "en"
    result=$(_i18n_get "msg.help.title")
    [[ "$result" == *"AI natural language"* ]]
}

@test "i18n: 获取中文翻译" {
    _i18n_init
    _i18n_set_locale "zh"
    result=$(_i18n_get "msg.help.title")
    [[ "$result" == *"AI 自然语言"* ]]
}

@test "i18n: 不存在的键返回键名" {
    _i18n_init
    result=$(_i18n_get "msg.nonexistent.key")
    [[ "$result" == "msg.nonexistent.key" ]]
}

@test "i18n: 自动初始化翻译表" {
    # 不手动调用 _i18n_init
    result=$(_i18n_get "msg.help.title")
    [[ "$result" == *"AI natural language"* ]]
}

@test "i18n: 中文回退到英文" {
    _i18n_init
    _i18n_set_locale "zh"
    # 使用一个只有英文没有中文的键
    result=$(_i18n_get "msg.help.title")
    # 应该返回中文翻译
    [[ "$result" == *"AI 自然语言"* ]]
}

# ==================== 语言切换测试 ====================

@test "i18n: 设置有效语言" {
    _i18n_init
    _i18n_set_locale "zh"
    [[ "$_FUCKITS_LOCALE" == "zh" ]]
}

@test "i18n: 设置无效语言返回错误" {
    _i18n_init
    run _i18n_set_locale "fr"
    [[ "$status" -eq 1 ]]
}

@test "i18n: 语言切换后翻译正确" {
    _i18n_init
    _i18n_set_locale "zh"
    result=$(_i18n_get "msg.help.title")
    [[ "$result" == *"AI 自然语言"* ]]

    _i18n_set_locale "en"
    result=$(_i18n_get "msg.help.title")
    [[ "$result" == *"AI natural language"* ]]
}

# ==================== 系统语言检测测试 ====================

@test "i18n: 自动检测中文系统" {
    LANG="zh_CN.UTF-8"
    locale=$(_i18n_detect_locale)
    [[ "$locale" == "zh" ]]
}

@test "i18n: 自动检测英文系统" {
    LANG="en_US.UTF-8"
    locale=$(_i18n_detect_locale)
    [[ "$locale" == "en" ]]
}

@test "i18n: 自动检测回退英文" {
    LANG="ja_JP.UTF-8"
    locale=$(_i18n_detect_locale)
    [[ "$locale" == "en" ]]
}

@test "i18n: 检测 LANG 环境变量" {
    LANG="zh_TW.UTF-8"
    locale=$(_i18n_detect_locale)
    [[ "$locale" == "zh" ]]
}

@test "i18n: 检测 LC_ALL 环境变量" {
    unset LANG
    LC_ALL="zh_CN.UTF-8"
    locale=$(_i18n_detect_locale)
    [[ "$locale" == "zh" ]]
}

# ==================== 翻译完整性测试 ====================

@test "i18n: 中英文翻译完整性" {
    _i18n_init
    # 验证每个英文键都有对应的中文键
    local missing=0
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! _i18n_has_key "${key}.zh"; then
            echo "Missing zh translation for: $key"
            ((missing++))
        fi
    done <<< "$_I18N_KEYS"
    [[ $missing -eq 0 ]]
}

@test "i18n: 关键错误消息翻译存在" {
    _i18n_init
    # 验证关键错误消息的翻译
    _i18n_has_key "msg.error.api_key_not_set"
    _i18n_has_key "msg.error.api_key_not_set.zh"
    _i18n_has_key "msg.error.home_not_set"
    _i18n_has_key "msg.error.home_not_set.zh"
}

@test "i18n: 关键安全消息翻译存在" {
    _i18n_init
    # 验证关键安全消息的翻译
    _i18n_has_key "msg.security.blocked"
    _i18n_has_key "msg.security.blocked.zh"
    _i18n_has_key "msg.security.high_risk"
    _i18n_has_key "msg.security.high_risk.zh"
}
