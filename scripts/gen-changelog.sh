#!/bin/bash
#
# 从 git log 自动生成 docs/CHANGELOG.md
# 策略：通过 VERSION 文件变更历史确定版本边界
# 每次 VERSION 文件变更 = 一个新版本，其 commit 到下一个版本边界的提交归入该版本
#

set -euo pipefail

readonly CHANGELOG_PATH="docs/CHANGELOG.md"
readonly C_CYAN='\033[0;36m'
readonly C_GREEN='\033[0;32m'
readonly C_RESET='\033[0m'

if [[ ! -f "VERSION" ]]; then
    echo "Error: Must run from project root" >&2
    exit 1
fi

mkdir -p docs

echo -e "${C_CYAN}📝 Generating changelog from git log...${C_RESET}"

node <<'NODESCRIPT'
const { execSync } = require('child_process');

function run(cmd) {
    return execSync(cmd, { encoding: 'utf-8' }).trim();
}

// 获取完整 git log（hash|shortHash|subject）
const log = run('git log --format="%H|%h|%s" --no-decorate');
const allCommits = log.split('\n').filter(Boolean).map(line => {
    const [fullHash, shortHash, ...rest] = line.split('|');
    return { fullHash, hash: shortHash, subject: rest.join('|') };
});

// 找出所有修改过 VERSION 文件的 commit，读取当时的版本号
const vFileLog = run('git log --format="%H" -- VERSION');
const versionCommits = vFileLog.split('\n').filter(Boolean);

const versionBoundaries = []; // { hash, version, indexInAll }
for (const fullHash of versionCommits) {
    try {
        // 读取该 commit 时的 VERSION 内容
        const ver = run('git show ' + fullHash + ':VERSION').trim();
        if (/^\d+\.\d+\.\d+$/.test(ver)) {
            const shortHash = fullHash.slice(0, 7);
            const idx = allCommits.findIndex(c => c.fullHash === fullHash);
            if (idx >= 0) {
                versionBoundaries.push({ hash: shortHash, version: 'v' + ver, index: idx });
            }
        }
    } catch {}
}

// 按在 log 中的位置排序（从新到旧）
versionBoundaries.sort((a, b) => a.index - b.index);

// 按版本边界分组 commits
const versions = [];
for (let i = 0; i < versionBoundaries.length; i++) {
    const boundary = versionBoundaries[i];
    const endIdx = i + 1 < versionBoundaries.length
        ? versionBoundaries[i + 1].index
        : allCommits.length;
    const commits = allCommits.slice(boundary.index, endIdx);
    if (commits.length > 0) {
        versions.push({ version: boundary.version, commits });
    }
}

// 生成 Markdown
let md = '# Changelog\n\n';
md += 'All notable changes to fuckits will be documented in this file.\n\n';
md += 'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),\n';
md += 'and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n';

for (const { version, commits } of versions) {
    md += '\n## ' + version + '\n';
    for (const c of commits) {
        md += '- ' + c.subject + '\n';
    }
}

require('fs').writeFileSync('docs/CHANGELOG.md', md, 'utf-8');
console.log('  Changelog: generated ' + versions.length + ' version entries');
NODESCRIPT

echo -e "${C_GREEN}✅ Changelog generated: ${CHANGELOG_PATH}${C_RESET}"
