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
> 这个密钥用于共享 Worker 演示模式，提供每天 10 次的免费体验额度。
>
> **推荐用户配置本地密钥：**
> - 运行 `fuck config` 查看配置文件位置
> - 在 `~/.fuck/config.sh` 中设置 `FUCK_OPENAI_API_KEY`
> - 配置后 CLI 将直接使用用户自己的密钥，无使用限制
> - 配置文件自动设置为 `chmod 600` 权限，确保密钥安全

**可选：配置共享 Worker 的每日限额**

```bash
# 设置共享演示模式的每日调用限制（默认 10 次）
npx wrangler secret put SHARED_DAILY_LIMIT
```

**可选配置：**

自定义 AI 模型（默认：gpt-4-turbo）：
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

如果返回 `status: ok` 且 `hasApiKey: true`，说明 DNS 与 secret 均已正确配置。

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

### 环境变量

在 Cloudflare Workers 中配置的环境变量：

| 变量名 | 必需 | 默认值 | 说明 |
|--------|------|--------|------|
| `OPENAI_API_KEY` | ✅ 是 | - | OpenAI API 密钥（用于共享演示模式） |
| `OPENAI_API_MODEL` | ❌ 否 | `gpt-4-turbo` | 使用的 AI 模型 |
| `OPENAI_API_BASE` | ❌ 否 | `https://api.openai.com/v1` | API 基础 URL |
| `SHARED_DAILY_LIMIT` | ❌ 否 | `10` | 共享演示模式的每日调用限制 |

> [!NOTE]
> **关于限流机制：**
> - Worker 使用内存 Map 实现简单的 IP 级别限流
> - 每天 UTC 00:00 自动重置配额
> - 达到限制时返回 HTTP 429 状态码
> - 用户可通过配置本地 API 密钥绕过限制

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
> This secret only powers the shared demo Worker (10 calls/day). Ask end users to run `fuck config` and set `FUCK_OPENAI_API_KEY` in `~/.fuck/config.sh` so the CLI uses their own key.

**Optional Configuration:**

Custom AI model (default: gpt-4-turbo):
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

Expect `status: ok` and `hasApiKey: true`.

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

### Environment Variables

Environment variables configured in Cloudflare Workers:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | ✅ Yes | - | OpenAI API key |
| `OPENAI_API_MODEL` | ❌ No | `gpt-4-turbo` | AI model to use |
| `OPENAI_API_BASE` | ❌ No | `https://api.openai.com/v1` | API base URL |

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
