# fuckits CLI - AI Agent Usage Guide

> fuckits converts natural language descriptions into executable shell commands using AI.

## Quick Reference

| Aspect | Detail |
|--------|--------|
| **Tool name** | `fuck` (alias: `pls`, configurable) |
| **Input** | Natural language prompt describing a task |
| **Output** | Executable shell command (or JSON with `--json`) |
| **Backend** | Cloudflare Worker → OpenAI API |
| **Platforms** | macOS, Linux (apt/yum/dnf/pacman/zypper/brew) |
| **Shells** | bash, zsh, sh |

## Authentication

Three methods, checked in order:

1. **Local API key** (`FUCK_OPENAI_API_KEY`) — recommended, bypasses shared quota
2. **Admin key** (`FUCK_ADMIN_KEY`) — bypasses shared quota for trusted maintainers
3. **Shared Worker quota** — default fallback, limited to ~10 calls/day

Check current auth status:
```bash
fuck --config
```

## Output Contract

- **stdout**: Command output (data)
- **stderr**: Progress spinners, prompts, color output (human messages)
- **Exit codes**: `0` = success, `1` = general error, `2` = quota exceeded

## Command Catalog

### Core: Generate & Execute Commands

```bash
fuck <prompt>              # Generate and execute a shell command
fuck <prompt> --json       # Output command as structured JSON (does not execute)
# Note: --json can be placed at any position (e.g. fuck --json <prompt>, fuck --history --json)
```

**Flow**: prompt → AI generates command → safety check → user confirmation → execute → log to history

**Auto-exec mode** (skip confirmation):
```bash
FUCK_AUTO_EXEC=true fuck <prompt>
```

### Subcommands

```bash
# Configuration
fuck --config                # Show config file path and available options

# Version
fuck version               # Show installed version (alias: fuck -v, fuck --version)

# History
fuck --history               # Show recent 20 commands
fuck --history <N>           # Show recent N commands
fuck --history search <kw>   # Search history by keyword
fuck --history replay <N>    # Replay the Nth command from history

# Favorites
fuck --favorite add <name> <prompt>   # Save a prompt as a named favorite
fuck --favorite list                  # List all favorites (alias: fuck --favorite ls)
fuck --favorite run <N>               # Execute favorite #N (alias: fuck --favorite exec)
fuck --favorite delete <N>            # Delete favorite #N (alias: fuck --favorite del/rm)

# Uninstall
fuck --uninstall             # Remove fuckits from ~/.fuck/
```

### Configuration Options

Set in `~/.fuck/config.sh`:

| Key | Description | Default |
|-----|-------------|---------|
| `FUCK_OPENAI_API_KEY` | Local OpenAI-compatible API key | (empty = shared quota) |
| `FUCK_ADMIN_KEY` | Admin bypass key | (empty) |
| `FUCK_OPENAI_MODEL` | Model override (local key only) | gpt-5-nano（项目自定义标识符，可通过配置覆盖） |
| `FUCK_OPENAI_API_BASE` | API base URL | https://api.openai.com/v1 |
| `FUCK_ALIAS` | Extra alias name | (empty) |
| `FUCK_AUTO_EXEC` | Skip confirmation prompts | false |
| `FUCK_TIMEOUT` | curl timeout in seconds | 30 |
| `FUCK_SECURITY_MODE` | Security engine: strict/balanced/off | balanced |
| `FUCK_SECURITY_WHITELIST` | Comma-separated command patterns to bypass security | (empty) |
| `FUCK_SECURITY_CHALLENGE_TEXT` | Phrase for high-risk confirmation | I accept the risk |

## Decision Trees

### "Install a package"
1. `fuck "install <package>"`
2. Review the generated command
3. Confirm with Y
4. Verify: `<package> --version`

### "Find files / list things"
1. `fuck "find all files larger than 10MB in the current directory"`
2. Review → Confirm → Execute

### "System maintenance"
1. `fuck "update all system packages"` → review → confirm
2. `fuck "check disk usage"` → review → confirm
3. `fuck "clean up docker unused images"` → review → confirm

### "Check if something is installed"
1. `fuck "check if node is installed"`
2. Or directly: `command -v node && node --version`

## Security Model

fuckits has a 3-tier security engine:

| Level | Behavior | Example patterns |
|-------|----------|-----------------|
| **Block** | Execution denied, no override | `rm -rf /`, `dd of=/dev/`, `mkfs` |
| **Challenge** | Requires phrase confirmation | `curl \| sh`, `eval`, `exec` |
| **Warn** | Warning shown, user decides | `rm -rf` (non-root), `chmod 777` |

**Whitelist** bypasses all checks:
```bash
export FUCK_SECURITY_WHITELIST="docker rm -f,rm -rf /tmp/safe-dir"
```

**Strict mode** escalates warn→challenge, challenge→block:
```bash
export FUCK_SECURITY_MODE=strict
```

## Gotchas

1. **Shared quota is limited** (~10 calls/day). Set `FUCK_OPENAI_API_KEY` for unlimited use.
2. **History requires `jq`**. Install with `brew install jq` (macOS) or `apt install jq` (Linux).
3. **Commands execute via `bash -c`**. The generated command runs in a bash subshell.
4. **Confirmation prompt reads from /dev/tty**. In non-interactive contexts (pipes, scripts), set `FUCK_AUTO_EXEC=true`.
5. **Config file is chmod 600**. Only the owning user can read it.
6. **Security engine is regex-based**. Complex commands may trigger false positives on the challenge tier.
7. **Version injection**: `SCRIPT_VERSION` is injected at build time from `VERSION`. The placeholder `__SCRIPT_VERSION__` is replaced during `npm run build`.

## Examples

```bash
# Simple file operations
fuck "list all files sorted by size"
fuck "find files modified in the last 24 hours"
fuck "compress the docs folder into a tarball"

# Package management
fuck "install node.js using homebrew"
fuck "update all brew packages"

# Git operations
fuck "show git log for the last 5 commits"
fuck "create a new branch called feature/auth"

# Docker
fuck "show running docker containers"
fuck "remove all stopped containers"

# System info
fuck "show current disk usage"
fuck "check which process is using port 3000"
```

## Error Codes (JSON Mode)

All JSON error responses follow: `{"status":"error","code":"<CODE>","message":"<description>"}`

| Code | Meaning | Trigger |
|------|---------|---------|
| `MISSING_DEPENDENCY` | Required tool not installed | curl not found |
| `MISSING_PROMPT` | No prompt provided | `fuck` with no args |
| `MISSING_KEYWORD` | Search keyword missing | `fuck --history search` with no keyword |
| `INVALID_SUBCOMMAND` | Unknown subcommand | `fuck --favorite` with invalid action |
| `HISTORY_PARSE_FAILED` | History file corrupt | jq parse error on history.json |
| `FAVORITES_PARSE_FAILED` | Favorites file corrupt | jq parse error on favorites |

## For Agent Integration

When integrating fuckits into an AI agent workflow:

1. **Parse the command before executing** — fuckits outputs the command to stdout after user confirmation
2. **Check exit code** — `0` means success, `2` means quota exceeded
3. **Use `FUCK_AUTO_EXEC=true`** for non-interactive automation
4. **Set a local API key** to avoid shared quota limits
5. **Use `FUCK_SECURITY_WHITELIST`** to pre-approve known-safe patterns
