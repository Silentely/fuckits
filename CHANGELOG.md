# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2024-12-05

### 🎉 Major Refactor

#### Added
- **Configuration System**: Per-user config file at `~/.fuck/config.sh`
  - Custom API endpoints (`FUCK_API_ENDPOINT`)
  - Auto-exec mode (`FUCK_AUTO_EXEC`)
  - Request timeout (`FUCK_TIMEOUT`)
  - Debug mode (`FUCK_DEBUG`)
  - Custom aliases (`FUCK_ALIAS`)
  - Disable default alias (`FUCK_DISABLE_DEFAULT_ALIAS`)

- **New Commands**:
  - `fuck config` - Display config file location and help

- **Build System**:
  - Automated build script (`scripts/build.sh`)
  - One-click deploy script (`scripts/one-click-deploy.sh`)
  - Simplified deploy script (`scripts/deploy.sh`)
  - Interactive setup wizard (`scripts/setup.sh`)

- **npm Integration**:
  - `package.json` with proper scripts
  - `npm run build` - Build worker
  - `npm run deploy` - Deploy to Cloudflare
  - `npm run one-click-deploy` - Complete automated deployment
  - `npm run setup` - Interactive setup
  - `npm run dev` - Local development

- **Documentation**:
  - Comprehensive deployment guide (`DEPLOY.md`)
  - Configuration examples (`config.example.sh`)
  - Updated README with new features
  - Changelog file

- **Developer Experience**:
  - `.gitignore` file
  - Better error handling with TTY checks
  - Debug logging system
  - Cross-platform build support (macOS & Linux)

#### Changed
- Refactored core logic for better maintainability
- Improved API endpoint handling with fallbacks
- Enhanced curl with timeout support
- Better confirmation flow with auto-exec support

#### Fixed
- TTY handling for non-interactive environments
- Cross-platform compatibility issues
- Configuration file creation during installation

### 🔧 Technical Details

**Breaking Changes**: None - fully backward compatible

**Migration**: Existing installations will work as-is. Run `fuck config` to create a config file.

## [1.0.0] - Previous Release

Initial release with basic functionality:
- Natural language to shell command conversion
- Interactive confirmation
- Dual-mode operation (install & temporary)
- Cross-platform support
- Bilingual (English & Chinese)
