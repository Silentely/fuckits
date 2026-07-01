# Changelog

All notable changes to fuckits will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.1.64
- ✨ feat: 新增 worker 功能增强

## v2.1.63
- fix: remove dead code, fix English strings in main.sh, fix grep pattern for config cleanup

## v2.1.62
- feat: embed default Pollinations App Key for OAuth attribution

## v2.1.61
- docs: update changelog for Pollinations OAuth

## v2.1.60
- test: add Pollinations OAuth tests

## v2.1.59
- feat: add --oauth to zh_main.sh

## v2.1.58
- feat: add Pollinations config hints and template

## v2.1.57
- feat: add --oauth command routing and help text

## v2.1.56
- feat: add Pollinations OAuth core functions

## v2.1.55
- feat: add pollinations status to health check

## v2.1.54
- ✨ feat: 自动重载更新后的脚本，移除手动 reload 提示

## v2.1.53
- ♻️ refactor: 重构版本检查机制，用缓存文件替代后台进程异步检查

## v2.1.52
- ♻️ refactor: 简化异步版本检查中的 stderr 重定向并添加 disown 防止 zsh 通知

## v2.1.51
- ♻️ refactor: 优化异步版本检查的 stderr 重定向与调试输出控制

## v2.1.50
- ✨ feat: 新增写入核心脚本逻辑的函数

## v2.1.49
- 🐛 fix: 修复异步版本检查 health 接口路径错误并增强构建流程健壮性

## v2.1.48
- 🐛 fix: 修复安装更新提示中 URL 拼接重复斜杠问题并优化函数定义顺序

## v2.1.47
- ♻️ refactor: 优化 worker.js 中的代码结构

## v2.1.46
- ✨ feat: 更新成功后提示用户重载 shell

## v2.1.45
- ✅ test: 删除无效的 Base64 编码验证测试

## v2.1.44
- 🐛 fix: 修复构建部署集成测试中base64解码的跨平台兼容性问题

## v2.1.43
- ✅ test: 修复集成测试中 base64 解码长字符串的问题

## v2.1.42
- ✨ feat: 新增 --favorite 命令行选项替代 favorite 子命令

## v2.1.41
- ♻️ refactor: 统一子命令格式，使用 `--` 前缀

## v2.1.40
- ✨ feat: 新增 help 和 update 子命令并提供相关测试

## v2.1.39
- 🐛 fix: 恢复 worker.js 中 CHANGELOG 和 buildTime 占位符，修复构建注入失效

## v2.1.38
- 📝 docs: 文档迁移到 /docs 目录 + 更新日志自动化 + 健康检查隐藏模型 + API Key 措辞修正

## v2.1.37
- ♻️ refactor: 将版本递增和 CHANGELOG 生成从部署脚本迁移到 pre-commit hook
- 🔥 remove: 移除默认模型配置项
- ✨ feat: 新增自动生成 CHANGELOG 功能并优化文案
- 📝 docs: 更新文档中关于配额绕过和自定义API基址的说明
- 📝 docs: 完善 CLAUDE.md 项目文档，新增基础检索与网络检索策略指南

## v2.1.35
- ✨ feat: Agent 友好性改造 + 社区规范 + 技术债务清理 (#7)

## v2.1.33
- 📦 chore: 恢复 .husky 目录到 git 跟踪

## v2.1.32
- 📦 chore: 恢复 post-commit hook 到 git 跟踪

## v2.1.31
- 🐛 fix: post-commit hook 用 replaceAll 替换所有占位符 + 清理残留

## v2.1.30
- 🐛 fix: 恢复 worker.js 更新日志占位符确保构建时动态注入

## v2.1.29
- 📦 chore: 版本号更新至 2.1.28

## v2.1.27
- 📝 docs: 修复 CHANGELOG.md v2.1.25 条目换行显示问题

## v2.1.26
- ✨ feat: 版本徽章移至标题内联 + health buildTime 改为动态生成

## v2.1.25
- 🐛 fix: 更新日志注入使用 \n 转义换行防止 JS 字符串中断

## v2.1.24
- 🐛 fix: 改用 post-commit + amend 修复 CHANGELOG 占位符替换

## v2.1.23
- 🐛 fix: commit-msg hook 改用 git update-index 更新暂存区

## v2.1.22
- 🐛 fix: 修复 commit-msg hook 不生效 + 更新日志注入安全转义

## v2.1.21
- 🐛 fix: 重新构建 main.sh/zh_main.sh 嵌入修复后的 runtime-common.sh

## v2.1.20
- 🐛 fix: 修复 runtime-common.sh 5 处 [ ... ]] 括号语法错误

## v2.1.19
- 🐛 fix: build.sh 统一用 Python base64 编码消除平台差异

## v2.1.18
- 🐛 fix: CI 恢复先测试后构建顺序

## v2.1.17
- ✨ feat: CHANGELOG.md 单一来源 + CI 修复 + 更新日志自动同步

## v2.1.16
- 🐛 fix: 修复 CI 安全测试失败 + 网页移除贡献指南

## v2.1.15
- ✨ feat: 版本号统一管理 + 网页版本徽章 + 更新日志补全

## v2.1.14
- 📝 docs: 全量文档同步 — 修正版本号/代码行数/安全规则数量/函数列表

## v2.1.13
- 🐛 fix(shell): 修复 BASH_SOURCE 路径解析导致 runtime-common.sh 污染项目目录

## v2.1.12
- fix: 修复 SonarCloud 代码质量问题

## v2.1.11
- 📝 docs: README 添加社交预览图展示

## v2.1.10
- ✨ feat: SEO 优化 — 添加 Canonical/OG/Twitter/JSON-LD 元标签 + 社交预览图 + 缓存头

## v2.1.9
- ✨ feat: GEO 内容优化 — 着陆页升级为完整项目主页

## v2.1.8
- ✨ feat: 实现 Agent 可发现性端点 — sitemap/robots.txt/.well-known/WebMCP

## v2.1.7
- ⚡ perf: 优化配额 KV 竞态处理 — 指数退避重试 + 写入验证

## v2.1.6
- ⚡ perf: 多维度性能优化 — OpenAI 超时/缓存键规范化/健康检查缓存

## v2.1.5
- 📝 docs: 更新部署文档和测试文档 — health 端点字段说明、测试数量同步

## v2.1.4
- 📝 docs: 更新测试文档 + 修复 Husky pre-commit hook

## v2.1.3
- 📦 chore: bump version to 2.1.3
- 📝 docs: 更新 CLAUDE.md — 版本号、测试数量、变更记录同步
- 🐛 fix: 修复版本号变量作用域和 readonly 重赋值问题

## v2.1.2
- ✨ feat: 单一版本来源 — VERSION 文件统一管理版本号
- ✨ feat: health 端点增加构建时间字段 buildTime
- 📦 chore: rebuild worker with version fixes
- ✨ feat: 优化安装/更新流程 — 版本对比 + 清洁更新
- 🐛 fix: 修复构建时版本号只替换第一个占位符的 bug
- ✨ feat: 安装时运行时注入版本号到已安装脚本
- ✨ feat: 注入脚本版本占位符并支持版本查看与远程更新提示
- 🔒 security: 过滤 wrangler deploy 输出中的敏感信息
- 🛠️ chore: 删除 Codex Intelligence Hub 工作流并将 AI 输出重定向到标准错误
- refactor: 提取共享函数到 runtime-common.sh 减少主脚本重复
- ✨ feat: 新增安全工具函数测试和历史扩展功能测试，修复 fuzzing 测试问题
- 📝 docs: 更新文档内容，修正测试架构说明并优化开发指南
- 📝 docs: 更新文档内容以修正过时数据和完善架构说明
- 📝 docs: 更新项目文档和版本信息
- chore: 优化文件操作命令并更新忽略配置 - 在所有 mv 操作中添加了 command 前缀和 -f -- 参数以确保安全性和一致性 - 在 .gitignore 中添加 .omx 文件忽略规则 - 改进了缓存和历史记录文件的处理方式，增强系统稳定性
- fix: 改进系统信息收集、JSON 转义和命令执行安全性
- test: 修复 CI 环境中的测试失败
- fix: 在 CI 工作流中添加 bats-core 安装步骤
- fix: 修复 CI 工作流中的 BATS 测试警告
- revert: 完全回退 R2 对象存储迁移，恢复 base64 嵌入式架构
- feat: 将安装脚本迁移至 Cloudflare R2 存储
- feat: 实现 AI 响应缓存系统并完成性能优化
- feat: 引入全面的项目改进计划和技术债务管理
- feat: 扩展测试套件并完善文档
- docs: 澄清统计数据排除管理员绕过请求
- docs: 更新部署和自检文档
- feat: 增强 API 健壮性，改进健康检查和错误处理
- fix(build): rebuild embedded installer scripts
- fix: 改进审计日志健壮性，优化性能测试，并移除任务报告
- docs(review): compile comprehensive project review and improvement plan (#5)
- feat(docs): 添加 Pollinations 构建徽章到 README 文件
- Update GitHub Actions workflow for codex_hub
- Create codex_hub.yml
- test: 大幅改进 Worker 和 Shell 脚本测试覆盖率
- test: 增加全面的自动化测试套件
- fix: 修复代码审查发现的关键问题并统一注释语言
- fix: 增强正则表达式定义以提升 Zsh 兼容性和代码可维护性
- feat: 增强配置文件加载安全性并扩展命令注入检测规则
- fix: 移除终端颜色代码以解决输出格式问题
- feat: 优化AI提示词以生成更直接可执行的命令
- chore: 从仓库中彻底移除 .claude 和备份文件
- chore: 从仓库中移除 .bats 目录并更新 .gitignore
- fix(ci): 修复工作流清理步骤权限问题
- docs: 补充完整项目文档和测试架构说明
- feat: 添加 CORS 支持并改进语言检测
- refactor: 创建 scripts/common.sh 消除代码重复
- test: 添加完整测试套件（Vitest + bats-core）
- feat: 改进 spinner 动画，支持前缀标签显示
- refactor: 更新终端加载动画并改进配置文件文档
- fix: 修复终端动画和更新进度显示
- perf: 简化系统信息收集并提高健壮性
- refactor: 使安全规则数组可被环境变量覆盖
- fix: 增强 JSON 转义功能并修复只读变量错误
- feat: 新增系统信息缓存和增强型安全检测引擎
- Fix: Optimize display of thinking message and spinner in zh_main.sh
- docs: 将共享演示模式的每日调用限额从10次提升至200次
- fix: 部署输出中添加API密钥过滤并改进错误处理
- fix: 修复部署脚本中环境变量缺失时的路径回退逻辑
- ci: 在部署工作流中增加 OpenAI API 密钥掩码功能
- fix: 改进 GitHub Actions 工作流中的敏感信息屏蔽逻辑
- ci: 在部署工作流中添加敏感值屏蔽
- ci: 修复敏感值掩码脚本的缩进格式
- ci: 改进Wrangler配置敏感信息屏蔽脚本的健壮性
- ci: 添加 Cloudflare 环境变量到 GitHub Actions 输出掩码
- ci: 增强 GitHub Actions 中敏感值的掩码功能
- ci: 改进 GitHub Actions 部署工作流的可靠性和安全性
- style: 修复wrangler配置掩码脚本的缩进格式
- ci: 改进安全变量掩蔽与工作流清理逻辑
- refactor: 以 AWK 替换 Python 脚本来解析和遮蔽敏感配置变量
- ci: 修复Python脚本的缩进以提高可读性
- ci: 增强部署工作流并更新相关文档
- ci: 支持从 Secrets 回退到 Variables 的 wrangler 配置下载
- ci: 添加 GitHub Actions 自动部署工作流到 Cloudflare Workers
- refactor: 移除复杂的输出边框，改为更简洁的分隔线
- feat: 增强命令执行界面的用户体验和安全性
- feat: 将默认 AI 模型从 gpt-4-turbo 升级为 gpt-5-nano
- docs: 调整README文档结构，删除临时文件
- remove: 移除后台执行功能及相关配置选项
- feat: 添加后台执行命令功能
- feat: 支持自定义 KV 绑定名，增强配额存储配置灵活性
- feat: 添加 KV 持久化配额计数以跨 PoP 严格限制调用次数
- refactor: 重构代码架构和优化安装流程
- feat: 添加配置文件占位符提示和详细配置说明
- Delete SUMMARY.md
- Fix formatting and update project maintenance info
- Update README by removing badges and changing links
- feat: 新增管理员免额度密钥机制
- feat: 添加本地API密钥优先模式，支持绕过共享Worker配额限制
- feat: 更新项目名称和仓库URL，改进错误处理和用户体验
- fix: 修复默认 API 端点配置逻辑，避免环境变量覆盖问题
- fix: 修复shell脚本逻辑错误和文件格式问题
- refactor: 改进部署脚本配置管理方式
- chore: 更新项目配置和文档中的项目名称
- Delete .serena directory
- docs: 修复 Cloudflare Custom Domain 配置说明
- Update CHANGELOG.md
- feat: 迁移到统一域名并增强用户体验
- fix
- docs: 新增项目文档和开发环境配置
- refactor-project-add-one-click-deploy-and-improve-features (#1)
- Merge pull request #6 from faithleysath/copilot/improve-inclusivity-and-chinese-support
- Polish remaining informal language to be fully civilized
- Remove confirmation loop from uninstall to keep only echo statement changes
- Make zh_main.sh more civilized by replacing offensive language with polite alternatives
- Initial plan
- update star history
- Revise project details and customization options in README
- Revise README for project restructuring details
- Revise README with project refactoring details
- Update README with project refactoring information
- 降低攻击性
- update doc
- update preview
- UPDATE DOC
- update doc
- fix bugs
- update worker
- update chart
- update chart
- update doc
- update doc
- update doc
- update doc
- update echo
- fix bugs
- fix encode
- update
- clean
- Revert "更新CI"
- 更新CI
- 增加攻击性
- 优化翻译
- 增加攻击性
- deepseek祖安版本
- update echo
- fix
- v1.0
- wip
- wip
- fix
- clean output
- update output
- fix
- update domain
- fix bugs
- update CI
- fix
- cloudflare worker
- fix bugs
- colorful
- fix bugs
- fuck!
- first commit
