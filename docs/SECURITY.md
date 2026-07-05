# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.2.x   | :white_check_mark: |
| 2.1.x   | :white_check_mark: |
| < 2.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in fuckits, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

### How to Report

1. **Email**: Send details to the repository owner via GitHub (use the "Report" button on the repository or contact through profile)
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: within 48 hours
- **Assessment**: within 1 week
- **Fix**: depends on severity
  - Critical/High: within 1 week
  - Medium: within 2 weeks
  - Low: next release cycle

### Scope

The following are in scope for security reports:

- **Worker (worker.js)**: API endpoint vulnerabilities, injection attacks, authentication bypass
- **CLI (main.sh / zh_main.sh)**: Command injection, path traversal, config file tampering
- **Security Engine**: Bypass of block/challenge/warn rules
- **Config Validation**: Injection through config.sh files
- **Dependencies**: Vulnerabilities in npm packages

### Out of Scope

- Social engineering attacks
- Attacks requiring physical access
- Issues in third-party services (OpenAI API, Cloudflare infrastructure)
- The shared demo quota system (by design, it's limited)

## Security Design

fuckits implements multiple security layers:

1. **Server-side sanitization** (worker.js: `sanitizeCommand`)
2. **3-tier local security engine** (main.sh: 8 block + 20 challenge + 4 warn rules)
3. **Config file validation** (prevents code injection via config.sh)
4. **File permission enforcement** (config.sh locked to chmod 600)
5. **User confirmation prompts** (unless `FUCK_AUTO_EXEC=true`)

## Responsible Disclosure

We appreciate responsible disclosure and will credit reporters in the changelog (unless they prefer anonymity).
