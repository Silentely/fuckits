# fuckits 测试基础设施架构设计

## 📋 文档信息

**创建时间**: 2025-12-12
**负责人**: Claude (Ojousama Engineer)
**状态**: 已完成
**优先级**: P0 (Critical)

---

## 🎯 设计目标

### 核心目标
1. **从 0% 提升到 80%+ 代码覆盖率**
   - worker.js: 核心功能 100% 覆盖
   - main.sh: 安全引擎 100% 覆盖
   - 构建脚本: 关键路径 80%+ 覆盖

2. **建立 TDD 工作流**
   - 先写测试，后修复漏洞
   - 每个 P0 漏洞都必须有对应的测试用例
   - 防止回归问题

3. **本地验证优先**
   - 所有测试必须能在本地运行
   - CI/CD 仅作为二次验证
   - 符合 CLAUDE.md 强制验证机制

---

## 🏗️ 测试架构总览

### 目录结构
```
fuckits/
├── tests/                          # 测试根目录
│   ├── unit/                       # 单元测试
│   │   ├── worker/                 # Worker 单元测试
│   │   │   ├── quota.test.js      # 配额管理测试
│   │   │   ├── locale.test.js     # 语言检测测试
│   │   │   └── handlers.test.js   # 请求处理测试
│   │   └── bash/                   # Bash 脚本单元测试
│   │       ├── security.bats       # 安全引擎测试
│   │       ├── config.bats         # 配置系统测试
│   │       └── install.bats        # 安装逻辑测试
│   ├── integration/                # 集成测试
│   │   ├── e2e.test.js            # 端到端测试
│   │   └── build-deploy.bats      # 构建部署流程测试
│   ├── fixtures/                   # 测试数据
│   │   ├── mock-responses.json    # Mock API 响应
│   │   └── test-commands.sh       # 测试命令集
│   └── helpers/                    # 测试工具
│       ├── test-env.js            # 测试环境设置
│       └── bats-helpers.bash      # Bats 辅助函数
├── vitest.config.js               # Vitest 配置
├── .bats/                          # Bats 测试配置
│   └── setup.bash                  # Bats 全局设置
└── package.json                    # 新增测试脚本和依赖
```

---

## 🔧 工具选型

### 1. JavaScript/Worker 测试：Vitest

**选型理由**：
- ✅ **原生 ES6 模块支持** - 项目使用 `"type": "module"`
- ✅ **Cloudflare Workers 兼容** - 通过 Miniflare 集成
- ✅ **快速执行** - Vite 的即时热更新
- ✅ **现代化 API** - 与 Jest 兼容但更轻量
- ✅ **内置覆盖率** - 使用 c8 无需额外配置

**核心依赖**：
```json
{
  "devDependencies": {
    "vitest": "^1.0.0",
    "miniflare": "^3.0.0",
    "@cloudflare/workers-types": "^4.0.0",
    "c8": "^9.0.0"
  }
}
```

**配置要点**：
- 使用 `miniflare` 模拟 Cloudflare Workers 运行时
- 模拟 KV 存储进行配额测试
- 支持异步测试和 Worker 环境变量

### 2. Bash 脚本测试：bats-core

**选型理由**：
- ✅ **行业标准** - GitHub、Homebrew 等大型项目都在使用
- ✅ **简单易用** - TAP (Test Anything Protocol) 格式
- ✅ **模块化** - 支持辅助函数和共享设置
- ✅ **CI 友好** - 标准退出码和 TAP 输出

**核心依赖**：
```bash
# 通过 npm 安装（跨平台兼容）
npm install --save-dev bats bats-support bats-assert
```

**配置要点**：
- 使用 `bats-support` 提供通用辅助函数
- 使用 `bats-assert` 提供丰富的断言
- 为安全引擎的 21 条规则各编写独立测试

---

## 📊 测试策略

### Worker.js 测试策略

#### 优先级 P0: 配额管理系统
**测试目标**：确保共享配额和 KV 持久化正确工作

**测试用例**：
1. **内存配额测试**：
   - ✅ 单个 IP 达到限额后被拒绝
   - ✅ 不同 IP 独立计数
   - ✅ 日期切换后计数重置

2. **KV 配额测试**：
   - ✅ KV 成功持久化计数
   - ✅ TTL 正确设置（到 UTC 午夜）
   - ✅ KV 失败时降级到内存模式

3. **管理员绕过测试**：
   - ✅ 正确的 adminKey 绕过限额
   - ✅ 错误的 adminKey 不生效
   - ✅ 空 adminKey 不绕过

**Mock 策略**：
```javascript
// 使用 Miniflare 的内存 KV
import { Miniflare } from 'miniflare';

const mf = new Miniflare({
  kvNamespaces: ['QUOTA_KV'],
  script: workerScript,
});
```

#### 优先级 P1: Locale 检测
**测试用例**：
- ✅ URL 路径 `/zh` 返回中文
- ✅ query 参数 `?lang=zh` 返回中文
- ✅ Accept-Language header 检测
- ✅ 默认英文

#### 优先级 P1: 请求处理
**测试用例**：
- ✅ GET 请求返回脚本（curl）
- ✅ GET 请求重定向到 GitHub（浏览器）
- ✅ POST 请求生成命令
- ✅ 健康检查端点 `/health`

---

### main.sh 安全引擎测试策略

#### 优先级 P0: 阻止规则（8 条）
**测试目标**：确保危险命令被正确阻止

**测试用例模板**：
```bash
@test "Security: Block rule - rm -rf /" {
  run _fuck_security_evaluate_command "rm -rf /"
  assert_output --partial "block|"
  assert_output --partial "Recursive delete targeting root"
}
```

**8 条阻止规则测试**：
1. ✅ `rm -rf /` 递归删除根目录
2. ✅ `rm -rf /*` 使用通配符删除根目录
3. ✅ `rm -rf --no-preserve-root /` 强制删除根目录
4. ✅ `rm -rf .*` 删除隐藏/系统文件
5. ✅ `dd if=/dev/zero of=/dev/sda` 原始磁盘写入
6. ✅ `mkfs.ext4 /dev/sda` 格式化文件系统
7. ✅ `fdisk /dev/sda` 分区管理命令
8. ✅ `:(){ :|:& };:` Fork 炸弹

#### 优先级 P0: 挑战规则（9 条）
**测试目标**：确保高风险命令需要确认

**9 条挑战规则测试**：
1. ✅ `curl ... | bash` 远程脚本执行
2. ✅ `wget ... | sh` 远程脚本执行
3. ✅ `source https://...` 远程文件引入
4. ✅ `eval "..."` 显式 eval
5. ✅ `$(command)` 命令替换
6. ✅ `` `command` `` 反引号替换
7. ✅ `bash -c "..."` 嵌套 shell
8. ✅ `python -c "..."` 内联解释器
9. ✅ `rm /etc/passwd` 操作关键系统路径

#### 优先级 P1: 警告规则（4 条）
**测试目标**：确保潜在危险命令显示警告

**4 条警告规则测试**：
1. ✅ `rm -rf ...` 递归删除
2. ✅ `chmod 777` 世界可写权限
3. ✅ `sudo rm -rf` sudo + 递归删除
4. ✅ `> /etc/passwd` 重定向到敏感文件

#### 优先级 P1: 模式应用
**测试用例**：
- ✅ `strict` 模式：warn → challenge, challenge → block
- ✅ `balanced` 模式（默认）：保持原样
- ✅ `off` 模式：全部通过
- ✅ 白名单匹配：绕过检查

---

### 构建脚本测试策略

#### 优先级 P0: build.sh 分隔符脆弱性
**测试目标**：确保 base64 内容不会破坏 sed 命令

**测试用例**：
```bash
@test "Build: sed delimiter robustness" {
  # 创建包含特殊字符的测试脚本
  echo '#!/bin/bash\necho "test#with#delimiters"' > test_main.sh

  # 执行构建（应该成功）
  run bash scripts/build.sh
  assert_success

  # 验证 worker.js 被正确更新
  run grep "const INSTALLER_SCRIPT = b64_to_utf8" worker.js
  assert_success
}
```

#### 优先级 P0: one-click-deploy.sh Python 注入
**测试目标**：确保用户输入不会注入 Python 代码

**测试用例**：
```bash
@test "Deploy: Python injection prevention" {
  # 尝试注入恶意 Python 代码
  export QUOTA_LIMIT='"; import os; os.system("whoami"); "'

  # 执行部署脚本（应该失败或清理输入）
  run bash scripts/one-click-deploy.sh --dry-run

  # 验证没有执行注入的代码
  refute_output --partial "whoami"
}
```

---

## 🚀 实施计划

### Phase 1: 基础设施搭建（Day 1）
1. ✅ 创建 `tests/` 目录结构
2. ✅ 安装 Vitest + Miniflare
3. ✅ 安装 bats-core + 扩展
4. ✅ 创建 `vitest.config.js`
5. ✅ 创建 `.bats/setup.bash`
6. ✅ 更新 `package.json` 添加测试脚本

### Phase 2: Worker 测试（Day 2）
1. ✅ 编写配额管理测试（内存 + KV）
2. ✅ 编写 locale 检测测试
3. ✅ 编写请求处理测试
4. ✅ 运行测试并达到 80%+ 覆盖率

### Phase 3: Bash 安全引擎测试（Day 3）
1. ✅ 编写 8 条阻止规则测试
2. ✅ 编写 9 条挑战规则测试
3. ✅ 编写 4 条警告规则测试
4. ✅ 编写模式切换测试
5. ✅ 运行测试并达到 100% 规则覆盖

### Phase 4: 构建脚本修复与测试（Day 4）
1. ✅ 修复 build.sh sed 分隔符问题
2. ✅ 修复 one-click-deploy.sh Python 注入
3. ✅ 为修复编写回归测试
4. ✅ 验证所有构建脚本安全

### Phase 5: 集成与 CI（Day 5）
1. ✅ 编写端到端测试
2. ✅ 配置 GitHub Actions（可选）
3. ✅ 生成测试覆盖率报告
4. ✅ 更新项目文档

---

## 📝 package.json 更新方案

### 新增依赖
```json
{
  "devDependencies": {
    "vitest": "^1.0.0",
    "miniflare": "^3.0.0",
    "@cloudflare/workers-types": "^4.0.0",
    "c8": "^9.0.0",
    "bats": "^1.10.0",
    "bats-support": "^0.3.0",
    "bats-assert": "^2.1.0",
    "wrangler": "^3.80.0"
  }
}
```

### 新增脚本
```json
{
  "scripts": {
    "test": "npm run test:js && npm run test:bash",
    "test:js": "vitest run",
    "test:js:watch": "vitest watch",
    "test:js:coverage": "vitest run --coverage",
    "test:bash": "bats tests/unit/bash tests/integration",
    "test:security": "bats tests/unit/bash/security.bats",
    "test:build": "bats tests/integration/build-deploy.bats",
    "test:all": "npm run test && npm run test:js:coverage",
    "build": "bash scripts/build.sh",
    "deploy": "bash scripts/deploy.sh",
    "one-click-deploy": "bash scripts/one-click-deploy.sh",
    "setup": "bash scripts/setup.sh",
    "dev": "wrangler dev"
  }
}
```

---

## 🎯 测试覆盖率目标

### 最低要求
- **worker.js**: 80% 行覆盖率, 100% 关键功能覆盖
- **main.sh 安全引擎**: 100% 规则覆盖
- **构建脚本**: 80% 关键路径覆盖

### 衡量标准
- 使用 `c8` 生成 JavaScript 覆盖率报告
- 使用 bats TAP 输出验证测试通过率
- 所有 P0 漏洞必须有对应的测试用例

---

## ✅ 验证清单

### 本地验证（强制）
- [ ] `npm run test` 全部通过
- [ ] `npm run test:security` 21 条规则全部覆盖
- [ ] `npm run test:js:coverage` 达到 80%+
- [ ] 所有 P0 漏洞有回归测试

### CI 验证（可选）
- [ ] GitHub Actions 集成
- [ ] 自动生成覆盖率徽章

---

## 📚 参考资料

- [Vitest 官方文档](https://vitest.dev/)
- [Miniflare 文档](https://miniflare.dev/)
- [bats-core GitHub](https://github.com/bats-core/bats-core)
- [Cloudflare Workers Testing](https://developers.cloudflare.com/workers/testing/)

---

## 🔒 符合 CLAUDE.md 规范

本设计完全符合项目 `/Users/adair/Projects/fuckits/CLAUDE.md` 的强制要求：

✅ **强制验证机制**:
- 所有测试本地执行，拒绝远程 CI 依赖
- 每次改动提供可重复的验证步骤
- 测试覆盖不足时记录补偿计划

✅ **测试规范**:
- 提供自动运行的单元测试
- 覆盖正常流程、边界条件、错误恢复
- 防止破坏性变更遗漏关键分支

✅ **实现标准**:
- 禁止 MVP/最小实现
- 完成全量功能测试
- 提供回滚方案

---

**设计完成时间**: 2025-12-12
**实施完成时间**: 2026-02-03
