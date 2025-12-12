/**
 * Vitest 测试环境设置
 * 用于配置 Miniflare 模拟 Cloudflare Workers 运行时
 *
 * 功能：
 * - 初始化 Miniflare 实例
 * - 模拟 KV 存储（用于配额测试）
 * - 设置测试环境变量
 * - 提供测试工具函数
 * - 使用 MockAgent 模拟 OpenAI API
 */

import { Miniflare } from 'miniflare';
import { beforeAll, afterAll } from 'vitest';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// 全局 Miniflare 实例
let mf;

// Mock Agent 实例
let mockAgent;

/**
 * 测试套件开始前初始化 Miniflare
 */
beforeAll(async () => {
  // 动态导入 Miniflare 内部使用的 undici MockAgent
  const { MockAgent } = await import('miniflare/node_modules/undici/index.js');

  // 读取 mock 响应数据
  const mockResponses = JSON.parse(
    readFileSync('./tests/fixtures/mock-responses.json', 'utf-8')
  );

  // 创建 Mock Agent
  mockAgent = new MockAgent();
  mockAgent.disableNetConnect(); // 禁用真实网络连接

  // 配置 OpenAI API mock
  const mockPool = mockAgent.get('https://api.openai.com');
  mockPool
    .intercept({
      path: '/v1/chat/completions',
      method: 'POST',
    })
    .reply(200, mockResponses.mockSuccessResponse)
    .persist(); // 持久化 mock，允许多次调用

  // 读取 worker.js 内容
  const workerScript = readFileSync('./worker.js', 'utf-8');

  // 初始化 Miniflare
  mf = new Miniflare({
    // Worker 脚本内容
    script: workerScript,

    // 启用 ES 模块格式
    modules: true,

    // 模拟 KV 命名空间
    kvNamespaces: ['QUOTA_KV'],

    // 环境变量
    bindings: {
      OPENAI_API_KEY: 'test-api-key',
      OPENAI_API_MODEL: 'gpt-5-nano',
      OPENAI_API_BASE: 'https://api.openai.com/v1',
      SHARED_DAILY_LIMIT: '3', // 设置为 3 以匹配测试期望
      ADMIN_ACCESS_KEY: 'test-admin-key',
      QUOTA_KV_BINDING: 'QUOTA_KV',
    },

    // 兼容性标志
    compatibilityDate: '2025-10-26',

    // 使用 MockAgent 拦截 fetch 请求
    fetchMock: mockAgent,
  });
});

/**
 * 测试套件结束后清理资源
 */
afterAll(async () => {
  if (mf) {
    await mf.dispose();
  }
  if (mockAgent) {
    await mockAgent.close();
  }
});

/**
 * 获取 Miniflare 实例
 * @returns {Miniflare} Miniflare 实例
 */
export function getMiniflare() {
  return mf;
}

/**
 * 创建测试请求
 * @param {string} method - HTTP 方法
 * @param {string} path - 请求路径
 * @param {object} options - 请求选项
 * @returns {Promise<Response>} 响应对象
 */
export async function makeRequest(method, path, options = {}) {
  const url = `https://fuckits.test${path}`;

  return await mf.dispatchFetch(url, {
    method,
    redirect: 'manual',  // 阻止自动跟随重定向，让测试能够断言 302 响应
    ...options,
  });
}

/**
 * 创建 POST 请求
 * @param {string} path - 请求路径
 * @param {object} body - 请求体
 * @param {object} headers - 请求头
 * @returns {Promise<Response>} 响应对象
 */
export async function post(path, body, headers = {}) {
  return await makeRequest('POST', path, {
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

/**
 * 创建 GET 请求
 * @param {string} path - 请求路径
 * @param {object} headers - 请求头
 * @returns {Promise<Response>} 响应对象
 */
export async function get(path, headers = {}) {
  return await makeRequest('GET', path, { headers });
}

/**
 * 创建 OPTIONS 请求
 * @param {string} path - 请求路径
 * @param {object} headers - 请求头
 * @returns {Promise<Response>} 响应对象
 */
export async function options(path, headers = {}) {
  return await makeRequest('OPTIONS', path, { headers });
}

/**
 * 清空 KV 存储
 */
export async function clearKV() {
  const kv = await mf.getKVNamespace('QUOTA_KV');
  const keys = await kv.list();
  for (const key of keys.keys) {
    await kv.delete(key.name);
  }
}

/**
 * 设置 KV 键值对
 * @param {string} key - 键
 * @param {string} value - 值
 * @param {object} options - 选项（如 expirationTtl）
 */
export async function setKV(key, value, options = {}) {
  const kv = await mf.getKVNamespace('QUOTA_KV');
  await kv.put(key, value, options);
}

/**
 * 获取 KV 值
 * @param {string} key - 键
 * @returns {Promise<string|null>} 值
 */
export async function getKV(key) {
  const kv = await mf.getKVNamespace('QUOTA_KV');
  return await kv.get(key);
}
