/**
 * Vitest 配置文件
 * 用于 fuckits worker.js 的单元测试和集成测试
 *
 * 关键特性：
 * - 使用 Miniflare 模拟 Cloudflare Workers 运行时
 * - 支持 ES6 模块（项目使用 "type": "module"）
 * - 集成代码覆盖率报告（c8）
 * - 模拟 KV 存储用于配额测试
 */

import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // 测试文件匹配模式
    include: ['tests/unit/**/*.test.js', 'tests/integration/**/*.test.js'],

    // 测试环境：使用 node 环境 + Miniflare 模拟 Workers
    environment: 'node',

    // 全局设置文件
    setupFiles: ['./tests/helpers/test-env.js'],

    // 覆盖率配置
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['worker.js'],
      exclude: [
        'tests/**',
        'scripts/**',
        'main.sh',
        'zh_main.sh',
        '*.config.js',
      ],
      // 覆盖率目标：80% 最低要求
      lines: 80,
      functions: 80,
      branches: 75,
      statements: 80,
    },

    // 测试超时配置
    testTimeout: 10000,
    hookTimeout: 10000,

    // 并发控制
    maxConcurrency: 5,

    // 测试输出配置
    reporters: ['verbose'],

    // Mock 配置
    mockReset: true,
    restoreMocks: true,
  },
});
