<h1 align="center">fuckits</h1>

<p align="center">
  <strong>English</strong> | <a href="./README.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/Silentely/fuckits/stargazers">
    <img src="https://img.shields.io/github/stars/faithleysath/fuckits?style=social" alt="GitHub Stars">
  </a>
  <a href="https://github.com/Silentely/fuckits/network/members">
    <img src="https://img.shields.io/github/forks/faithleysath/fuckits?style=social" alt="GitHub Forks">
  </a>
  <a href="https://github.com/Silentely/fuckits/commits/main">
    <img src="https://img.shields.io/github/last-commit/faithleysath/fuckits" alt="GitHub last commit">
  </a>
  <a href="https://github.com/Silentely/fuckits/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/faithleysath/fuckits" alt="License">
  </a>
</p>

**I fucking forgot that command.**

`fuckits` is an AI-powered command-line tool that translates your natural language descriptions directly into executable shell commands.

When you're too lazy to check the `man` pages or search on Google, just `fuck` it.

**This project is completely free to use. You do not need to provide your own OpenAI API Key.**


## Preview

![Preview](preview.gif)


## Features

*   **Natural Language to Command**: Directly translates your plain English into executable shell commands.
*   **AI-Powered**: Leverages the power of Large Language Models to understand complex instructions.
*   **Interactive Confirmation**: Displays the command and asks for your approval before execution, ensuring safety.
*   **Dual-Mode Operation**: Supports a one-line installer for long-term use and a temporary, no-install mode.
*   **Cross-Platform**: Works on macOS and major Linux distributions.
*   **Bilingual**: Offers a full experience in both English and Chinese.
*   **Smart Context**: Automatically detects OS, package manager, and other info to provide better context to the AI.
*   **Easy Uninstall**: A single command completely removes the script from your system.

## 🔧 What's New

* Per-user config file (`~/.fuck/config.sh`) with custom API endpoints, aliases, auto-exec, timeouts, and debug flags.
* Local-key-first workflow: `fuck config` generates `~/.fuck/config.sh` (auto `chmod 600`); once you set `FUCK_OPENAI_API_KEY`/`FUCK_OPENAI_MODEL`/`FUCK_OPENAI_API_BASE`, the CLI calls OpenAI directly via your own quota. The shared Worker only exposes a 10 calls/day demo bucket and now tells you to switch once you hit the cap.
* `fuck config` helper that tells you where the config lives and auto-generates a starter file.
* Auto-exec mode controlled via `FUCK_AUTO_EXEC=true` for non-interactive workflows.
* Custom aliases via `FUCK_ALIAS="pls"` while keeping the OG `fuck` command.
* Rebuilt build/deploy workflow: `npm run build` now injects the latest installers into `worker.js`.
* One-click deploy workflow via `npm run one-click-deploy`.

---

## Quick Install

Pick your preferred language and run the command below in your terminal.

```bash
curl -sS https://fuckits.25500552.xyz | bash
```

> [!NOTE]
> `fuckits.25500552.xyz` is the Works (Cloudflare Workers) custom domain bound to this Worker. After deploying with the guides in this repo, point that domain to your Worker and use `/zh` if you want the Chinese installer.

> [!WARNING]
> **Security Notice (As if you care)**
> 
> If you don't trust piping scripts directly into `bash`, you can do it step-by-step:
> 1.  **Download**: `curl -o fuckits https://fuckits.25500552.xyz`
> 2.  **Inspect**: `less fuckits`
> 3.  **Run**: `bash fuckits`
> Hosting your own instance? Point `FUCK_API_ENDPOINT` in `~/.fuck/config.sh` to your custom domain so the CLI doesn't keep calling the demo server.
>
> [!TIP]
> The shared Worker is just a tasting menu (10 calls/day). Right after installation run `fuck config`, set `FUCK_OPENAI_API_KEY`/`FUCK_OPENAI_MODEL`/`FUCK_OPENAI_API_BASE` in `~/.fuck/config.sh`, and every request will hit your own key instead of the shared quota. The installer locks that file to `chmod 600`, so the key never leaves your box.

After installation, restart your shell or run `source ~/.bashrc` / `source ~/.zshrc` for the command to take effect.

---

## How to Use

It's dead simple. The format is:

```bash
fuck <your prompt>
```

The AI will return the command it thinks is correct. You confirm, and it runs.

**Examples:**

```bash
# Find all files larger than 10MB in the current directory
fuck find all files larger than 10MB in the current directory

# Install git (auto-detects apt/yum/brew, etc.)
fuck install git

# Uninstall git (also auto-detects)
fuck uninstall git
```

### Configure

See where the config file lives and generate a starter template:

```bash
fuck config
```

The config file lives at `~/.fuck/config.sh`. You can tweak:
- Custom API endpoints for self-hosted workers
- Local OpenAI-compatible credentials via `FUCK_OPENAI_API_KEY` (plus optional `FUCK_OPENAI_MODEL`/`FUCK_OPENAI_API_BASE`)
- Auto-exec mode to skip confirmations
- Request timeouts and debug output
- Extra aliases (while keeping the default `fuck` command)

### Uninstall

If you want to get rid of me, you can kick me out anytime:

```bash
fuck uninstall
```

---

### Temporary Use (No Installation)

If you don't want to install the script and just need a one-off command, you can run it directly with `curl`.

```bash
curl -sS https://fuckits.25500552.xyz | bash -s "your prompt"
```

**Example:**
```bash
# Find all files larger than 10MB
curl -sS https://fuckits.25500552.xyz | bash -s "find all files larger than 10MB"
```

This method won't install any files on your system; the command is executed directly.

---

## How It Works

1.  You type `fuck <your prompt>` in your terminal.
2.  The script sends your prompt and some basic system info (like OS, package manager) to a Cloudflare Worker.
3.  The Cloudflare Worker calls the OpenAI API (or another LLM) with your prompt.
4.  The AI returns the generated shell command.
5.  The script displays the command in your terminal and waits for your confirmation.
6.  You type `y`, the command executes. World peace is achieved.

---

## ☁️ One-Click Deploy

One command handles dependencies, Cloudflare login, secrets, build, and deploy:

```bash
npm run one-click-deploy
```

The script walks you through Cloudflare auth, prompts for your OpenAI key, and embeds the freshest `main.sh`/`zh_main.sh` into `worker.js`. Need more details? Check [DEPLOY.md](./DEPLOY.md#english).

After deployment, map `fuckits.25500552.xyz` to this Worker via the Works (Cloudflare Workers) custom domain UI; append `/zh` to expose the Chinese installer endpoint. DNS/SSL might take a few minutes to propagate, so run:

```bash
curl -sS https://fuckits.25500552.xyz/health | jq
```

You should see `status: "ok"` and `hasApiKey: true`. If not, double-check the domain binding and OpenAI secrets.

> [!TIP]
> Forking the repo? Swap the domain and regenerate `FUCK_API_ENDPOINT` in your config before sharing binaries.

> [!NOTE]
> Cloudflare Custom Domains do not allow wildcard or path suffixes (e.g., `fuckits.25500552.xyz/*` or `/zh`). Bind the bare domain only—the Worker itself routes `/zh` requests internally.

### Post-deploy checklist

1. Bind your custom domain + `/zh` path in the Cloudflare dashboard.
2. Hit `https://<your-domain>/health` to ensure the Worker is alive and has secrets.
3. Pipe both English and Chinese installers via `curl ... | bash -s "echo ok"` to test real usage.
4. Update your local `~/.fuck/config.sh` so the CLI talks to your own Worker.

---

## ⚙️ Configuration

`~/.fuck/config.sh` is your control center. Both installed and temporary modes respect it.

| Variable | Default | Description |
| --- | --- | --- |
| `FUCK_API_ENDPOINT` | `https://fuckits.25500552.xyz/` | Point to your self-hosted worker |
| `FUCK_OPENAI_API_KEY` | empty | Local OpenAI-compatible key (recommended, bypasses the shared quota) |
| `FUCK_OPENAI_MODEL` | `gpt-4-turbo` | Override the model when you use your own key |
| `FUCK_OPENAI_API_BASE` | `https://api.openai.com/v1` | Custom API base for proxies/alt providers |
| `FUCK_ALIAS` | `fuck` | Extra alias (without removing the default) |
| `FUCK_AUTO_EXEC` | `false` | Skip confirmations (dangerous but handy for automation) |
| `FUCK_TIMEOUT` | `30` | `curl` timeout in seconds |
| `FUCK_DEBUG` | `false` | Verbose debug logs |
| `FUCK_DISABLE_DEFAULT_ALIAS` | `false` | Don’t automatically inject the `fuck` alias |

Run `fuck config` to print the file path and auto-generate a starter template. The installer pins `~/.fuck/config.sh` to `chmod 600` so your API keys never leave your machine.

---

## Developer Guide (For tinkerers)

If you want to deploy this project yourself or modify it, follow these steps.

### Prerequisites

*   A [Cloudflare](https://www.cloudflare.com/) account
*   Node.js (>= 18.0.0)
*   npm
*   An OpenAI API key (or another OpenAI-compatible API service)

### Quick Deploy

**One-click (recommended):**

```bash
git clone https://github.com/Silentely/fuckits.git
cd fuckits
npm run one-click-deploy
```

**Manual:**

```bash
git clone https://github.com/Silentely/fuckits.git
cd fuckits

# Install dependencies
npm install

# Login to Cloudflare
npx wrangler login

# Set OpenAI API Key
npx wrangler secret put OPENAI_API_KEY

# Build and deploy
npm run deploy
```

### Available npm Scripts

- `npm run build` - Build the worker (embed scripts into worker.js)
- `npm run deploy` - Build and deploy to Cloudflare
- `npm run one-click-deploy` - Complete all setup and deployment automatically
- `npm run setup` - Interactive setup wizard
- `npm run dev` - Local development mode

### Custom Configuration

Edit worker name and routes in `wrangler.toml`:

```toml
name = "your-worker-name"
```

**Optional environment variables:**
- `OPENAI_API_MODEL`: AI model (default: `gpt-4-turbo`)
- `OPENAI_API_BASE`: API base URL (default: `https://api.openai.com/v1`)

For detailed deployment instructions, see [DEPLOY.md](./DEPLOY.md).

---

## 🧠 Brainstorming

* Amber-lang rewrite: Cross-platform CLI + UI powered by Amber.
* Multi-model routing: Seamlessly switch between OpenAI, Anthropic, DeepSeek, and other providers.
* Command history & favorites: `fuck history`, one-click replay of common commands.
* Scenario templates: Built-in prompt templates for ops, dev, data, etc.
* UI skins: Cat-girl, professional, serious modes and more personalities.
* Team mode: Share custom aliases, API keys, and tuned templates.

Drop your ideas in the Issues—let's brainstorm more fun features together.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Star History

[![Star History Chart](https://app.repohistory.com/api/svg?repo=faithleysath/fuckits&type=Date&background=FFFFFF&color=f86262)](https://app.repohistory.com/star-history)

## Stargazers over time
[![Stargazers over time](https://starchart.cc/faithleysath/fuckits.svg?background=%23FFFFFF&axis=%23333333&line=%23e76060)](https://starchart.cc/faithleysath/fuckits)
