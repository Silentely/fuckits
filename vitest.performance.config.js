/**
 * Vitest 性能测试配置
 * 专门用于 tests/performance/ 目录下的性能基准测试
 */

import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/performance/**/*.test.js'],
    environment: 'node',
    reporters: ['verbose'],
    testTimeout: 30000,
    hookTimeout: 30000,
    maxConcurrency: 1,
    mockReset: true,
    restoreMocks: true,
  },
});
