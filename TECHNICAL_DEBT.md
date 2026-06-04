# 技术债务清单 (Technical Debt)

**项目**：fuckits
**生成日期**：2026-01-31
**最后更新**：2026-06-04
**负责人**：项目维护团队
**下次审查**：2026-07-01

---

## 📊 债务统计

| 严重级别 | 数量 | 预计修复时间 |
|---------|------|-------------|
| **Critical** | 0 | 0 小时 |
| **High** | 2 | 15-20 小时 |
| **Medium** | 3 | 27-42 小时 |
| **Low** | 5 | 15-22 小时 |
| **已完成** | 4 | - |
| **总计** | 10 (待处理) | 57-82 小时 |

---

## 🔴 High Priority (高优先级)

### **DEBT-001: 代码重复 - main.sh vs zh_main.sh**

**位置**：
- `/Users/adair/Projects/fuckits/main.sh` (1,752 行)
- `/Users/adair/Projects/fuckits/zh_main.sh` (1,735 行)

**问题描述**：
- 两个文件有 95%+ 的代码重复
- 仅差异在于语言文本和注释
- 每次修改需要同步两个文件，维护成本高

**影响**：
- ❌ 维护成本翻倍
- ❌ 容易引入不一致性
- ❌ 添加新语言需要复制文件

**建议解决方案**：
```bash
# 方案 A: 国际化（i18n）重构 ⭐ 推荐
main.sh (核心逻辑) + locales/en.json + locales/zh.json

# 收益
- 消除 95%+ 代码重复
- 易于添加新语言
- 维护成本降低 50%+

# 实施步骤
1. 创建 locales/ 目录
2. 提取所有字符串到 JSON 文件
3. 实现 _fuck_localize() 函数
4. 更新所有字符串调用
5. 测试两种语言
```

**预计工作量**：15-20 小时
**风险等级**：中（需要大规模重构）
**依赖**：无

---

### **DEBT-002: Worker.js 文件过大（base64 嵌入脚本）**

**位置**：`/Users/adair/Projects/fuckits/worker.js`

**问题描述**：
- worker.js 文件大小 174 KB
- 包含 base64 编码的安装脚本（~154 KB）
- 影响冷启动时间

**影响**：
- ❌ 冷启动时间增加（~100-300ms）
- ❌ 修改脚本需要重新构建 Worker
- ❌ 部署时间较长

**建议解决方案**：
```javascript
// 方案 A: CDN 分发脚本 ⭐ 推荐
async function handleGetRequest(url, request) {
  const locale = url.pathname.startsWith('/zh') ? 'zh' : 'en';
  const scriptUrl = `https://cdn.fuckits.xyz/${locale}/main.sh`;
  const response = await fetch(scriptUrl);

  return new Response(response.body, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' }
  });
}

// 方案 B: R2 对象存储
const script = await env.SCRIPTS_BUCKET.get(`${locale}/main.sh`);
```

**预计工作量**：3-4 小时
**风险等级**：低
**依赖**：需要配置 CDN 或 R2

---

### ~~**DEBT-003: API 错误响应不友好**~~ ✅ 已完成 (2026-06-04)

**位置**：`worker.js`

**✅ 已实施解决方案**：
- 统一结构化 JSON 错误响应格式（code, message, requestId, timestamp）
- 所有 console.error 日志已统一为结构化 JSON 格式
- 错误码映射已实现（ERROR_CODES）

**完成时间**：2026-06-04
**实际工作量**：2 小时

---

## 🟡 Medium Priority (中优先级)

### **DEBT-004: 配额管理性能瓶颈**

**位置**：`worker.js` 配额检查逻辑

**问题描述**：
- 内存 Map：跨实例不一致
- KV 存储：延迟较高（~10-50ms）

**影响**：
- ⚠️ 配额计数不准确（内存模式）
- ⚠️ 高并发场景性能下降

**建议解决方案**：
```javascript
// 方案 A: Durable Objects ⭐ 推荐
export class QuotaManager {
  constructor(state, env) {
    this.state = state;
    this.storage = state.storage;
  }

  async checkLimit(ip, limit) {
    const today = new Date().toISOString().slice(0, 10);
    const key = `${ip}:${today}`;
    const count = (await this.storage.get(key)) || 0;

    if (count >= limit) {
      return { allowed: false, remaining: 0 };
    }

    await this.storage.put(key, count + 1);
    return { allowed: true, remaining: limit - count - 1 };
  }
}
```

**预计工作量**：8-12 小时
**风险等级**：中
**依赖**：需要学习 Durable Objects

---

### **DEBT-005: 安全规则硬编码**

**位置**：`main.sh` `_fuck_security_evaluate_command()` 函数

**问题描述**：
- 21 条安全规则硬编码在脚本中
- 添加规则需要修改核心代码

**影响**：
- ⚠️ 用户无法自定义规则
- ⚠️ 更新规则需要重新部署

**建议解决方案**：
```bash
# ~/.fuck/security-rules.json
{
  "rules": [
    {
      "pattern": "rm -rf /",
      "severity": "block",
      "message": "危险命令检测：递归删除根目录"
    }
  ]
}

# 动态加载
_fuck_security_load_rules() {
  if [ -f "$HOME/.fuck/security-rules.json" ]; then
    CUSTOM_RULES=$(jq -r '.rules[]' "$HOME/.fuck/security-rules.json")
  fi
}
```

**预计工作量**：6-8 小时
**风险等级**：低
**依赖**：DEBT-001（i18n 重构后更容易实现）

---

### ~~**DEBT-006: AI 响应无缓存**~~ ✅ 已完成 (2026-02-03)

**位置**：`worker.js` AI 推理逻辑

**问题描述**：
- 相同的提示词每次都调用 OpenAI API
- 浪费成本和响应时间

**影响**：
- ⚠️ API 调用成本高
- ⚠️ 响应时间长（~2s）

**✅ 已实施解决方案**：
```javascript
// 缓存键生成 (SHA-256 + locale)
const cacheKey = await generateCacheKey(prompt, sysinfo, model, locale);

// 缓存查找
const cachedCommand = await getCachedResponse(cacheKey, env);
if (cachedCommand) {
  ctx.waitUntil(incrementCacheStats('hit', env)); // 异步统计
  return new Response(cachedCommand, {
    headers: { 'X-Cache-Status': 'HIT' }
  });
}

// AI 调用后存入缓存
ctx.waitUntil(setCachedResponse(cacheKey, cleanedCommand, env)); // 异步写入
```

**实施成果**：
- ✅ KV namespace AI_CACHE 已配置
- ✅ SHA-256 缓存键生成（包含 locale 支持）
- ✅ 24 小时 TTL 过期策略
- ✅ 缓存命中率统计（健康检查端点，并行读取优化）
- ✅ 9 个测试覆盖缓存功能（含 locale 和错误场景）
- ✅ 文档已更新（API.md, MONITORING.md）
- ✅ Codex 代码审查通过并完成优化

**性能提升**：
- 缓存命中响应时间：~40-80ms（比 API 调用快 25-50 倍）
- getCacheStats 并行读取：延迟减半（~10-50ms vs ~20-100ms）
- ctx.waitUntil 异步操作：缓存写入和统计更新不阻塞响应
- 预期缓存命中率：60-80%
- 预计成本节省：40-60%

**Codex 审查优化**（2026-02-03）：
- 🔴 Critical: Locale 包含在缓存键中（避免跨语言缓存混淆）
- 🔴 Critical: wrangler.toml 配置说明完善
- 🟡 Warning: 测试覆盖增强（真实错误场景、locale 测试）
- 💡 Optimization: Promise.all 并行化 KV 读取
- 💡 Optimization: ctx.waitUntil 异步处理缓存写入和统计

**完成时间**：2026-02-03
**实际工作量**：6 小时（含 Codex 审查和优化）
**风险等级**：低
**依赖**：无

---

### **DEBT-007: 系统信息缓存未充分利用**

**位置**：`main.sh` 系统信息收集逻辑

**问题描述**：
- 已实现 `~/.fuck/.sysinfo.cache`
- 仅缓存部分系统信息

**影响**：
- ⚠️ 每次启动仍执行较多检测命令
- ⚠️ 启动时间可进一步优化

**建议解决方案**：
```bash
# 扩展缓存内容
_sysinfo_cache_keys=(
  "OS" "Distro" "PkgMgr" "Shell" "CPU_Arch"
  "Disk_Space" "Memory" "Hostname" "Username"
)

_fuck_persist_extended_cache() {
  # 缓存更多静态信息
}
```

**预计工作量**：2-3 小时
**风险等级**：低
**依赖**：无

---

### **DEBT-008: 测试覆盖缺口 - 真实 API 测试**

**位置**：`tests/` 目录

**问题描述**：
- 所有 OpenAI API 调用使用 Mock
- 缺少真实 API 集成测试

**影响**：
- ⚠️ 无法发现真实 API 兼容性问题
- ⚠️ 测试覆盖率虚高

**建议解决方案**：
```javascript
// tests/integration/openai-api.test.js
describe('OpenAI API 集成测试', () => {
  it('应该成功调用真实 OpenAI API', async () => {
    // 使用测试 API Key
    const response = await callRealOpenAI(prompt);

    expect(response.command).toBeTruthy();
    expect(response.explanation).toBeTruthy();
  });
});
```

**预计工作量**：4-6 小时
**风险等级**：低
**依赖**：需要 OpenAI 测试 Key

---

## 🟢 Low Priority (低优先级)

### **DEBT-009: 文档缺失 - ARCHITECTURE.md**

**位置**：项目根目录

**问题描述**：
- 缺少架构决策记录（ADR）
- 架构演进历史未记录

**建议解决方案**：
```markdown
# docs/ARCHITECTURE.md

## 架构决策记录（ADR）

### ADR-001: 单体架构 vs 微服务
**状态**: 已接受
**日期**: 2024-01-01
**决策**: 采用单体 Cloudflare Worker 架构
**原因**: 简单、快速、成本低

### ADR-002: 脚本嵌入 vs CDN 分发
**状态**: 待审查
**日期**: 2025-01-31
**决策**: 考虑迁移到 CDN 分发
**原因**: 优化 Worker 大小和冷启动时间
```

**预计工作量**：3-4 小时
**风险等级**：低
**依赖**：无

---

### **DEBT-010: 性能基准测试未完全覆盖**

**位置**：`tests/performance/`

**问题描述**：
- 仅有配额管理性能测试
- 缺少其他关键路径的性能基准

**建议解决方案**：
```javascript
// 添加性能测试
describe('Worker 冷启动性能', () => {
  it('应该在 150ms 内完成冷启动', async () => {
    const start = Date.now();
    await mf.dispatchFetch(new Request('http://localhost/'));
    const duration = Date.now() - start;

    expect(duration).toBeLessThan(150);
  });
});

describe('AI 推理性能', () => {
  it('应该在 3s 内返回响应', async () => {
    // 测试 AI 响应时间
  });
});
```

**预计工作量**：4-6 小时
**风险等级**：低
**依赖**：无

---

### ~~**DEBT-011: 错误日志分散**~~ ✅ 已完成 (2026-06-04)

**位置**：`worker.js`

**✅ 已实施解决方案**：
- 所有 console.log 调用已使用 JSON.stringify 结构化格式
- 所有 console.error 调用已统一为 `{event, level, message, error, timestamp}` 格式
- 事件类型包括：quota_check, quota_persist_failed, stats_kv_read_failed, cache_read_error, cache_write_error, cache_stats_error, cache_stats_flush_error, ai_api_error, internal_error, command_blocked_server_side, cache_miss, cache_hit

**完成时间**：2026-06-04
**实际工作量**：1 小时

---

### **DEBT-012: 配置文件版本管理**

**位置**：`~/.fuck/config.sh`

**问题描述**：
- 旧版本用户可能缺少新配置项
- 没有配置迁移机制

**建议解决方案**：
```bash
# config.sh 版本号
export FUCK_CONFIG_VERSION="2.0.0"

_fuck_migrate_config() {
  local version="${FUCK_CONFIG_VERSION:-1.0.0}"

  if [[ "$version" < "2.0.0" ]]; then
    # 添加新配置项
    echo "正在迁移配置到 v2.0.0..."
    _fuck_append_config_hint "FUCK_ADMIN_KEY" "管理员密钥" '' 0
  fi
}
```

**预计工作量**：2-3 小时
**风险等级**：低
**依赖**：无

---

## 📈 债务偿还优先级矩阵

| 债务编号 | 影响力 | 工作量 | ROI 优先级 |
|---------|--------|--------|----------|
| DEBT-001 | 高 | 15-20h | **1** |
| DEBT-002 | 中 | 3-4h | **2** |
| DEBT-005 | 中 | 6-8h | **3** |
| DEBT-004 | 中 | 8-12h | **4** |
| DEBT-007 | 低 | 2-3h | **5** |
| DEBT-008 | 低 | 4-6h | **6** |
| DEBT-013 | 低 | 4-6h | **7** |
| DEBT-009 | 低 | 3-4h | **8** |
| DEBT-010 | 低 | 4-6h | **9** |
| DEBT-012 | 低 | 2-3h | **10** |

---

## 🔄 债务审查流程

**月度审查**（每月最后一周）：
1. 检查债务清单完整性
2. 更新已解决的债务
3. 评估新增债务
4. 调整优先级

**解决标准**：
- ✅ 修复代码
- ✅ 添加/更新测试
- ✅ 更新文档
- ✅ 代码审查通过
- ✅ CI/CD 测试通过

---

## 🆕 新增债务项

### **DEBT-013: CLI 缺少 Agent 友好性** ⚠️ 部分完成

**位置**：`main.sh`, `zh_main.sh`

**问题描述**：
- 2026 年 AI Agent 成为 CLI 工具的主要用户之一
- fuckits 作为 AI 驱动的工具，CLI 接口未针对 Agent 使用场景优化

**✅ 已实施**：
- SKILL.md 已创建（AI Agent 使用指南）
- `--json` 输出支持已添加（version, history, history search, favorite list, 主命令）
- stdout/stderr 分离已实现
- 结构化 JSON 错误响应

**⚠️ 待完善**：
- 有意义的退出码分类（当前仅 0/1/2）
- `fuck --help --json` 输出完整命令目录
- Breadcrumb 引导（JSON 输出中包含 next_commands 建议）

**预计工作量**：4-6 小时（剩余部分）
**风险等级**：低

---

### ~~**DEBT-014: compatibility_date 过期**~~ ✅ 已完成 (2026-06-04)

**位置**：`wrangler.toml`

**✅ 已实施**：
- compatibility_date 更新至 2026-06-01
- nodejs_compat 标志已启用

**完成时间**：2026-06-04
**实际工作量**：0.5 小时

---

## 📊 债务趋势追踪

| 日期 | Critical | High | Medium | Low | 已完成 | 总计(待处理) |
|------|----------|------|--------|-----|--------|-------------|
| 2026-01-31 | 0 | 3 | 5 | 4 | 1 | 12 |
| 2026-02-03 | 0 | 2 | 4 | 4 | 2 | 10 |
| 2026-06-04 | 0 | 2 | 3 | 5 | 4 | 10 |

---

**最后更新**：2026-06-04
**下次审查**：2026-07-01
**负责人**：项目维护团队
