#!/bin/bash
#
# Example configuration file for fuckits
# Copy or symlink this file to ~/.fuck/config.sh and customize it.
# Run: chmod 600 ~/.fuck/config.sh to keep your API keys local-only.
#

# Custom API endpoint (default shared demo: https://fuckits.25500552.xyz/)
# export FUCK_API_ENDPOINT="https://your-domain.workers.dev/"

# Local OpenAI API key (recommended; bypasses shared demo limit)
# export FUCK_OPENAI_API_KEY="sk-..."

# Optional: admin bypass key (ask project maintainer)
# export FUCK_ADMIN_KEY="adm-..."

# Optional: local model & base URL
# export FUCK_OPENAI_MODEL="gpt-4o-mini"
# export FUCK_OPENAI_API_BASE="https://api.openai.com/v1"

# Extra alias besides the default 'fuck'
# export FUCK_ALIAS="pls"

# Auto-exec mode (skip confirmations) — use with caution!
# export FUCK_AUTO_EXEC=false

# Override curl timeout (seconds)
# export FUCK_TIMEOUT=30

# Enable verbose debug logs
# export FUCK_DEBUG=false

# Detach after confirmation (run commands in background)
# export FUCK_DETACH_AFTER_CONFIRM=false

# Disable the built-in 'fuck' alias
# export FUCK_DISABLE_DEFAULT_ALIAS=false
