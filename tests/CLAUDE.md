[根目录](../CLAUDE.md) > **tests**

---

# tests 模块文档

## 变更记录 (Changelog)

| 时间 | 操作 | 说明 |
|------|------|------|
| 2026-02-03 | R2 回退完成 | 回退 Task 1.3 R2 迁移,删除 r2-integration.test.js (18 tests),恢复 build-deploy.bats 中 7 个 base64 验证测试,测试总数调整为 171 个（83 JS + 88 Bash），100% 通过率 ✅ |
| 2026-02-03 | 历史功能测试新增 | 新增 unit/bash/history.bats (18 tests)，Task 1.4 完成；验证命令历史记录、搜索、收藏管理功能 |
| 2026-01-28 | 增量更新 | 新增 integration/、security/、performance/ 目录，测试总数从 56 增至 145 个 |
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
├── fixtures/               # 测试数据
│   └── mock-responses.json
└── helpers/                # 测试辅助工具
    ├── test-env.js        # JS 测试环境配置
    └── bats-helpers.bash  # Bash 测试辅助函数
```

**详细设计文档**：参见 [../docs/TEST_ARCHITECTURE.md](../docs/TEST_ARCHITECTURE.md)

---

## 运行测试

### 快速运行

```bash
# 运行所有测试（171 个）
npm test

# 仅 JavaScript 测试（101 个）
npm run test:js

# 仅 Bash 测试（70 个）
npm run test:bash

# 生成覆盖率报告
npm run test:coverage
```

### 开发模式

```bash
# Watch 模式（自动重跑）
npm run test:watch

# 调试模式
npm run test:debug
```

---

## 测试文件详解

### <a name="security-bats"></a>security.bats

**路径**：`tests/unit/bash/security.bats`
**行数**：约 600 行
**职责**：测试 main.sh 中的 21 条安全规则

**测试覆盖**：
- **Block 级别（8 条）**：绝对禁止的危险命令
  - `rm -rf /` - 递归删除根目录
  - `rm -rf /*` - 通配符删除根下所有文件
  - `:(){ :|:& };:` - Fork 炸弹
  - `dd if=/dev/zero of=/dev/sda` - 磁盘擦除
  - `mkfs.ext4 /dev/sda` - 格式化系统盘
  - `chmod -R 777 /` - 全局权限放开
  - `chown -R nobody /` - 全局所有权变更
  - `>` / `truncate` 覆盖关键系统文件

- **Challenge 级别（9 条）**：需要二次确认的高风险命令
  - `rm -rf` 删除大量文件
  - `chmod -R` / `chown -R` 递归权限变更
  - `curl | sh` / `wget | bash` 远程脚本执行
  - `sudo` / `su` 提权操作
  - `kill -9` 强制终止进程
  - `systemctl stop` / `service stop` 停止系统服务
  - 包管理器卸载操作

- **Warn 级别（4 条）**：提示潜在风险
  - `eval` 动态代码执行
  - `source` 未知脚本
  - Git 强制操作 (`--force`, `--hard`)
  - Docker 特权模式

**测试模式**：
- `balanced`（默认）：block + challenge + warn
- `strict`：全部规则升级为 block
- `permissive`：仅 block 生效，其他降级
- `whitelist`：允许特定命令绕过检测

**关键测试**：
```bash
@test "Security Block: rm -rf / " {
    run _fuck_security_evaluate_command "rm -rf /"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -q "Recursive delete targeting root"
}

@test "Security Challenge: sudo dangerous command" {
    run _fuck_security_evaluate_command "sudo apt remove nginx"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -q "Elevated privileges detected"
}
```

---

### <a name="history-bats"></a>history.bats

**路径**：`tests/unit/bash/history.bats`
**行数**：约 318 行
**职责**：测试命令历史记录、搜索和收藏管理功能

**测试覆盖**：
- **历史文件初始化（2 个测试）**：
  - 创建正确的 JSON 结构（version, commands, favorites）
  - 文件权限设置为 600
  - 不覆盖已有历史文件

- **jq 依赖检查（2 个测试）**：
  - jq 已安装时通过检查
  - jq 缺失时返回友好错误提示

- **历史记录日志（2 个测试）**：
  - 记录命令执行（提示词、命令、退出码、耗时）
  - 限制最多 1000 条记录（FIFO 队列）

- **历史查看（2 个测试）**：
  - 显示最近 N 条命令
  - 空历史时显示友好提示

- **历史搜索（2 个测试）**：
  - 通过关键词搜索历史命令
  - 无匹配时显示提示信息

- **收藏管理（4 个测试）**：
  - 添加收藏需要名称和提示词参数
  - 列出收藏时空列表显示提示
  - 运行收藏需要索引参数
  - 删除收藏需要索引参数

- **命令路由（4 个测试）**：
  - `fuck history` 调用历史查看
  - `fuck history search` 调用历史搜索
  - `fuck favorite` 显示使用帮助
  - `fuck fav list` 别名正常工作

**关键测试**：
```bash
@test "History Log: should record command execution" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    run _fuck_log_history "install git" "apt install git" 0 5

    [ "$status" -eq 0 ]

    # Verify entry was added
    local count=$(jq '.commands | length' "$history_file")
    [ "$count" -eq 1 ]

    # Verify entry content
    jq -e '.commands[0].prompt == "install git"' "$history_file"
    jq -e '.commands[0].command == "apt install git"' "$history_file"
    jq -e '.commands[0].exitCode == 0' "$history_file"
    jq -e '.commands[0].duration == 5' "$history_file"
}

@test "History Search: should find matching commands" {
    if ! command -v jq &> /dev/null; then
        skip "jq not installed"
    fi

    local history_file="$INSTALL_DIR/history.json"
    _fuck_init_history_file "$history_file"

    _fuck_log_history "install git" "apt install git" 0 1
    _fuck_log_history "install nginx" "apt install nginx" 0 1
    _fuck_log_history "remove git" "apt remove git" 0 1

    run _fuck_history_search "install"

    [ "$status" -eq 0 ]
    echo "$output" | grep -q "install git"
    echo "$output" | grep -q "install nginx"
    ! echo "$output" | grep -q "remove git"
}
```

**依赖要求**：
- 需要安装 `jq` 工具（JSON 处理）
- 历史文件存储在 `~/.fuck/history.json`
- 配置文件权限自动设置为 600

---

### <a name="handlers-test"></a>handlers.test.js

**路径**：`tests/unit/worker/handlers.test.js`
**行数**：约 150 行
**职责**：测试 Worker 的 HTTP 请求处理逻辑

**测试覆盖**：
- **GET 请求**：
  - 浏览器访问 → 重定向到 GitHub
  - curl/wget → 返回安装脚本（英文）
  - `/zh` 路径 → 返回中文脚本
  - User-Agent 检测正确性

- **POST 请求**：
  - 正常请求 → 返回 AI 生成的命令
  - 缺少必需字段 → 400 错误
  - OpenAI API 错误 → 500 错误
  - 超时处理

- **健康检查**：
  - GET `/health` → 返回 JSON 状态
  - 包含 `services.apiKey` 字段
  - 包含 `stats.totalCalls` 和 `stats.uniqueIPs` 统计
  - 版本信息正确

- **CORS 支持**：
  - OPTIONS 预检请求
  - 跨域头部正确设置

**示例测试**：
```javascript
describe('GET 请求处理', () => {
  it('应该为浏览器请求返回 GitHub 重定向', async () => {
    const response = await get('/', {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
    });
    expect(response.status).toBe(302);
    expect(response.headers.get('Location')).toContain('github.com');
  });

  it('应该为 curl 请求返回安装脚本', async () => {
    const response = await get('/', {
      'User-Agent': 'curl/7.79.1',
    });
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toContain('text/plain');
    const body = await response.text();
    expect(body).toContain('#!/bin/bash');
  });
});
```

---

### <a name="locale-test"></a>locale.test.js

**路径**：`tests/unit/worker/locale.test.js`
**行数**：约 80 行
**职责**：测试中英文双语支持

**测试覆盖**：
- **路径识别**：
  - `/` → 英文脚本
  - `/zh` → 中文脚本
  - `/en` → 英文脚本
  - 大小写不敏感

- **脚本内容验证**：
  - 英文脚本包含 `INSTALLER_SCRIPT`
  - 中文脚本包含 `INSTALLER_SCRIPT_ZH`
  - Base64 解码正确
  - 字符编码 UTF-8

- **Accept-Language 头部**（预留）：
  - 自动语言检测
  - 回退到默认语言

**示例测试**：
```javascript
describe('多语言支持', () => {
  it('GET / 应该返回英文安装脚本', async () => {
    const response = await get('/', { 'User-Agent': 'curl/7.79.1' });
    const body = await response.text();
    expect(body).toContain('Installing fuckits');
  });

  it('GET /zh 应该返回中文安装脚本', async () => {
    const response = await get('/zh', { 'User-Agent': 'curl/7.79.1' });
    const body = await response.text();
    expect(body).toContain('安装 fuckits');
  });
});
```

---

### <a name="quota-test"></a>quota.test.js

**路径**：`tests/unit/worker/quota.test.js`
**行数**：183 行
**职责**：测试配额管理系统（演示限额保护）

**测试覆盖**：
- **内存配额（Map）**：
  - 单 IP 达到限额后拒绝
  - 每日重置（基于日期）
  - 跨请求计数累加

- **KV 配额（持久化）**：
  - 写入/读取正确
  - 跨 Worker 实例共享
  - TTL 自动过期

- **管理员绕过**：
  - 正确的 `adminKey` 绕过限额
  - 错误的 `adminKey` 仍受限
  - 不传 `adminKey` 走正常流程

- **本地密钥优先**：
  - 提供 `apiKey` 绕过共享限额
  - 无效 `apiKey` 返回 401

- **配额耗尽响应**：
  - HTTP 429 状态码
  - 错误信息包含 `DEMO_LIMIT_EXCEEDED`
  - 建议配置本地密钥

**关键测试**：
```javascript
describe('配额管理系统', () => {
  it('应该在达到限额后拒绝请求', async () => {
    const ip = '192.168.1.1';
    // 发送 3 次请求（限额为 3）
    for (let i = 0; i < 3; i++) {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: `test ${i}`,
      }, { 'CF-Connecting-IP': ip });
      expect(response.status).toBe(200);
    }

    // 第 4 次请求应该被拒绝
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'test 4',
    }, { 'CF-Connecting-IP': ip });
    expect(response.status).toBe(429);
    const body = await response.json();
    expect(body.error).toContain('DEMO_LIMIT_EXCEEDED');
  });

  it('正确的 adminKey 应该绕过限额', async () => {
    // 先耗尽配额...
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'admin command',
      adminKey: 'test-admin-key',
    }, { 'CF-Connecting-IP': ip });

    expect(response.status).toBe(200);
  });
});
```

---

## 测试辅助工具

### test-env.js

**路径**：`tests/helpers/test-env.js`
**职责**：Vitest 全局配置和 Miniflare 环境设置

**功能**：
- 创建 Miniflare 实例（模拟 Cloudflare Workers）
- 注入环境变量（`OPENAI_API_KEY`, `ADMIN_ACCESS_KEY`）
- 配置 KV 命名空间（`QUOTA_KV`）
- 提供全局测试辅助函数（`get`, `post`, `getKV`, `setKV`）
- 自动清理测试数据

**示例代码**：
```javascript
import { Miniflare } from 'miniflare';
import { readFileSync } from 'fs';

const mf = new Miniflare({
  script: readFileSync('./worker.js', 'utf-8'),
  modules: true,
  bindings: {
    OPENAI_API_KEY: 'test-key',
    ADMIN_ACCESS_KEY: 'test-admin-key',
    SHARED_DAILY_LIMIT: 3,
  },
  kvNamespaces: ['QUOTA_KV'],
});

global.get = async (path, headers = {}) => {
  return await mf.dispatchFetch(`http://localhost${path}`, {
    method: 'GET',
    headers,
  });
};
```

---

### bats-helpers.bash

**路径**：`tests/helpers/bats-helpers.bash`
**职责**：Bash 测试辅助函数

**功能**：
- `extract_severity()` - 从输出提取安全级别（block/challenge/warn）
- `setup()` - 每个测试前的环境准备
- `teardown()` - 测试后清理
- 颜色代码处理
- 临时文件管理

**示例代码**：
```bash
# 提取安全评估结果的严重性级别
extract_severity() {
    echo "$1" | grep -oE 'SEVERITY: (block|challenge|warn)' | cut -d' ' -f2
}

# 标准化测试环境
setup() {
    source ./main.sh
    export FUCK_SECURITY_MODE="balanced"
    export FUCK_DEBUG=false
}
```

---

## 测试覆盖率

### 当前状态（2026-02-03）

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
- cache.test.js: 9 个（AI 响应缓存系统测试,含 Codex 审查优化）

**Bash 测试**：88 个
- unit/bash/security.bats: 27 个（21 规则 + 3 模式 + 3 白名单）
- unit/bash/history.bats: 18 个（历史记录与收藏管理，Task 1.4 完成）
- integration/build-deploy.bats: 23 个（已恢复 7 个 base64 验证测试）
- integration/e2e.bats: 20 个

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
  - name: Run JavaScript tests
    run: npm run test:js

  - name: Run Bash tests
    run: npm run test:bash

  - name: Generate coverage report
    run: npm run test:coverage
```

**失败策略**：测试失败 → 阻止部署

---

## 扩展测试计划

### 已完成 ✅

1. **集成测试** (`tests/integration/`):
   - ✅ 端到端工作流（安装 → 配置 → 执行 → 卸载）- e2e.bats
   - ✅ 构建和部署流程 - build-deploy.bats
   - ✅ 跨平台兼容性（macOS/Linux）

2. **性能测试** (`tests/performance/`):
   - ✅ 配额管理性能 - quota-benchmark.test.js

3. **安全测试** (`tests/security/`):
   - ✅ 模糊测试 - fuzzing.bats

### 待补充测试

1. **真实 API 测试**:
   - 真实 OpenAI API 调用（使用测试 key）

2. **回归测试**:
   - 历史 bug 防护
   - 边界条件覆盖

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

**问题：KV 命名空间测试失败**
- 确认：Miniflare 版本兼容
- 检查：`test-env.js` 正确初始化 KV

**问题：CI 测试通过但本地失败**
- 检查：Node.js 版本一致（18.x）
- 确认：依赖版本锁定（`npm ci` vs `npm install`）

---

## 相关文件清单

```
tests/
├── unit/
│   ├── bash/
│   │   ├── security.bats                # 21 条安全规则测试（27 tests, ~600 行）
│   │   └── history.bats                 # 命令历史与收藏测试（18 tests, ~318 行）
│   └── worker/
│       ├── handlers.test.js             # 请求处理测试（14 tests）
│       ├── locale.test.js               # 多语言测试（9 tests）
│       ├── quota.test.js                # 配额管理测试（6 tests）
│       ├── api-errors.test.js           # API 错误响应（14 tests, 392 行）
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
│   ├── build-deploy.bats               # 构建部署测试（23 tests, 304 行）
│   └── e2e.bats                        # 端到端测试（20 tests, 317 行）
├── security/
│   └── fuzzing.bats                    # 模糊测试（17 tests, 239 行）
├── performance/
│   └── quota-benchmark.test.js         # 性能基准（9 tests, 255 行）
├── fixtures/
│   └── mock-responses.json              # 模拟 API 响应
└── helpers/
    ├── test-env.js                      # Vitest 环境配置
    └── bats-helpers.bash                # Bash 测试辅助
```

**总代码量**：约 3100 行测试代码

**覆盖率**：100% (19/19 测试文件已扫描)

---

## 参考资源

- **详细设计**：[../docs/TEST_ARCHITECTURE.md](../docs/TEST_ARCHITECTURE.md)
- **Vitest 文档**：https://vitest.dev/
- **Miniflare 文档**：https://miniflare.dev/
- **bats-core 文档**：https://bats-core.readthedocs.io/
- **TAP 协议**：https://testanything.org/
- **Cloudflare Workers 测试**：https://developers.cloudflare.com/workers/testing/

---

_本小姐的测试套件确保每一行代码都经过严格验证！(￣ω￣)ノ_
