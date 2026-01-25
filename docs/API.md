# fuckits Worker API Documentation

## Base URL

```
https://fuckits.25500552.xyz
```

## Endpoints

### GET /

Returns the installer script based on locale detection.

**Headers:**
- `User-Agent`: Used to detect browser requests
- `Accept-Language`: Used for locale detection (optional)

**Query Parameters:**
- `lang`: Explicitly set language (`en` or `zh`)

**Response:**

- **Browser Request**: Redirects to GitHub README
  - English: `https://github.com/Silentely/fuckits/blob/main/README.en.md`
  - Chinese: `https://github.com/Silentely/fuckits`

- **CLI Request**: Returns installer script
  - Content-Type: `text/plain; charset=utf-8`
  - Content-Disposition: `attachment; filename="fuckits.sh"` (or `fuckits-zh.sh`)

**Examples:**

```bash
# Download English installer
curl -sS https://fuckits.25500552.xyz > fuckits.sh

# Download Chinese installer
curl -sS https://fuckits.25500552.xyz/zh > fuckits-zh.sh

# Explicit language parameter
curl -sS https://fuckits.25500552.xyz?lang=zh > fuckits.sh
```

---

### POST /

Generate shell command from natural language prompt.

**Request Body:**

```json
{
  "sysinfo": "OS=Debian; PkgMgr=apt",
  "prompt": "install git",
  "adminKey": "optional-admin-key"
}
```

**Fields:**
- `sysinfo` (required): System information string (OS type, package manager)
- `prompt` (required): Natural language command description
- `adminKey` (optional): Admin bypass key for quota limits

**Response:**

**Success (200 OK):**
```
sudo apt update && sudo apt install -y git
```
Returns plain text command directly.

**Errors:**

**400 Bad Request:**
```json
{
  "error": "Missing or empty \"sysinfo\" in request body"
}
```
or
```json
{
  "error": "Missing or empty \"prompt\" in request body"
}
```

**429 Too Many Requests:**
```json
{
  "error": "DEMO_LIMIT_EXCEEDED",
  "message": "Shared demo quota exceeded (max 10 calls per day).",
  "hint": "Configure FUCK_OPENAI_API_KEY in ~/.fuck/config.sh to use your own key.",
  "remaining": 0,
  "limit": 10
}
```

**500 Internal Server Error:**
```
Missing OPENAI_API_KEY secret
```
or
```
AI API Error: {error details}
```
or
```
The AI returned an empty command.
```

**Examples:**

```bash
# Basic usage
curl -X POST https://fuckits.25500552.xyz \
  -H "Content-Type: application/json" \
  -d '{
    "sysinfo": "OS=Debian; PkgMgr=apt",
    "prompt": "list all files larger than 10MB"
  }'

# With admin key
curl -X POST https://fuckits.25500552.xyz \
  -H "Content-Type: application/json" \
  -d '{
    "sysinfo": "OS=macOS; PkgMgr=brew",
    "prompt": "uninstall docker",
    "adminKey": "your-admin-key"
  }'
```

---

### GET /health

Health check endpoint for monitoring and deployment verification.

**Response (200 OK):**

```json
{
  "status": "ok",
  "version": "2.1.0",
  "timestamp": "2025-01-25T12:00:00.000Z",
  "hasApiKey": true
}
```

**Fields:**
- `status`: Always "ok" if worker is running
- `version`: Current worker version
- `timestamp`: Current server time (ISO 8601)
- `hasApiKey`: Whether OPENAI_API_KEY is configured

**Example:**

```bash
curl https://fuckits.25500552.xyz/health
```

---

### OPTIONS /

CORS preflight request handler.

**Response (204 No Content):**

Headers:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type`

---

## Rate Limiting

### Shared Demo Mode

Default behavior when `FUCK_OPENAI_API_KEY` is not configured:
- Limit: 10 requests per day per IP
- Resets: Daily at UTC midnight
- Storage: Cloudflare KV (persistent) or in-memory (fallback)

### Local API Key Mode

When `FUCK_OPENAI_API_KEY` is configured in `~/.fuck/config.sh`:
- No rate limits applied
- Requests use user's own OpenAI account

### Admin Bypass Mode

When `FUCK_ADMIN_KEY` matches `ADMIN_ACCESS_KEY` on server:
- Bypasses all rate limits
- For trusted maintainers only

---

## Error Codes Summary

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad Request | Check request body contains valid `sysinfo` and `prompt` |
| 429 | Quota Exceeded | Configure local API key or wait for daily reset |
| 500 | Server Error | Check Worker configuration or OpenAI API status |
| 502 | Bad Gateway | OpenAI API is down or unreachable |

---

## Security Features

### Request Validation
- Validates `sysinfo` and `prompt` are non-empty strings
- Sanitizes AI-generated commands (removes markdown, shebang, comments)
- CORS enabled for all origins

### Command Sanitization
AI responses are cleaned to extract executable commands:
1. Extracts from fenced code blocks (```bash ... ```)
2. Removes shebang lines (#!/bin/bash)
3. Removes comment lines
4. Trims whitespace

### Quota Enforcement
Race condition notice: The KV-based quota system uses non-atomic get→check→put pattern. Under high concurrency, slight overages (1-3 requests/day) may occur. This is acceptable for demo quota purposes.

For strict quota requirements, migrate to Cloudflare Durable Objects.

---

## Environment Variables

### Required
- `OPENAI_API_KEY` (secret): OpenAI API key

### Optional
- `OPENAI_API_MODEL`: AI model name (default: "gpt-5-nano")
- `OPENAI_API_BASE`: API base URL (default: "https://api.openai.com/v1")
- `SHARED_DAILY_LIMIT`: Daily quota limit (default: 10)
- `ADMIN_ACCESS_KEY` (secret): Admin bypass key
- `QUOTA_KV`: KV namespace binding for persistent quota storage
- `QUOTA_KV_BINDING`: Alternative KV binding name

---

## Examples

### Complete CLI Workflow

```bash
# 1. Install fuckits
curl -sS https://fuckits.25500552.xyz | bash

# 2. Configure local API key
vim ~/.fuck/config.sh
# Add: export FUCK_OPENAI_API_KEY="sk-..."

# 3. Use the tool
fuck install docker
fuck find files modified today
fuck compress all logs older than 7 days
```

### Direct API Usage (Python)

```python
import requests

def generate_command(prompt, sysinfo="OS=Linux; PkgMgr=apt"):
    response = requests.post(
        "https://fuckits.25500552.xyz",
        json={"sysinfo": sysinfo, "prompt": prompt}
    )
    
    if response.status_code == 200:
        return response.text
    elif response.status_code == 429:
        print("Quota exceeded. Configure local API key.")
    else:
        print(f"Error: {response.text}")
    
    return None

# Example usage
command = generate_command("list all docker containers")
print(command)  # Output: docker ps -a
```

---

## Changelog

### v2.1.0 (2025-01-25)
- Added version field to `/health` endpoint
- Enhanced error messages with structured JSON
- Improved quota system with KV persistence
- Added admin bypass mechanism

### v2.0.0 (2024-12-01)
- Initial public release
- Support for English and Chinese locales
- Shared demo quota system
- Security command sanitization
