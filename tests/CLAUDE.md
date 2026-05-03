[根目录](../CLAUDE.md) > **tests**

---

# tests 模块文档

## 变更记录 (Changelog)

| 时间 | 操作 | 说明 |
|------|------|------|
| 2026-05-03 22:11:39 | 架构增量扫描 | 验证测试结构完整性；发现 security/fuzzing.bats 依赖缺失的 test_helper/common-setup；确认 171 个测试（83 JS + 88 Bash） |
| 2026-02-03 | R2 回退完成 | 回退 Task 1.3 R2 迁移,删除 r2-integration.test.js (18 tests),恢复 build-deploy.bats 中 7 个 base64 验证测试,测试总数调整为 171 个（83 JS + 88 Bash），100% 通过率 |
| 2026-02-03 | 历史功能测试新增 | 新增 unit/bash/history.bats (18 tests)，Task 1.4 完成；验证命令历史记录、搜索、收藏管理功能 |
| 2026-01-28 | 增量更新 | 新增 integration/、security/、performance/ 目录，测试总数从 145 增至 171 个 |
| 2025-12-12 | 初始化 | 创建测试模块文档，覆盖率 100% |

---

## 模块职责

tests 目录包含项目的完整测试套件，负责验证 Worker 后端和 Shell 脚本前端的功能正确性、安全性和可靠性。

**核心目标**：
- 确保代码质量：80%+ 覆盖率
- 验证安全引擎：21 条安全规则全覆盖
- 跨平台兼容：macOS/Linux 构建脚本
- 持续集成：GitHub Actions 自动运行

**测试框架**：
- **JavaScript/Worker**：Vitest + Miniflare (Cloudflare Workers 本地模拟)
- **Bash/Shell**：bats-core (Bash Automated Testing System)

---

## 测试架构总览

```
tests/
├── unit/                    # 单元测试
│   ├── bash/               # Shell 脚本测试
│   │   ├── security.bats   # 21 条安全规则测试 (27 tests)
│   │   └── history.bats    # 命令历史与收藏测试 (18 tests)
│   └── worker/             # Worker 功能测试 (83 tests)
│       ├── handlers.test.js       # 请求处理测试 (14 tests)
│       ├── locale.test.js         # 中英文语言测试 (9 tests)
│       ├── quota.test.js          # 配额管理测试 (6 tests)
│       ├── api-errors.test.js     # OpenAI API 错误响应 (14 tests)
│       ├── health-check.test.js   # 健康检查端点 (3 tests)
│       ├── cors.test.js           # CORS 支持 (3 tests)
│       ├── user-agent.test.js     # UA 检测 (5 tests)
│       ├── url-paths.test.js      # URL 路径处理 (5 tests)
│       ├── post-requests.test.js  # POST 请求处理 (6 tests)
│       ├── ip-address.test.js     # IP 地址处理 (3 tests)
│       ├── quota-edge-cases.test.js # 配额边界条件 (3 tests)
│       ├── sysinfo.test.js        # 系统信息处理 (3 tests)
│       ├── concurrent-requests.test.js # 并发请求 (1 test)
│       └── cache.test.js          # AI 响应缓存 (9 tests)
├── integration/            # 集成测试 (43 tests)
│   ├── build-deploy.bats  # 构建部署流程 (23 tests)
│   └── e2e.bats           # 端到端用户流程 (20 tests)
├── security/               # 安全测试
│   └── fuzzing.bats       # 模糊测试 (17 tests)
├── performance/            # 性能测试
│   └── quota-benchmark.test.js # 配额性能基准 (9 tests)
├── e2e/                    # 真实部署测试
│   └── real-deployment.test.sh # 生产环境验证 (10 tests)
├── fixtures/               # 测试数据
│   └── mock-responses.json
└── helpers/                # 测试辅助工具
    ├── test-env.js        # JS 测试环境配置
    └── bats-helpers.bash  # Bash 测试辅助函数
```

---

## 运行测试

### 快速运行

```bash
# 运行所有测试（171 个）
npm test

# 仅 JavaScript 测试（83 个）
npm run test:js

# 仅 Bash 测试（88 个）
npm run test:bash

# 生成覆盖率报告
npm run test:coverage

# 运行安全测试
npm run test:security

# 运行模糊测试
npm run test:fuzzing

# 运行性能测试
npm run test:performance

# 运行端到端测试（需要已部署的 Worker）
npm run test:e2e
```

---

## 测试文件详解

### <a name="security-bats"></a>security.bats

**路径**：`tests/unit/bash/security.bats`
**行数**：约 223 行
**职责**：测试 main.sh 中的 21 条安全规则

**测试覆盖**：
- **Block 级别（8 条）**：绝对禁止的危险命令
  - `rm -rf /` - 递归删除根目录
  - `rm -rf /*` - 通配符删除根下所有文件
  - `rm --no-preserve-root` - 禁用根目录保护
  - `rm -rf .*` - 递归删除隐藏/系统文件
  - `dd if=... of=/dev/...` - 原始磁盘写入
  - `mkfs` - 文件系统格式化
  - `fdisk` - 分区操作
  - `:(){ :|:& };:` - Fork 炸弹

- **Challenge 级别（9 条）**：需要二次确认的高风险命令
  - `curl | bash` / `wget | sh` - 远程脚本执行
  - `source https://` - 远程文件导入
  - `eval` - 显式动态执行
  - `$(...)` / `` `...` `` - 命令替换
  - `bash -c` - 嵌套 shell 调用
  - `python -c` - 内联解释器执行
  - 操作关键系统路径

- **Warn 级别（4 条）**：提示潜在风险
  - `rm -rf` - 一般递归删除
  - `chmod 777` - 全局可写权限
  - `sudo rm -rf` - sudo 递归删除
  - `> /etc/passwd` 等 - 重定向到敏感系统文件

- **安全模式（4 个测试）**：strict/balanced/off 模式切换
- **白名单（2 个测试）**：命令绕过检测

---

### <a name="history-bats"></a>history.bats

**路径**：`tests/unit/bash/history.bats`
**行数**：约 334 行
**职责**：测试命令历史记录、搜索和收藏管理功能

**测试覆盖**：
- **历史文件初始化（2 个测试）**：JSON 结构、文件权限、不覆盖已有文件
- **jq 依赖检查（2 个测试）**：安装检测、缺失提示
- **历史记录日志（2 个测试）**：记录执行、限制 1000 条
- **历史查看（2 个测试）**：显示最近 N 条、空历史提示
- **历史搜索（2 个测试）**：关键词搜索、无匹配提示
- **收藏管理（4 个测试）**：添加/列表/运行/删除参数验证
- **命令路由（4 个测试）**：history/favorite/fav 别名路由

**依赖要求**：
- 需要安装 `jq` 工具（JSON 处理）
- 历史文件存储在 `~/.fuck/history.json`
- 配置文件权限自动设置为 600

---

### <a name="build-deploy-bats"></a>build-deploy.bats

**路径**：`tests/integration/build-deploy.bats`
**行数**：约 288 行
**职责**：测试构建脚本的正确性和跨平台兼容性

**测试覆盖**：
- **构建脚本测试（12 个）**：文件存在、构建成功、base64 编码验证、脚本内容验证
- **构建错误处理（3 个）**：文件缺失、备份恢复
- **Worker 语法验证（3 个）**：JavaScript 语法、export、函数完整性
- **部署脚本测试（3 个）**：脚本存在、wrangler.toml 验证
- **幂等性测试（2 个）**：连续构建一致性、无副作用
- **跨平台兼容性（2 个）**：POSIX 语法、base64 无换行
- **工作区清洁度（1 个）**：测试不污染项目目录

**重要特性**：
- 所有测试在临时目录中运行，不污染项目工作区
- 使用 `setup_file`/`teardown_file` 管理临时目录生命周期

---

### <a name="e2e-bats"></a>e2e.bats

**路径**：`tests/integration/e2e.bats`
**行数**：约 320 行
**职责**：端到端集成测试，验证完整用户流程

**测试覆盖**：
- **安装流程（4 个）**：目录创建、权限设置、可执行权限、配置文件内容
- **临时模式（1 个）**：带参数运行不安装
- **配置系统（2 个）**：配置加载、恶意配置拒绝
- **卸载流程（2 个）**：目录删除、shell 配置清理
- **安全引擎集成（3 个）**：函数可用性、命令阻断、模式切换
- **系统信息收集（2 个）**：数据收集、缓存机制
- **别名系统（2 个）**：默认别名、自定义别名
- **重复安装（2 个）**：正常覆盖、配置保留
- **错误处理（2 个）**：HOME 未设置、目录只读

---

### <a name="fuzzing-bats"></a>fuzzing.bats

**路径**：`tests/security/fuzzing.bats`
**行数**：约 240 行
**职责**：安全引擎的模糊测试和鲁棒性验证

**测试覆盖**：
- **随机命令（1 个）**：100 个随机字母数字命令不崩溃
- **特殊字符（1 个）**：各种特殊字符安全处理
- **长命令（1 个）**：10000 字符命令不溢出
- **空命令（1 个）**：空/空白命令处理
- **Unicode（1 个）**：中日韩字符不破坏引擎
- **嵌套引号（1 个）**：引号嵌套不导致注入
- **空字节（1 个）**：空字节安全处理
- **重复危险模式（1 个）**：所有危险模式都被检测
- **命令链（1 个）**：各种链式命令检测
- **路径遍历（1 个）**：路径遍历不绕过检查
- **环境变量（1 个）**：变量扩展安全处理
- **Glob 模式（1 个）**：通配符变体处理
- **快速连续评估（1 个）**：50 次评估结果一致
- **并发评估（1 个）**：10 个并发进程不崩溃
- **白名单绕过（1 个）**：各种绕过尝试被阻止
- **模式切换（1 个）**：三种模式切换一致
- **正则特殊字符（1 个）**：正则字符不崩溃

**已知问题**：
- 依赖 `test_helper/common-setup` 文件（当前缺失），需要创建该文件或修正 load 路径

---

### <a name="quota-benchmark"></a>quota-benchmark.test.js

**路径**：`tests/performance/quota-benchmark.test.js`
**行数**：约 256 行
**职责**：配额系统性能基准测试

**测试覆盖**：
- **内存配额性能（2 个）**：1000 次顺序请求 < 500ms、100 IP 高效处理
- **KV 配额性能（3 个）**：100 次顺序请求 < 1000ms、并发请求、竞态条件演示
- **配额重置性能（1 个）**：清除 1000 条记录 < 10ms
- **边界条件（2 个）**：快速重复请求、匿名用户处理
- **内存使用（1 个）**：10000 IP 不无限增长

**CI 适配**：
- 检测 `CI` 环境变量，自动放宽性能阈值

---

## 测试辅助工具

### test-env.js

**路径**：`tests/helpers/test-env.js`
**职责**：Vitest 全局配置和 Miniflare 环境设置

**功能**：
- 创建 Miniflare 实例（模拟 Cloudflare Workers）
- 注入环境变量（`OPENAI_API_KEY`, `ADMIN_ACCESS_KEY`）
- 配置 KV 命名空间（`QUOTA_KV`）
- 使用 MockAgent 模拟 OpenAI API
- 提供全局测试辅助函数（`get`, `post`, `postRaw`, `options`, `clearKV`, `setKV`, `getKV`）

> **注意**：test-env.js 中仍保留了 R2 Bucket（`SCRIPTS_BUCKET`）的 mock 初始化代码，这是 R2 迁移回退后的遗留代码（参见 commit 7a252d9），当前主代码已不使用 R2 存储。

---

### bats-helpers.bash

**路径**：`tests/helpers/bats-helpers.bash`
**职责**：Bash 测试辅助函数

**功能**：
- `extract_severity()` - 从输出提取安全级别（block/challenge/warn）
- `extract_reason()` - 从输出提取原因
- `test_security_rule()` - 安全规则测试辅助
- `test_security_mode()` - 安全模式测试辅助
- `create_test_whitelist()` / `clear_test_whitelist()` - 白名单管理
- `verify_config_permissions()` - 配置文件权限验证
- `mock_system_info()` - 系统信息模拟
- `validate_json()` - JSON 格式验证
- `generate_test_base64()` / `verify_base64_decode()` - Base64 工具

---

## 测试覆盖率

### 当前状态（2026-05-03）

**总体**：171/171 测试通过 (100%)

**JavaScript 测试**：83 个（14 个测试文件）
- handlers.test.js: 14 个
- locale.test.js: 9 个
- quota.test.js: 6 个
- api-errors.test.js: 14 个
- health-check.test.js: 3 个
- cors.test.js: 3 个
- user-agent.test.js: 5 个
- url-paths.test.js: 5 个
- post-requests.test.js: 6 个
- ip-address.test.js: 3 个
- quota-edge-cases.test.js: 3 个
- sysinfo.test.js: 3 个
- concurrent-requests.test.js: 1 个
- cache.test.js: 9 个

**Bash 测试**：88 个
- unit/bash/security.bats: 27 个（21 规则 + 3 模式 + 3 白名单）
- unit/bash/history.bats: 18 个（历史记录与收藏管理）
- integration/build-deploy.bats: 23 个（构建部署流程）
- integration/e2e.bats: 20 个（端到端用户流程）

**代码覆盖率**：
- worker.js: 目标 80%+
- main.sh security engine: 100%
- main.sh history functions: 100%
- 构建脚本: 手动验证

---

## 持续集成 (CI)

### GitHub Actions 集成

测试在每次 push/PR 时自动运行：

```yaml
# .github/workflows/deploy.yml
steps:
  - name: Install bats-core
    run: sudo apt-get install -y bats

  - name: Run tests
    run: npm test

  - name: Build worker bundle
    run: npm run build
```

**失败策略**：测试失败 -> 阻止部署

**Node 版本**：20.x

---

## 已知问题

### fuzzing.bats 依赖缺失

`tests/security/fuzzing.bats` 第 7 行引用了 `../test_helper/common-setup`，但该文件不存在：
- `tests/test_helper/common-setup` - 不存在
- `tests/test_helper/common-setup.bash` - 不存在

**影响**：`npm run test:fuzzing` 可能会失败

**修复建议**：
1. 创建 `tests/test_helper/common-setup.bash` 文件
2. 或修改 fuzzing.bats 的 load 路径指向 `../helpers/bats-helpers`

---

## 扩展测试计划

### 已完成

1. **集成测试** (`tests/integration/`):
   - 端到端工作流（安装 -> 配置 -> 执行 -> 卸载）- e2e.bats
   - 构建和部署流程 - build-deploy.bats
   - 跨平台兼容性（macOS/Linux）

2. **性能测试** (`tests/performance/`):
   - 配额管理性能 - quota-benchmark.test.js

3. **安全测试** (`tests/security/`):
   - 模糊测试 - fuzzing.bats

### 待补充测试

1. **真实 API 测试**:
   - 真实 OpenAI API 调用（使用测试 key）

2. **回归测试**:
   - 历史 bug 防护
   - 边界条件覆盖

3. **修复 fuzzing.bats**:
   - 创建缺失的 test_helper/common-setup 文件

---

## 故障排查

### 常见测试问题

**问题：Vitest 找不到 worker.js**
- 确认：项目根目录运行 `npm test`
- 检查：`vitest.config.js` 路径配置

**问题：bats 测试失败**
- 确认：已安装 bats-core (`brew install bats-core`)
- 检查：`main.sh` 可执行权限 (`chmod +x main.sh`)
- 验证：`source main.sh` 无语法错误

**问题：history.bats 测试跳过**
- 确认：已安装 jq (`brew install jq`)
- 检查：jq 在 PATH 中可用

**问题：fuzzing.bats 失败**
- 确认：`tests/test_helper/common-setup` 文件存在
- 临时方案：使用 `npm run test:bash` 运行其他 bash 测试

**问题：CI 测试通过但本地失败**
- 检查：Node.js 版本一致（20.x）
- 确认：依赖版本锁定（`npm ci` vs `npm install`）

---

## 相关文件清单

```
tests/
├── unit/
│   ├── bash/
│   │   ├── security.bats                # 21 条安全规则测试（27 tests, 223 行）
│   │   └── history.bats                 # 命令历史与收藏测试（18 tests, 334 行）
│   └── worker/
│       ├── handlers.test.js             # 请求处理测试（14 tests）
│       ├── locale.test.js               # 多语言测试（9 tests）
│       ├── quota.test.js                # 配额管理测试（6 tests）
│       ├── api-errors.test.js           # API 错误响应（14 tests）
│       ├── health-check.test.js         # 健康检查（3 tests）
│       ├── cors.test.js                 # CORS 支持（3 tests）
│       ├── user-agent.test.js           # UA 检测（5 tests）
│       ├── url-paths.test.js            # URL 路径（5 tests）
│       ├── post-requests.test.js        # POST 请求（6 tests）
│       ├── ip-address.test.js           # IP 处理（3 tests）
│       ├── quota-edge-cases.test.js     # 配额边界（3 tests）
│       ├── sysinfo.test.js              # 系统信息（3 tests）
│       ├── concurrent-requests.test.js  # 并发请求（1 test）
│       └── cache.test.js                # AI 响应缓存（9 tests）
├── integration/
│   ├── build-deploy.bats               # 构建部署测试（23 tests, 288 行）
│   └── e2e.bats                        # 端到端测试（20 tests, 320 行）
├── security/
│   └── fuzzing.bats                    # 模糊测试（17 tests, 240 行）
├── performance/
│   └── quota-benchmark.test.js         # 性能基准（9 tests, 256 行）
├── e2e/
│   └── real-deployment.test.sh         # 真实部署测试（10 tests, 332 行）
├── fixtures/
│   └── mock-responses.json              # 模拟 API 响应
└── helpers/
    ├── test-env.js                      # Vitest 环境配置（280 行）
    └── bats-helpers.bash                # Bash 测试辅助（146 行）
```

**总代码量**：约 3100 行测试代码

**覆盖率**：100% (19/19 测试文件已扫描)

---

## 参考资源

- **Vitest 文档**：https://vitest.dev/
- **Miniflare 文档**：https://miniflare.dev/
- **bats-core 文档**：https://bats-core.readthedocs.io/
- **TAP 协议**：https://testanything.org/
- **Cloudflare Workers 测试**：https://developers.cloudflare.com/workers/testing/

---

测试套件确保每一行代码都经过严格验证。
