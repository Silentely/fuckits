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

在 Cloudflare Dashboard 中配置自定义域名：
- `fuckit.sh` → 英文版本
- `zh.fuckit.sh` → 中文版本

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
| `OPENAI_API_KEY` | ✅ 是 | - | OpenAI API 密钥 |
| `OPENAI_API_MODEL` | ❌ 否 | `gpt-4-turbo` | 使用的 AI 模型 |
| `OPENAI_API_BASE` | ❌ 否 | `https://api.openai.com/v1` | API 基础 URL |

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

Set up custom domains in Cloudflare Dashboard:
- `fuckit.sh` → English version
- `zh.fuckit.sh` → Chinese version

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
