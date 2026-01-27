# 部署指南 / Deployment Guide

[English](#english) | [简体中文](#简体中文)

---

## 简体中文

### 快速部署（一键部署）

使用一键部署脚本自动完成所有配置：

```bash
npm run one-click-deploy
```

这个脚本会自动：
1. ✅ 检查系统依赖
2. 📦 安装 npm 包
3. 🔐 引导您登录 Cloudflare
4. 🔑 配置 OpenAI API 密钥
5. 🔨 构建 Worker
6. ☁️ 部署到 Cloudflare

### 手动部署

如果你想手动控制每个步骤：

#### 1. 准备环境

确保你已安装：
- Node.js (>= 18.0.0)
- npm
- curl

#### 2. 安装依赖

```bash
npm install
```

#### 3. 配置 Cloudflare

登录到 Cloudflare：

```bash
npx wrangler login
```

#### 4. 配置 OpenAI API 密钥

设置你的 OpenAI API 密钥：

```bash
npx wrangler secret put OPENAI_API_KEY
```

> [!TIP]
> **关于 API 密钥的使用说明：**
>
> 这个密钥用于共享 Worker 演示模式，提供每天 200 次的免费体验额度。
>
> **推荐用户配置本地密钥：**
> - 运行 `fuck config` 查看配置文件位置
> - 在 `~/.fuck/config.sh` 中设置 `FUCK_OPENAI_API_KEY`
> - 配置后 CLI 将直接使用用户自己的密钥，无使用限制
> - 配置文件自动设置为 `chmod 600` 权限，确保密钥安全

**可选：配置管理员免限额密钥**

```bash
npx wrangler secret put ADMIN_ACCESS_KEY
```

> 将该密钥只分享给信任的同事，并指导他们在 `~/.fuck/config.sh` 中设置 `FUCK_ADMIN_KEY`。一旦两端匹配，该用户的请求将直接跳过共享 200 次/日的限额。

**可选：配置共享 Worker 的每日限额**

```bash
# 设置共享演示模式的每日调用限制（默认 200 次）
npx wrangler secret put SHARED_DAILY_LIMIT
```

**可选配置：**

自定义 AI 模型（默认：gpt-5-nano）：
```bash
npx wrangler secret put OPENAI_API_MODEL
```

自定义 API 基础 URL（用于代理或其他 API）：
```bash
npx wrangler secret put OPENAI_API_BASE
```

#### 5. 构建 Worker

```bash
npm run build
```

这会将 `main.sh` 和 `zh_main.sh` 编码并嵌入到 `worker.js` 中。

#### 6. 部署

```bash
npm run deploy
```

或直接使用 wrangler：

```bash
npx wrangler deploy
```

#### 7. 配置自定义域名

在 Works（Cloudflare Workers）Dashboard 中绑定自定义域名：
- `fuckits.25500552.xyz` → 主入口（英文）
- `fuckits.25500552.xyz/zh` → 通过路径提供中文版本（无需额外域名）

绑定后，运行以下命令确认 Worker 已正常响应：

```bash
curl -sS https://fuckits.25500552.xyz/health | jq
```

如果返回 `status: ok` 且 `services.apiKey: true`，说明 DNS 与 secret 均已正确配置。响应还包含 `stats.totalCalls` 和 `stats.uniqueIPs` 显示当日使用统计。

> 注意：Custom Domain 仅支持裸域名（`fuckits.25500552.xyz`），不要在 `wrangler.toml` 或 Dashboard 中添加 `*` 或 `/zh`，否则部署会直接报错。`/zh` 路由由 Worker 脚本处理。

### 开发模式

在本地运行开发服务器：

```bash
npm run dev
```

### 更新部署

当你修改了 `main.sh` 或 `zh_main.sh`：

```bash
npm run deploy
```

这会自动重新构建并部署。

### GitHub Actions 自动部署

如果你想让 Cloudflare 部署在 CI 中自动完成，同时又不把真实的 `wrangler.toml` 放在仓库里，可以按下面步骤配置：

1. 将完整的 `wrangler.toml`（包含 `account_id`、`name`、`routes`、`kv_namespaces` 等字段）保存到私有 gist 或任何可被 GitHub Actions 读取的 URL，记录它的 **原始链接**。
2. 进入 GitHub 仓库 → `Settings → Secrets and variables → Actions`：
   - 建议直接在 **Secrets** 中新增 `WRANGLER_TOML_URL`（可避免链接被明文变量曝光）；如果一定要用 Variables，也同样受支持。
   - 另外新增 `CLOUDFLARE_API_TOKEN`（需要 `Workers Scripts:Edit`、`Workers KV Storage:Edit` 权限）。如果 `wrangler.toml` 里没有 `account_id` 字段，再额外添加 `CLOUDFLARE_ACCOUNT_ID` secret。
3. 推送或合并到 `main` 时，`.github/workflows/deploy.yml` 会自动运行，执行 `npm ci → npm run build → curl 远程 toml → npx wrangler deploy --config wrangler.ci.toml`。Pull Request 仍会执行构建验证，但部署步骤会自动跳过。
4. 需要立即触发部署时，打开 GitHub → Actions → **Deploy to Cloudflare Works** → `Run workflow` 即可复用同一套变量和 secret。

> [!IMPORTANT]
> - `WRANGLER_TOML_URL` 未设置时，workflow 会第一时间失败并提醒你补齐。
> - 缺少 `CLOUDFLARE_API_TOKEN` 会阻止 `wrangler deploy`，避免把流量打到未知账号。
> - workflow 会把下载的 `wrangler.ci.toml` 写在临时文件中，部署结束后立即删除。

> [!WARNING]
> 还是推荐使用 `wrangler secret put` 来设置 `OPENAI_API_KEY` / `ADMIN_ACCESS_KEY` 等敏感值，而不是写入 `[vars]`。如果确实留在 `wrangler.toml`，工作流会在部署前自动将这些值加入掩码，避免它们在 GitHub Log 中裸露，但最安全的方案仍是改用 Secrets。

### 环境变量

在 Cloudflare Workers 中配置的环境变量：

| 变量名 | 必需 | 默认值 | 说明 |
|--------|------|--------|------|
| `OPENAI_API_KEY` | ✅ 是 | - | OpenAI API 密钥（用于共享演示模式） |
| `OPENAI_API_MODEL` | ❌ 否 | `gpt-5-nano` | 使用的 AI 模型 |
| `OPENAI_API_BASE` | ❌ 否 | `https://api.openai.com/v1` | API 基础 URL |
| `SHARED_DAILY_LIMIT` | ❌ 否 | `200` | 共享演示模式的每日调用限制 |
| `ADMIN_ACCESS_KEY` | ❌ 否 | - | 管理员免限额度密钥，配合 CLI 中的 `FUCK_ADMIN_KEY` 使用 |

> [!NOTE]
> **关于限流机制：**
> - Worker 使用内存 Map 实现简单的 IP 级别限流
> - 每天 UTC 00:00 自动重置配额
> - 达到限制时返回 HTTP 429 状态码
> - 用户可通过配置本地 API 密钥绕过限制

#### 有关 KV 限流

为了让 `SHARED_DAILY_LIMIT` 在不同 PoP/实例间保持一致，建议为 Worker 绑定一个名为 `QUOTA_KV` 的 Cloudflare KV 命名空间（若你坚持使用其他名字，可以在 `[vars]` 中添加 `QUOTA_KV_BINDING="实际绑定名"`）：

```bash
npx wrangler kv:namespace create QUOTA_KV
npx wrangler kv:namespace create QUOTA_KV --preview
```

然后在 `wrangler.toml` 中添加（替换为命令输出的 `id/preview_id`）：

```toml
[[kv_namespaces]]
binding = "QUOTA_KV"
id = "<production-id>"
preview_id = "<preview-id>"
```

若未配置 KV，Worker 会降级为内存 Map 计数，在 Cloudflare 启动新实例或跨 PoP 转发时可能“忘记”已有调用次数，只能作为临时演示用。

### 故障排查

### 问题：构建失败

确保 `main.sh` 和 `zh_main.sh` 文件存在且可读。

### 问题：部署失败

1. 检查是否已登录 Cloudflare：`npx wrangler whoami`
2. 确认 `wrangler.toml` 配置正确
3. 检查网络连接

### 问题：API 调用失败

1. 确认已设置 `OPENAI_API_KEY`
2. 检查 API 密钥是否有效
3. 查看 Cloudflare Workers 日志

### 问题：用户报告配额限制

1. 提示用户运行 `fuck config` 配置本地密钥
2. 检查 Worker 的 `SHARED_DAILY_LIMIT` 设置
3. 查看 Worker 日志确认限流是否正常工作

### 问题：本地 API 密钥模式不工作

1. 确认用户已在 `~/.fuck/config.sh` 中正确设置 `FUCK_OPENAI_API_KEY`
2. 检查配置文件权限是否为 600
3. 确认用户系统中安装了 python3 或 node（用于 JSON 解析）
4. 运行 `FUCK_DEBUG=true fuck <命令>` 查看详细日志

---

## English

### Quick Deploy (One-Click)

Use the one-click deploy script to automate everything:

```bash
npm run one-click-deploy
```

This script will automatically:
1. ✅ Check system dependencies
2. 📦 Install npm packages
3. 🔐 Guide you through Cloudflare login
4. 🔑 Configure OpenAI API key
5. 🔨 Build the Worker
6. ☁️ Deploy to Cloudflare

### Manual Deployment

If you prefer manual control over each step:

#### 1. Prerequisites

Ensure you have installed:
- Node.js (>= 18.0.0)
- npm
- curl

#### 2. Install Dependencies

```bash
npm install
```

#### 3. Configure Cloudflare

Login to Cloudflare:

```bash
npx wrangler login
```

#### 4. Configure OpenAI API Key

Set your OpenAI API key:

```bash
npx wrangler secret put OPENAI_API_KEY
```

> [!TIP]
> This secret only powers the shared demo Worker (200 calls/day). Ask end users to run `fuck config` and set `FUCK_OPENAI_API_KEY` in `~/.fuck/config.sh` so the CLI uses their own key.

**Optional: Admin bypass secret**

```bash
npx wrangler secret put ADMIN_ACCESS_KEY
```

> Hand this token only to trusted teammates. Anyone who adds the same value to `FUCK_ADMIN_KEY` inside `~/.fuck/config.sh` will skip the 200 calls/day shared limit.

**Optional Configuration:**

Custom AI model (default: gpt-5-nano):
```bash
npx wrangler secret put OPENAI_API_MODEL
```

Custom API base URL (for proxies or alternative APIs):
```bash
npx wrangler secret put OPENAI_API_BASE
```

#### 5. Build the Worker

```bash
npm run build
```

This embeds `main.sh` and `zh_main.sh` into `worker.js` as base64 strings.

#### 6. Deploy

```bash
npm run deploy
```

Or use wrangler directly:

```bash
npx wrangler deploy
```

#### 7. Configure Custom Domains

Set up your Works (Cloudflare Workers) custom domain:
- `fuckits.25500552.xyz` → primary endpoint (English)
- `fuckits.25500552.xyz/zh` → Chinese endpoint exposed via the `/zh` path

Use the health endpoint to verify DNS/SSL propagation:

```bash
curl -sS https://fuckits.25500552.xyz/health | jq
```

Expect `status: ok` and `services.apiKey: true`. The response also includes `stats.totalCalls` and `stats.uniqueIPs` for daily usage statistics.

> Reminder: Cloudflare Custom Domains must be bare domains only. Do **not** include `*` or `/zh` in `wrangler.toml` or the dashboard; those requests are routed inside the Worker itself.

### Development Mode

Run local development server:

```bash
npm run dev
```

### Update Deployment

When you modify `main.sh` or `zh_main.sh`:

```bash
npm run deploy
```

This will automatically rebuild and redeploy.

### GitHub Actions Deployment

To keep the real `wrangler.toml` outside of the repo while still deploying automatically, follow these steps:

1. Store the complete `wrangler.toml` (with `account_id`, `name`, `routes`, KV bindings, etc.) inside a private gist or any URL accessible from GitHub Actions and copy its **raw** link.
2. Go to `Settings → Secrets and variables → Actions`:
   - **Recommended**: store `WRANGLER_TOML_URL` as a **secret** so the gist link never appears in logs. If you insist on a variable, the workflow now supports it as a fallback.
   - Still add `CLOUDFLARE_API_TOKEN` (needs at least `Workers Scripts:Edit` + `Workers KV Storage:Edit`). Add `CLOUDFLARE_ACCOUNT_ID` only if your gist omits the `account_id` field.
3. Every push/merge to `main` triggers `.github/workflows/deploy.yml`, which runs `npm ci → npm run build → curl remote toml → npx wrangler deploy --config wrangler.ci.toml`. Pull Requests still execute build verification but automatically skip the deploy step.
4. To redeploy on demand, open GitHub → Actions → **Deploy to Cloudflare Works** → `Run workflow`.

> [!NOTE]
> - Missing `WRANGLER_TOML_URL` or `CLOUDFLARE_API_TOKEN` makes the workflow fail immediately, preventing partial deployments.
> - The downloaded `wrangler.ci.toml` is removed as soon as the deploy step finishes.

> [!WARNING]
> Prefer `wrangler secret put` for sensitive values such as `OPENAI_API_KEY` / `ADMIN_ACCESS_KEY`. Keeping them inside `[vars]` works, and the workflow now masks any values it finds there, but secrets stored via Wrangler stay off disk and never appear in logs.

### Environment Variables

Environment variables configured in Cloudflare Workers:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | ✅ Yes | - | OpenAI API key |
| `OPENAI_API_MODEL` | ❌ No | `gpt-5-nano` | AI model to use |
| `OPENAI_API_BASE` | ❌ No | `https://api.openai.com/v1` | API base URL |
| `SHARED_DAILY_LIMIT` | ❌ No | `200` | Daily cap for the shared demo Worker |
| `ADMIN_ACCESS_KEY` | ❌ No | - | Maintainer bypass key (paired with CLI `FUCK_ADMIN_KEY`) |

#### KV-backed quota (recommended)

Keep demo limits consistent across all Cloudflare POPs by binding a KV namespace to your Worker (either name it `QUOTA_KV`, or keep your custom binding and add `QUOTA_KV_BINDING="<binding-name>"` under `[vars]`):

```bash
npx wrangler kv:namespace create QUOTA_KV
npx wrangler kv:namespace create QUOTA_KV --preview
```

Then update `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "QUOTA_KV"
id = "<production-id>"
preview_id = "<preview-id>"
```

When KV is unavailable the Worker falls back to the in-memory Map, which may reset whenever Cloudflare spins up a fresh isolate (tolerable for demos, but not a strict quota).

### Troubleshooting

### Issue: Build fails

Make sure `main.sh` and `zh_main.sh` files exist and are readable.

### Issue: Deploy fails

1. Check if logged in to Cloudflare: `npx wrangler whoami`
2. Verify `wrangler.toml` configuration
3. Check network connection

### Issue: API calls fail

1. Confirm `OPENAI_API_KEY` is set
2. Verify API key is valid
3. Check Cloudflare Workers logs
