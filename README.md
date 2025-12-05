<h1 align="center">fuckits</h1>

<p align="center">
  <a href="./README.en.md">English</a> | <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://github.com/faithleysath/fuckit.sh/stargazers">
    <img src="https://img.shields.io/github/stars/faithleysath/fuckit.sh?style=social" alt="GitHub Stars">
  </a>
  <a href="https://github.com/faithleysath/fuckit.sh/network/members">
    <img src="https://img.shields.io/github/forks/faithleysath/fuckit.sh?style=social" alt="GitHub Forks">
  </a>
  <a href="https://github.com/faithleysath/fuckit.sh/commits/main">
    <img src="https://img.shields.io/github/last-commit/faithleysath/fuckit.sh" alt="GitHub last commit">
  </a>
  <a href="https://github.com/faithleysath/fuckit.sh/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/faithleysath/fuckit.sh" alt="License">
  </a>
</p>

> [!IMPORTANT]
> **本项目正在重构中**
> 
> 受[Linux.do佬友们的启发和建议](https://linux.do/t/topic/1099746)，此项目将用[Amber](https://amber-lang.com)语言重构，并加入完善的版本管理、更新提示，以及自定义llm key，自定义alias、个人偏好设置、ui风格（猫娘、御姐等）等更多新功能。

**我他妈忘了那条命令了。**

`fuckits` 是一个基于 AI 的命令行工具，它能将你的自然语言描述直接转换成可执行的 Shell 命令。

当你懒得去查 `man` 手册或者在 Google 上搜索时，直接 `fuck` 就完事了。

**本项目完全免费，你无需提供自己的 OpenAI API Key 即可直接使用。**


## 预览

![预览](preview.gif)


## 功能特性

*   **自然语言转换**: 直接将你的日常语言转换成可执行的 Shell 命令。
*   **AI 驱动**: 利用大语言模型的强大能力，理解复杂指令。
*   **交互式确认**: 在执行任何命令之前，都会显示并请求你的确认，确保安全。
*   **双模式运行**: 支持一键安装以长期使用，也支持无需安装的临时运行模式。
*   **跨平台支持**: 可在 macOS 和主流 Linux 发行版上运行。
*   **多语言**: 提供完整的中英文双语体验。
*   **智能上下文**: 自动检测操作系统、包管理器等信息，为 AI 提供更准确的上下文。
*   **轻松卸载**: 一条命令即可将脚本从你的系统中完全移除。

## 🔧 重构亮点

* `~/.fuck/config.sh` 配置文件：支持自定义 API 入口、命令别名、自动执行、超时时间等。
* 新增 `fuck config` 命令：一键定位配置文件并查看可用开关。
* 自动执行模式：`FUCK_AUTO_EXEC=true` 时可跳过确认（慎用）。
* 自定义别名：通过 `FUCK_ALIAS="pls"` 等配置添加更顺手的命令。
* CLI 与 Worker 构建脚本重构：`npm run build` 自动嵌入最新的安装脚本。
* 一键部署：`npm run one-click-deploy` 帮你完成依赖、登录、构建、部署全流程。

---

## 快速安装

选择你喜欢的语言版本，在终端里运行以下命令即可。

### 英文端点 (fuckits.25500552.xyz)

```bash
curl -sS https://fuckits.25500552.xyz | bash
```

### 中文端点 (fuckits.25500552.xyz/zh)

```bash
curl -sS https://fuckits.25500552.xyz/zh | bash
```

> [!NOTE]
> `fuckits.25500552.xyz` 通过 Works 自定义域映射到你部署的 Worker。按照本文档或 [DEPLOY.md](./DEPLOY.md#简体中文) 中的步骤重新部署后，域名会自动指向你的实例，中文脚本使用 `/zh` 路径。
> 自行部署时请在 `~/.fuck/config.sh` 中把 `FUCK_API_ENDPOINT` 改成你自己的域名，避免所有请求仍指向默认演示服务。

> [!WARNING]
> **安全提示**
> 
> 如果你不信任直接在 `| bash` 中运行脚本，可以分步操作：
> 1.  **下载**: `curl -o fuckit.sh https://fuckits.25500552.xyz`
> 2.  **瞅一眼**: `less fuckit.sh`
> 3.  **运行**: `bash fuckit.sh`

安装完成后，请重启你的终端或运行 `source ~/.bashrc` / `source ~/.zshrc` 来让命令生效。

---

## 使用方法

使用起来非常简单，格式如下：

```bash
fuck <你的需求>
```

AI 会返回它认为正确的命令，你确认后即可执行。

**示例:**

```bash
# 查找当前目录下所有大于 10MB 的文件
fuck find all files larger than 10MB in the current directory

# 安装 git (自动识别 apt/yum/brew 等)
fuck install git

# 卸载 git (同样会自动识别)
fuck uninstall git
```

### 配置脚本

查看配置文件位置和可用选项：

```bash
fuck config
```

配置文件位于 `~/.fuck/config.sh`，你可以在其中自定义：
- 自定义 API 端点（用于自建 Worker）
- 自动执行模式（跳过确认）
- 请求超时时间
- 调试模式
- 自定义别名

### 卸载脚本

如果你不想用我了，随时可以滚蛋：

```bash
fuck uninstall
```

---

### 临时使用 (无需安装)

如果你不想安装脚本，只想临时用一下，也可以直接通过 `curl` 运行。

**英文版:**
```bash
curl -sS https://fuckits.25500552.xyz | bash -s "你的需求"
```

**中文版:**
```bash
curl -sS https://fuckits.25500552.xyz/zh | bash -s "你的需求"
```

**示例:**
```bash
# 查找所有大于 10MB 的文件
curl -sS https://fuckits.25500552.xyz | bash -s "find all files larger than 10MB"
```

这种方式不会在你的系统上安装任何文件，命令会直接执行。

---

## 工作原理

1.  你在终端输入 `fuck <你的需求>`。
2.  脚本将你的需求和一些基本的系统信息（如操作系统、包管理器）发送到 Cloudflare Worker。
3.  Cloudflare Worker 调用 OpenAI API（或其他大语言模型）并将你的需求作为提示。
4.  AI 返回生成的 Shell 命令。
5.  脚本在终端显示这条命令，并等待你确认。
6.  你输入 `y`，命令被执行。世界和平。

---

## ☁️ 一键部署

只需一条命令即可完成依赖安装、Worker 构建和部署：

```bash
npm run one-click-deploy
```

脚本会引导你完成 Cloudflare 登录、设置 OpenAI Key，并自动将最新的 `main.sh`/`zh_main.sh` 嵌入 `worker.js`。需要了解更多细节可以阅读 [DEPLOY.md](./DEPLOY.md#简体中文)。

部署完成后，请在 Works（Cloudflare Workers）控制台中将 `fuckits.25500552.xyz` 绑定到该 Worker（中文版本通过 `/zh` 路径提供）。DNS/SSL 生效可能需要几分钟，可使用健康检查确保域名已指向你自己的 Worker：

```bash
curl -sS https://fuckits.25500552.xyz/health | jq
```

若返回 `status: "ok"` 且 `hasApiKey: true`，说明 Worker 能正确调用 OpenAI。否则请检查自定义域与 secret 设置。

> [!TIP]
> Fork 本项目时，自定义域名和 `FUCK_API_ENDPOINT` 也要替换成你自己的值。

### 部署后自检

1. 在 Cloudflare Dashboard → Custom Domains 绑定你的域名，并确认 `/zh` 路径路由到同一个 Worker。
2. 运行 `curl -sS https://<你的域>/health | jq`，确认 Status 与 `hasApiKey` 返回正常。
3. 使用 `curl -sS https://<你的域> | bash -s "echo ok"` 以及 `/zh` 版本做一次真实 round-trip。
4. 最后再运行 `fuck config`，把本地 CLI 的 `FUCK_API_ENDPOINT` 更新为新域。

---

## ⚙️ 配置说明

`~/.fuck/config.sh` 是你的专属开关面板。无论是安装版还是临时运行模式都支持该配置。

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `FUCK_API_ENDPOINT` | `https://fuckits.25500552.xyz/` | 自建或自定义 Worker 地址 |
| `FUCK_ALIAS` | `fuck` | 额外别名（不会影响默认别名，除非关闭） |
| `FUCK_AUTO_EXEC` | `false` | 自动执行命令，跳过确认（危险操作请慎用） |
| `FUCK_TIMEOUT` | `30` | `curl` 请求超时时间（秒） |
| `FUCK_DEBUG` | `false` | 输出调试日志，便于排查问题 |
| `FUCK_DISABLE_DEFAULT_ALIAS` | `false` | 若设为 `true`，将不会自动注入 `fuck` 别名 |

通过 `fuck config` 可以快速查看文件路径并创建默认示例。

---

## 开发者指南

如果你想自己部署这个项目，或者想对它进行修改，请遵循以下步骤。

### 环境要求

*   [Cloudflare](https://www.cloudflare.com/) 账号
*   Node.js (>= 18.0.0)
*   npm
*   OpenAI API 密钥 (或其他兼容 OpenAI 格式的 API 服务)

### 快速部署

**一键部署（推荐）：**

```bash
git clone https://github.com/faithleysath/fuckit.sh.git
cd fuckit.sh
npm run one-click-deploy
```

**手动部署：**

```bash
git clone https://github.com/faithleysath/fuckit.sh.git
cd fuckit.sh

# 安装依赖
npm install

# 登录 Cloudflare
npx wrangler login

# 设置 OpenAI API Key
npx wrangler secret put OPENAI_API_KEY

# 构建并部署
npm run deploy
```

### 可用的 npm 脚本

- `npm run build` - 构建 Worker（将脚本嵌入 worker.js）
- `npm run deploy` - 构建并部署到 Cloudflare
- `npm run one-click-deploy` - 一键完成所有配置和部署
- `npm run setup` - 交互式设置向导
- `npm run dev` - 本地开发模式

### 自定义配置

在 `wrangler.toml` 中修改 Worker 名称和路由：

```toml
name = "your-worker-name"
```

配置环境变量（可选）：
- `OPENAI_API_MODEL`: AI 模型（默认：`gpt-4-turbo`）
- `OPENAI_API_BASE`: API 基础 URL（默认：`https://api.openai.com/v1`）

详细部署说明请参阅 [DEPLOY.md](./DEPLOY.md)。

---

## 🧠 头脑风暴

* Amber 版本重构：用 Amber 语言实现跨平台 CLI 与 UI。
* 多模型路由：在 OpenAI、Anthropic、DeepSeek、硅基流动等模型之间自动切换。
* 命令历史 & 收藏：支持 `fuck history`、一键回放常用命令。
* 场景模板：内置运维、开发、数据等场景的提示词模板。
* UI 皮肤：猫娘/御姐/严肃模式随心切换，提供更多人设。
* 团队模式：共享自定义 alias、API key、调优模板。

欢迎在 Issue 中继续脑暴更多好玩的点子。

---

## 许可证

本项目采用 MIT 许可证。详情请见 [LICENSE](LICENSE) 文件。

---

## Star History

[![Star History Chart](https://app.repohistory.com/api/svg?repo=faithleysath/fuckit.sh&type=Date&background=FFFFFF&color=f86262)](https://app.repohistory.com/star-history)

## Stargazers over time
[![Stargazers over time](https://starchart.cc/faithleysath/fuckit.sh.svg?background=%23FFFFFF&axis=%23333333&line=%23e76060)](https://starchart.cc/faithleysath/fuckit.sh)
