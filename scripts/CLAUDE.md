[根目录](../CLAUDE.md) > **scripts**

---

# scripts 模块文档

## 变更记录 (Changelog)

| 时间 | 操作 | 说明 |
|------|------|------|
| 2026-01-28 | 增量更新 | 新增 common.sh 公共函数库文档 |
| 2025-12-12 09:15:03 | 架构分析更新 | 验证面包屑导航，确认模块覆盖率 100% |
| 2025-12-06 | 架构分析更新 | 添加面包屑导航，确认模块结构 |
| 2025-12-05 22:23:10 | 初始化 | 首次生成模块文档 |

---

## 模块职责

scripts 目录包含项目的构建、部署和配置脚本，负责自动化整个开发和部署流程。

**核心功能**：
- 构建：将安装脚本嵌入到 Worker
- 部署：上传 Worker 到 Cloudflare
- 配置：交互式环境配置
- 一键部署：完整自动化流程

---

## 入口与启动

所有脚本通过 npm scripts 或直接执行：

```bash
# 通过 npm
npm run build
npm run deploy
npm run one-click-deploy
npm run setup

# 直接执行
bash scripts/build.sh
bash scripts/deploy.sh
bash scripts/one-click-deploy.sh
bash scripts/setup.sh
```

**前置条件**：
- Node.js >= 18.0.0
- npm
- curl（用于一键部署）
- 脚本需要可执行权限（`chmod +x scripts/*.sh`）

---

## 脚本详解

### <a name="build"></a>build.sh

**职责**：构建 Worker，将安装脚本嵌入到 worker.js

**工作流程**：
1. 检查必需文件（main.sh, zh_main.sh, worker.js）
2. 创建 worker.js 备份
3. 使用 base64 编码安装脚本
4. 通过 sed 替换 worker.js 中的占位符
5. 验证构建结果
6. 清理备份文件

**平台兼容性**：
- macOS：使用 `base64 -i` 和 `sed -i.tmp`
- Linux：使用 `base64 -w 0` 和 `sed -i`

**关键代码**：
```bash
# macOS
B64_EN=$(base64 -i main.sh)
sed -i.tmp "s#^const INSTALLER_SCRIPT = b64_to_utf8(\`.*\`);#const INSTALLER_SCRIPT = b64_to_utf8(\`${B64_EN}\`);#" worker.js

# Linux
B64_EN=$(base64 -w 0 main.sh)
sed -i "s#^const INSTALLER_SCRIPT = b64_to_utf8(\`.*\`);#const INSTALLER_SCRIPT = b64_to_utf8(\`${B64_EN}\`);#" worker.js
```

**错误处理**：
- 文件不存在：退出并提示
- 构建失败：恢复备份
- 空内容检测：防止生成无效 Worker

---

### <a name="deploy"></a>deploy.sh

**职责**：构建并部署 Worker 到 Cloudflare

**工作流程**：
1. 检查 npx 和 wrangler 可用性
2. 如果 wrangler 不存在，自动安装
3. 调用 build.sh 构建
4. 执行 `wrangler deploy` 部署

**依赖**：
- build.sh
- wrangler CLI

**使用场景**：
- 快速部署更新
- CI/CD 集成

---

### <a name="setup"></a>setup.sh

**职责**：交互式配置向导，帮助用户完成初始设置

**工作流程**：
1. 检查依赖（Node.js, npm）
2. 安装 npm 依赖
3. 引导 Cloudflare 登录
4. 配置 OpenAI API Key
5. 可选：配置自定义模型
6. 可选：配置自定义 API Base
7. 设置脚本可执行权限
8. 显示后续步骤

**交互提示**：
- 每个步骤都有清晰的说明
- 使用颜色区分不同类型的信息
- 提供跳过选项

**适用场景**：
- 首次部署
- 重新配置环境

---

### <a name="one-click-deploy"></a>one-click-deploy.sh

**职责**：完整的自动化部署流程，一键完成所有配置和部署

**工作流程**：
1. **环境检查**：验证 node, npm, curl
2. **安装依赖**：检查并安装 npm 包
3. **Cloudflare 认证**：
   - 检查是否已登录
   - 未登录则引导登录
4. **配置 OpenAI API**：
   - 提示输入 API Key
   - 可选：配置自定义模型
   - 可选：配置自定义 API Base
5. **构建 Worker**：调用 build.sh
6. **部署**：执行 wrangler deploy
7. **显示后续步骤**：域名配置、测试命令等

**特色功能**：
- ASCII 艺术 Banner
- 彩色进度提示
- 详细的步骤说明
- 友好的错误处理
- 完整的后续指引

**辅助函数**：
```bash
check_command()    # 检查命令是否可用
prompt_input()     # 提示用户输入
confirm()          # 确认操作
```

**使用场景**：
- 首次部署（推荐）
- 快速重新部署
- 演示和教学

---

### <a name="common"></a>common.sh

**职责**：公共函数库，提供跨脚本共享的辅助函数

**核心函数**：
```bash
update_wrangler_var()  # 更新 wrangler.toml 中的 [vars] 配置
```

**工作原理**：
1. 接收键值对参数（KEY, VALUE）
2. 使用嵌入式 Python 脚本解析 TOML
3. 如果 `[vars]` 段不存在则创建
4. 更新或添加指定的配置项
5. 正确处理转义字符

**使用方式**：
```bash
source scripts/common.sh
update_wrangler_var "OPENAI_API_MODEL" "gpt-4o-mini"
```

**依赖**：
- python3（用于安全的 TOML 解析）

---

## 关键依赖与配置

### 外部依赖
- **Node.js**: >= 18.0.0
- **npm**: 包管理器
- **wrangler**: Cloudflare Workers CLI
- **curl**: HTTP 客户端（一键部署用）
- **base64**: 编码工具
- **sed**: 文本替换工具

### 配置文件
- `package.json`: npm 脚本定义
- `wrangler.toml`: Cloudflare Workers 配置
- `worker.js`: 构建目标文件

### 环境变量
通过 wrangler secret 设置：
- `OPENAI_API_KEY`
- `OPENAI_API_MODEL`（可选）
- `OPENAI_API_BASE`（可选）

---

## 数据模型

### 构建产物
- **输入**：main.sh, zh_main.sh（纯文本）
- **中间产物**：Base64 编码字符串
- **输出**：worker.js（嵌入 Base64 的 JavaScript）

### 部署流程
```
main.sh + zh_main.sh
    ↓ (base64 encode)
Base64 Strings
    ↓ (sed replace)
worker.js (updated)
    ↓ (wrangler deploy)
Cloudflare Workers
```

---

## 测试与质量

### 当前状态
- 无自动化测试
- 依赖手动验证

### 测试方法
1. **构建测试**：
   ```bash
   npm run build
   # 检查 worker.js 是否包含 base64 内容
   grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js
   ```

2. **部署测试**：
   ```bash
   npm run deploy
   # 访问部署的 URL 验证
   curl -I https://your-worker.workers.dev
   ```

3. **一键部署测试**：
   ```bash
   # 在干净环境中运行
   npm run one-click-deploy
   ```

### 质量保证
- 所有脚本使用 `set -euo pipefail` 严格模式
- 关键操作后检查退出码
- 提供详细的错误信息
- 备份机制（build.sh）

---

## 常见问题 (FAQ)

**Q: 构建时提示 "sed: command not found"**
A: 安装 sed 工具。macOS 自带，Linux 使用包管理器安装。

**Q: 部署时提示 "Not logged in"**
A: 运行 `npx wrangler login` 登录 Cloudflare。

**Q: 一键部署卡在认证步骤**
A: 确保浏览器可以打开，手动完成 OAuth 流程。

**Q: 构建后 worker.js 内容为空**
A: 检查 main.sh 和 zh_main.sh 是否存在且可读。

**Q: 如何回滚到之前的版本**
A: 使用 Git 恢复 worker.js，或从 worker.js.backup 恢复。

---

## 相关文件清单

```
scripts/
├── build.sh              # 构建脚本（~82 行）
├── deploy.sh             # 部署脚本（~34 行）
├── one-click-deploy.sh   # 一键部署（~179 行）
├── setup.sh              # 配置向导（~104 行）
└── common.sh             # 公共函数库（~65 行）
```

**总代码量**：约 465 行 Bash

**覆盖率**：100% (5/5 文件已扫描)

---

## 扩展建议

### 功能增强
- 添加 `scripts/test.sh` 用于自动化测试
- 添加 `scripts/rollback.sh` 用于快速回滚
- 支持多环境部署（dev/staging/prod）
- 添加版本号管理

### 已完成 ✅
- ✅ 提取公共函数到 `scripts/common.sh`
- ✅ GitHub Actions 工作流
- ✅ 自动化测试和部署

### 代码改进
- 添加更详细的日志记录
- 支持静默模式（非交互式）
- 添加配置文件验证

### CI/CD 集成
- 版本标签自动发布
