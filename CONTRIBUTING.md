# Contributing to fuckits

First off, thank you for considering contributing to fuckits! 🎉

This document provides guidelines and instructions for contributing to the project.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Project Structure](#project-structure)

---

## Code of Conduct

This project follows a simple code of conduct:

- **Be respectful**: Treat everyone with respect and kindness
- **Be constructive**: Provide helpful feedback and suggestions
- **Be collaborative**: Work together to improve the project
- **Be patient**: Remember that everyone was a beginner once

---

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report:

1. **Check existing issues**: Your bug might already be reported
2. **Test with latest version**: Ensure you're using the latest release
3. **Enable debug mode**: Run with `FUCK_DEBUG=true` to collect details

When filing a bug report, include:

- **Description**: Clear and concise description of the bug
- **Steps to reproduce**: Detailed steps to reproduce the issue
- **Expected behavior**: What you expected to happen
- **Actual behavior**: What actually happened
- **Environment**:
  - OS and version (e.g., Ubuntu 22.04, macOS 14.0)
  - Shell and version (e.g., bash 5.1, zsh 5.8)
  - fuckits version (check `~/.fuck/main.sh` header)
- **Debug output**: If applicable, attach debug logs
- **Screenshots**: If relevant

### Suggesting Features

Feature requests are welcome! Please:

1. **Search existing issues**: Check if already suggested
2. **Describe the use case**: Explain the problem you're trying to solve
3. **Propose a solution**: How would you implement it?
4. **Consider alternatives**: Are there existing workarounds?

### Improving Documentation

Documentation improvements are always appreciated:

- Fix typos or unclear wording
- Add examples and use cases
- Translate to other languages
- Create tutorials or guides

### Contributing Code

See [Development Workflow](#development-workflow) below.

---

## Development Setup

### Prerequisites

- **Node.js**: v18.0.0 or higher
- **npm**: Latest stable version
- **Bash**: v4.0 or higher (for testing)
- **Git**: Latest stable version
- **Cloudflare Account**: For Worker deployment (optional)

### Initial Setup

```bash
# 1. Fork the repository
# Click "Fork" on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/fuckits.git
cd fuckits

# 3. Add upstream remote
git remote add upstream https://github.com/Silentely/fuckits.git

# 4. Install dependencies
npm install

# 5. Install bats for shell script testing
npm run test:bash --version
# If bats not found, install via package manager:
# macOS: brew install bats-core
# Linux: apt-get install bats or yum install bats
```

### Environment Configuration

```bash
# Create .dev.vars file for local development
cat > .dev.vars << 'EOF'
OPENAI_API_KEY=sk-your-test-key
OPENAI_API_MODEL=gpt-3.5-turbo
SHARED_DAILY_LIMIT=100
EOF

# Never commit .dev.vars (it's in .gitignore)
```

---

## Development Workflow

### 1. Create a Feature Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feat/your-feature-name

# Or for bugfixes
git checkout -b fix/issue-description
```

### 2. Make Your Changes

Follow the [Coding Standards](#coding-standards) below.

### 3. Test Your Changes

```bash
# Run all tests
npm test

# Run specific test suites
npm run test:js          # JavaScript/Worker tests
npm run test:bash        # Bash script tests
npm run test:security    # Security engine tests

# Run with coverage
npm run test:js:coverage

# Test locally with wrangler
npm run dev
# In another terminal:
curl -X POST http://localhost:8787 \
  -H "Content-Type: application/json" \
  -d '{"sysinfo":"OS=Linux","prompt":"test"}'
```

### 4. Commit Your Changes

Follow the [Commit Message Guidelines](#commit-message-guidelines).

```bash
git add .
git commit -m "feat: add awesome new feature"
```

### 5. Push and Create Pull Request

```bash
# Push to your fork
git push origin feat/your-feature-name

# Create PR on GitHub
# Click "Compare & pull request"
```

---

## Coding Standards

### Bash Scripts (main.sh, zh_main.sh, scripts/*)

```bash
# 1. Always use strict mode
set -euo pipefail

# 2. Use readonly for constants
readonly API_ENDPOINT="https://example.com"

# 3. Use local for function variables
function my_function() {
    local arg="$1"
    local result=""
    # ...
}

# 4. Prefix internal functions with underscore
_internal_helper() {
    # ...
}

# 5. Quote all variables
echo "${variable}"
rm -rf "${directory_path}"

# 6. Check command existence before use
if command -v curl &> /dev/null; then
    # Use curl
fi

# 7. Use descriptive variable names
# Bad:  x="value"
# Good: api_response="value"

# 8. Add comments for complex logic
# Calculate time until next UTC midnight
next_midnight=$(date -u -d 'tomorrow 00:00:00' +%s)
```

### JavaScript (worker.js, tests/*.test.js)

```javascript
// 1. Use ES6+ syntax
const response = await fetch(url);
const { data } = await response.json();

// 2. Use async/await over promises
// Bad:
fetch(url).then(r => r.json()).then(data => ...);
// Good:
const response = await fetch(url);
const data = await response.json();

// 3. Use descriptive names
// Bad:  const x = 10;
// Good: const maxRetries = 10;

// 4. Handle errors explicitly
try {
  const result = await riskyOperation();
  return result;
} catch (error) {
  console.error('Operation failed:', error);
  throw error;
}

// 5. Use JSDoc for complex functions
/**
 * Checks quota and updates counter
 * @param {string} ip - Client IP address
 * @param {number} limit - Daily limit
 * @param {object} env - Worker environment
 * @returns {Promise<{allowed: boolean, remaining: number}>}
 */
async function checkQuota(ip, limit, env) {
  // ...
}

// 6. Prefer const over let
const immutableValue = 'value';
let mutableValue = 0;

// 7. Use template literals
const message = `User ${username} has ${count} items`;
```

### Code Organization

```
fuckits/
├── worker.js              # Cloudflare Worker entry point
├── main.sh                # English CLI installer
├── zh_main.sh             # Chinese CLI installer
├── scripts/               # Build and deployment scripts
│   ├── build.sh          # Build Worker with embedded scripts
│   ├── deploy.sh         # Deploy to Cloudflare
│   ├── one-click-deploy.sh
│   ├── setup.sh
│   └── common.sh         # Shared utility functions
├── tests/
│   ├── unit/
│   │   ├── worker/       # Worker unit tests (Vitest)
│   │   └── bash/         # Bash unit tests (bats)
│   └── integration/      # Integration tests
└── docs/                 # Documentation
```

---

## Testing Guidelines

### Writing Tests

#### JavaScript Tests (Vitest)

```javascript
// tests/unit/worker/feature.test.js
import { describe, it, expect, beforeEach } from 'vitest';

describe('Feature Name', () => {
  beforeEach(() => {
    // Setup before each test
  });

  it('should do something specific', () => {
    const result = functionUnderTest();
    expect(result).toBe(expectedValue);
  });

  it('should handle error case', () => {
    expect(() => {
      errorProneFunction();
    }).toThrow('Expected error message');
  });
});
```

#### Bash Tests (bats)

```bash
# tests/unit/bash/feature.bats
#!/usr/bin/env bats

setup() {
  # Runs before each test
  export TEST_HOME=$(mktemp -d)
}

teardown() {
  # Runs after each test
  rm -rf "$TEST_HOME"
}

@test "Feature: should behave correctly" {
  source ./main.sh
  
  run _function_under_test "arg1" "arg2"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"expected"* ]]
}
```

### Test Coverage Requirements

- **New features**: Must include tests
- **Bug fixes**: Add regression test
- **Code changes**: Maintain >80% coverage
- **Critical paths**: Aim for 100% coverage

### Running Tests

```bash
# All tests
npm test

# Watch mode (JavaScript)
npm run test:js:watch

# Specific test file
npx vitest run tests/unit/worker/quota.test.js

# Single bats test
./node_modules/.bin/bats tests/unit/bash/security.bats -f "Block: rm -rf /"
```

---

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, tooling
- `ci`: CI/CD configuration changes

### Examples

```bash
# Feature
git commit -m "feat(security): add whitelist mechanism for trusted commands"

# Bug fix
git commit -m "fix(quota): resolve KV race condition in concurrent requests"

# Documentation
git commit -m "docs(api): add endpoint examples for POST /"

# Refactoring
git commit -m "refactor(worker): extract command sanitization to separate function"

# Multiple lines
git commit -m "feat(cli): add audit logging

- Log all commands to ~/.fuck/.audit.log
- Include timestamp, user, and execution status
- Automatically set file permissions to 600

Closes #123"
```

---

## Pull Request Process

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] All tests pass: `npm test`
- [ ] Added tests for new features
- [ ] Updated documentation if needed
- [ ] Commit messages follow conventions
- [ ] No merge conflicts with `main`

### PR Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How did you test this?

## Checklist
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No linting errors
- [ ] Follows code style guide

## Related Issues
Closes #123
Related to #456
```

### Review Process

1. **Automated Checks**: CI/CD runs tests automatically
2. **Code Review**: Maintainer reviews your code
3. **Feedback**: Address review comments
4. **Approval**: Once approved, PR will be merged
5. **Deployment**: Changes deployed to production

### After Merge

```bash
# Update your local main branch
git checkout main
git pull upstream main

# Delete your feature branch
git branch -d feat/your-feature-name
git push origin --delete feat/your-feature-name
```

---

## Project Structure

### Key Files

```
worker.js
  ├── handleGetRequest()     # Serve installer script
  ├── handlePostRequest()    # Generate commands via AI
  ├── handleHealthCheck()    # Health monitoring
  ├── checkSharedQuota()     # Quota enforcement
  └── sanitizeCommand()      # Security sanitization

main.sh
  ├── _fuck_execute_prompt()           # Main entry point
  ├── _fuck_security_evaluate_command() # Security engine
  ├── _fuck_collect_sysinfo_string()   # System detection
  └── _fuck_safe_source_config()       # Config validation

scripts/build.sh
  └── Embeds main.sh and zh_main.sh into worker.js via base64
```

### Adding New Features

#### Example: Add New Configuration Option

1. **Update config template** in `main.sh`:
```bash
_fuck_ensure_config_exists() {
  # ...
  cat << 'CFG' > "$CONFIG_FILE"
# ... existing config ...

# New option description
# export FUCK_NEW_OPTION="default_value"
CFG
}
```

2. **Use the option** in your function:
```bash
_fuck_use_new_option() {
  local option="${FUCK_NEW_OPTION:-default_value}"
  # Your logic here
}
```

3. **Add tests**:
```bash
# tests/unit/bash/config.bats
@test "Config: FUCK_NEW_OPTION should work" {
  export FUCK_NEW_OPTION="custom"
  run bash -c "source $MAIN_SH; _fuck_use_new_option"
  [ "$status" -eq 0 ]
  [[ "$output" == *"custom"* ]]
}
```

4. **Document** in `docs/API.md` or README

5. **Update** `config.example.sh`

---

## Questions?

- **GitHub Issues**: https://github.com/Silentely/fuckits/issues
- **Discussions**: https://github.com/Silentely/fuckits/discussions
- **Email**: Open an issue for contact information

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to fuckits! 🚀
