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

// 全局 Miniflare 实例
let mf;

// Mock Agent 实例
let mockAgent;

/**
 * 测试套件开始前初始化 Miniflare
 */
beforeAll(async () => {
  // 注意：必须从 Miniflare 内部导入 MockAgent
  // Miniflare 会验证 MockAgent 实例类型，直接从 undici 导入会失败
  // 这是 Miniflare 的设计限制，不是最佳实践但是必需的
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

  // 初始化 Miniflare
  mf = new Miniflare({
    // Worker 脚本路径（支持 ES 模块 import/export）
    scriptPath: './worker.js',

    // 启用 ES 模块格式
    modules: true,

    // 模块规则：告诉 Miniflare 所有 .js 文件都是 ES 模块
    modulesRules: [
      { type: 'ESModule', include: ['**/*.js'], fallthrough: true }
    ],

    // 模拟 KV 命名空间
    kvNamespaces: ['QUOTA_KV'],

    // 模拟 R2 buckets
    r2Buckets: ['SCRIPTS_BUCKET'],

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

  // 初始化 R2 mock 数据
  await initR2MockData();
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
 * 初始化 R2 mock 数据
 * 读取 main.sh 和 zh_main.sh 并存入 R2 bucket
 */
async function initR2MockData() {
  try {
    const r2 = await mf.getR2Bucket('SCRIPTS_BUCKET');

    // 读取英文脚本
    const mainScript = readFileSync('./main.sh', 'utf-8');
    await r2.put('en/main.sh', mainScript, {
      httpMetadata: {
        contentType: 'text/plain; charset=utf-8',
      },
    });

    // 读取中文脚本
    const zhScript = readFileSync('./zh_main.sh', 'utf-8');
    await r2.put('zh/main.sh', zhScript, {
      httpMetadata: {
        contentType: 'text/plain; charset=utf-8',
      },
    });

    console.log('✅ R2 mock data initialized');
  } catch (error) {
    console.error('❌ Failed to initialize R2 mock data:', error);
    throw error;
  }
}

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
 * 创建 POST 请求（自动处理 JSON）
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
 * 创建原始 POST 请求（不自动处理 JSON，用于边界测试）
 * @param {string} path - 请求路径
 * @param {string|object} body - 原始请求体
 * @param {object} headers - 请求头（不会自动添加 Content-Type）
 * @returns {Promise<Response>} 响应对象
 */
export async function postRaw(path, body, headers = {}) {
  return await makeRequest('POST', path, {
    headers,
    body: typeof body === 'string' ? body : JSON.stringify(body),
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

/**
 * 获取 R2 bucket 实例
 * @returns {Promise<R2Bucket>} R2 bucket 实例
 */
export async function getR2Bucket() {
  return await mf.getR2Bucket('SCRIPTS_BUCKET');
}

/**
 * 清空 R2 bucket
 */
export async function clearR2() {
  const r2 = await getR2Bucket();
  const objects = await r2.list();
  for (const obj of objects.objects) {
    await r2.delete(obj.key);
  }
}

/**
 * 向 R2 添加对象
 * @param {string} key - 对象键
 * @param {string} content - 对象内容
 * @param {object} options - 选项
 */
export async function putR2(key, content, options = {}) {
  const r2 = await getR2Bucket();
  await r2.put(key, content, options);
}

/**
 * 从 R2 删除对象
 * @param {string} key - 对象键
 */
export async function deleteR2(key) {
  const r2 = await getR2Bucket();
  await r2.delete(key);
}
