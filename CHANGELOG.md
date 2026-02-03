# Changelog

All notable changes to fuckits will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2025-01-25

### Added

#### Documentation
- **API Documentation** (`docs/API.md`): Comprehensive API reference with examples
- **Troubleshooting Guide** (`docs/TROUBLESHOOTING.md`): Common issues and solutions
- **Monitoring Guide** (`docs/MONITORING.md`): Observability and incident response
- **Contributing Guide** (`CONTRIBUTING.md`): Development workflow and coding standards

#### Features
- **Command History & Favorites** (Task 1.4):
  - New `fuck history` command to view recent command history (default: last 20 entries)
  - `fuck history search <keyword>` to search through command history
  - `fuck favorite add <name> <prompt>` to save frequently used commands
  - `fuck favorite list` to view all saved favorites
  - `fuck favorite run <index>` to execute a favorite command
  - `fuck favorite delete <index>` to remove a favorite
  - Short alias `fuck fav` for all favorite operations
  - History stored in `~/.fuck/history.json` with 1000 entry limit
  - Automatic timestamp, exit code, and duration tracking
  - Requires `jq` tool for JSON processing

- **Audit Logging**: New `FUCK_AUDIT_LOG` configuration option to log all command executions
  - Logs include timestamp, user, event type, exit code, and command
  - Log file secured with 600 permissions
  - Configurable log file path via `FUCK_AUDIT_LOG_FILE`
  - Events tracked: EXEC (execution), BLOCK (security block), ABORT (user cancel)

- **Security Enhancements**:
  - Added `FUCK_SECURITY_MODE` configuration (strict/balanced/off)
  - Added `FUCK_SECURITY_WHITELIST` for trusted command patterns
  - Integrated audit logging for blocked commands

#### Testing
- **Command History Tests** (`tests/unit/bash/history.bats`):
  - 18 comprehensive test cases for history and favorites functionality
  - History file initialization and structure validation
  - jq dependency checking and error handling
  - History logging with 1000 entry limit
  - History viewing and searching
  - Favorite command management (add/list/run/delete)
  - Command routing integration tests
  - All tests passing with 100% coverage

- **Performance Tests** (`tests/performance/quota-benchmark.test.js`):
  - Benchmark quota system performance
  - Test in-memory vs KV-based quota handling
  - Concurrent request testing
  - Race condition demonstration

- **Security Fuzzing Tests** (`tests/security/fuzzing.bats`):
  - 100+ fuzzing test cases for security engine
  - Unicode character handling
  - Special character injection prevention
  - Long command buffer overflow prevention
  - Nested quote and glob pattern testing

- **End-to-End Deployment Tests** (`tests/e2e/real-deployment.test.sh`):
  - Live deployment health checks
  - CORS verification
  - Locale switching validation
  - Performance benchmarking

#### DevOps
- **Automated Rollback** (`.github/workflows/rollback.yml`):
  - GitHub Actions workflow for emergency rollbacks
  - Automatic health check after rollback
  - Incident issue creation
  - Failure notifications

- **Environment Isolation** (`wrangler.toml`):
  - Staging environment configuration
  - Production environment configuration
  - Environment-specific variable overrides

#### Scripts
- New npm scripts:
  - `npm run deploy:production` - Deploy to production environment
  - `npm run deploy:staging` - Deploy to staging environment
  - `npm run test:fuzzing` - Run security fuzzing tests
  - `npm run test:performance` - Run performance benchmarks
  - `npm run test:e2e` - Run end-to-end deployment tests
  - `npm run audit` - Run security audit
  - `npm run audit:fix` - Auto-fix security vulnerabilities
  - `npm run security:scan` - Comprehensive security scan

### Changed

- **Version**: Bumped to 2.1.0
- **Configuration Template**: Updated with new security and audit options in both `main.sh` and `zh_main.sh`
- **Config Display**: Added new options to `fuck config` output

### Fixed

- N/A (No bug fixes in this release, pure feature addition)

### Security

- Enhanced configuration validation to prevent code injection
- Audit logging provides forensic trail for security incidents
- Improved error handling in security engine

## [2.0.0] - 2024-12-01

### Added

- Initial public release
- AI-powered natural language to shell command conversion
- Dual language support (English and Chinese)
- Security engine with 21 detection rules
- Shared demo quota system
- KV-based persistent quota storage
- Admin bypass mechanism
- System information caching
- Configuration management
- Comprehensive test suite (145 tests)

### Features

- One-line installation via curl
- Temporary mode (no installation required)
- Interactive command confirmation
- Dangerous command detection and blocking
- Custom API endpoint support
- Local OpenAI API key integration
- Cloudflare Workers deployment
- GitHub Actions CI/CD

---

## Release Notes

### v2.1.0 Highlights

This release focuses on **production readiness** and **operational excellence**:

1. **📚 Documentation**: Complete API docs, troubleshooting guide, and monitoring playbook
2. **🔍 Audit Logging**: Track all command executions for security and compliance
3. **🛡️ Security**: Enhanced fuzzing tests and whitelist mechanism
4. **🚀 DevOps**: Automated rollback, environment isolation, and comprehensive monitoring
5. **🧪 Testing**: 182 tests covering functionality, security, performance, and deployment (101 JS + 81 Bash)

### Upgrade Guide (v2.0.0 → v2.1.0)

**For Users:**
```bash
# Simply reinstall (your config will be preserved)
curl -sS https://fuckits.25500552.xyz | bash

# Or manually update main.sh
cd ~/.fuck
curl -sS https://fuckits.25500552.xyz > main.sh
chmod +x main.sh
```

**New Configuration Options:**
```bash
# Edit ~/.fuck/config.sh and add:

# Enable audit logging
export FUCK_AUDIT_LOG=true

# Customize security mode
export FUCK_SECURITY_MODE="balanced"

# Whitelist trusted commands
export FUCK_SECURITY_WHITELIST="docker rm -f"
```

**For Developers:**
```bash
# Update dependencies
npm install

# Rebuild worker with new features
npm run build

# Run all tests including new ones
npm test
npm run test:performance
npm run test:fuzzing
npm run test:e2e https://your-worker.workers.dev
```

### Breaking Changes

None. This is a backward-compatible feature release.

### Deprecations

None.

---

## Links

- [Repository](https://github.com/Silentely/fuckits)
- [API Documentation](./docs/API.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)
- [Contributing](./CONTRIBUTING.md)
- [Issues](https://github.com/Silentely/fuckits/issues)
