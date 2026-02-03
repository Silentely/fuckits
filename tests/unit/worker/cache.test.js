/**
 * AI 响应缓存系统测试
 * 测试缓存命中、未命中、统计和性能
 */
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { Miniflare } from 'miniflare';

let mf;
let mockAgent;

/**
 * 创建测试用的 Miniflare 实例
 */
beforeAll(async () => {
  // 从 Miniflare 内部导入 MockAgent
  const { MockAgent } = await import('miniflare/node_modules/undici/index.js');

  mockAgent = new MockAgent();
  mockAgent.disableNetConnect();

  mf = new Miniflare({
    scriptPath: './worker.js',
    modules: true,
    modulesRules: [
      { type: 'ESModule', include: ['**/*.js'], fallthrough: true }
    ],
    kvNamespaces: ['QUOTA_KV', 'AI_CACHE'],
    bindings: {
      OPENAI_API_KEY: 'test-api-key',
      OPENAI_API_MODEL: 'gpt-5-nano',
      OPENAI_API_BASE: 'https://api.openai.com/v1',
      SHARED_DAILY_LIMIT: '100',
      ADMIN_ACCESS_KEY: 'test-admin-key',
      QUOTA_KV_BINDING: 'QUOTA_KV',
    },
    compatibilityDate: '2025-10-26',
    fetchMock: mockAgent,
  });
});

afterAll(async () => {
  if (mf) {
    await mf.dispose();
  }
});

beforeEach(async () => {
  // 清空缓存内容,但保留统计数据
  const cache = await mf.getKVNamespace('AI_CACHE');
  const keys = await cache.list();
  for (const key of keys.keys) {
    // 只删除 ai: 开头的缓存数据,保留 stats: 统计数据
    if (key.name.startsWith('ai:')) {
      await cache.delete(key.name);
    }
  }
});

/**
 * 辅助函数:发送 POST 请求
 */
async function post(path, body, headers = {}) {
  const url = `https://fuckits.test${path}`;
  return await mf.dispatchFetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
    redirect: 'manual',
  });
}

/**
 * 辅助函数:发送 GET 请求
 */
async function get(path, headers = {}) {
  const url = `https://fuckits.test${path}`;
  return await mf.dispatchFetch(url, {
    method: 'GET',
    headers,
    redirect: 'manual',
  });
}

describe('AI 响应缓存系统', () => {
  describe('缓存命中与未命中', () => {
    it('第一次请求应该缓存未命中并调用 AI API', async () => {
      // Mock OpenAI API 响应
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'ls -la',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'list files',
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('X-Cache-Status')).toBe('MISS');
      const body = await response.text();
      expect(body).toBe('ls -la');
    });

    it('第二次相同请求应该缓存命中并快速返回', async () => {
      // 第一次请求 - Mock API
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'find . -type f -size +10M',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response1 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'find large files',
      });

      expect(response1.status).toBe(200);
      expect(response1.headers.get('X-Cache-Status')).toBe('MISS');

      // 第二次相同请求 - 应该从缓存返回,不调用 API
      const response2 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'find large files',
      });

      expect(response2.status).toBe(200);
      expect(response2.headers.get('X-Cache-Status')).toBe('HIT');
      const body = await response2.text();
      expect(body).toBe('find . -type f -size +10M');
    });

    it('不同的 prompt 应该产生不同的缓存 key', async () => {
      // Mock 第一个请求
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'ls',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response1 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'list directory',
      });

      expect(response1.headers.get('X-Cache-Status')).toBe('MISS');

      // Mock 第二个不同的请求
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-456',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'pwd',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response2 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'show current directory',
      });

      // 不同的 prompt 应该缓存未命中
      expect(response2.headers.get('X-Cache-Status')).toBe('MISS');
      const body = await response2.text();
      expect(body).toBe('pwd');
    });

    it('不同的 sysinfo 应该产生不同的缓存 key', async () => {
      // Mock 第一个请求 (Linux)
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'apt install nginx',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response1 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'install nginx',
      });

      expect(response1.headers.get('X-Cache-Status')).toBe('MISS');

      // Mock 第二个请求 (macOS)
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-456',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'brew install nginx',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response2 = await post('/', {
        sysinfo: 'OS=macOS; PkgMgr=brew',
        prompt: 'install nginx',
      });

      // 不同的 sysinfo 应该缓存未命中
      expect(response2.headers.get('X-Cache-Status')).toBe('MISS');
      const body = await response2.text();
      expect(body).toBe('brew install nginx');
    });
  });

  describe('缓存统计', () => {
    it('健康检查应该包含缓存统计信息', async () => {
      const response = await get('/health');
      expect(response.status).toBe(200);

      const body = await response.json();
      expect(body.services.aiCache).toBe(true);
      expect(body.cache).toBeDefined();
      expect(body.cache.enabled).toBe(true);
    });

    it('缓存统计应该正确追踪命中和未命中', async () => {
      // 第一次请求 - 未命中
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'echo hello',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response1 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'print hello',
      });

      // 验证第一次请求是缓存未命中
      expect(response1.headers.get('X-Cache-Status')).toBe('MISS');

      // 第二次请求 - 命中
      const response2 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'print hello',
      });

      // 验证第二次请求是缓存命中
      expect(response2.headers.get('X-Cache-Status')).toBe('HIT');

      // 检查健康检查中的缓存统计结构
      const healthResponse = await get('/health');
      const health = await healthResponse.json();

      // 验证缓存统计存在且格式正确
      expect(health.cache).toBeDefined();
      expect(health.cache.enabled).toBe(true);
      expect(health.cache.hits).toBeDefined();
      expect(health.cache.misses).toBeDefined();
      expect(health.cache.total).toBeDefined();
      expect(health.cache.hitRate).toBeDefined();
      expect(typeof health.cache.hitRate).toBe('string');
      expect(health.cache.hitRate).toMatch(/%$/);
    });
  });

  describe('缓存错误处理', () => {
    it('缓存读取失败应该降级到 API 调用', async () => {
      // 模拟缓存 KV 不可用的情况
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'cat file.txt',
            },
            finish_reason: 'stop',
          },
        ],
      });

      // 临时创建一个没有 AI_CACHE 绑定的 Worker
      const mfNoCache = new Miniflare({
        scriptPath: './worker.js',
        modules: true,
        modulesRules: [
          { type: 'ESModule', include: ['**/*.js'], fallthrough: true }
        ],
        kvNamespaces: ['QUOTA_KV'],  // 只有 QUOTA_KV，没有 AI_CACHE
        bindings: {
          OPENAI_API_KEY: 'test-api-key',
          OPENAI_API_MODEL: 'gpt-5-nano',
          OPENAI_API_BASE: 'https://api.openai.com/v1',
          SHARED_DAILY_LIMIT: '100',
        },
        compatibilityDate: '2025-10-26',
        fetchMock: mockAgent,
      });

      const response = await mfNoCache.dispatchFetch('https://fuckits.test/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: 'read file',
        }),
      });

      // 即使没有缓存，应该仍能正常工作
      expect(response.status).toBe(200);
      expect(response.headers.get('X-Cache-Status')).toBe(null); // 无缓存时不返回此头
      const body = await response.text();
      expect(body).toBe('cat file.txt');

      await mfNoCache.dispose();
    });

    it('locale 变化应该产生不同的缓存 key', async () => {
      // Mock 英文请求
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-en',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [{
          index: 0,
          message: { role: 'assistant', content: 'ls -la' },
          finish_reason: 'stop',
        }],
      });

      const responseEn = await post('/?lang=en', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'list files',
      });

      expect(responseEn.status).toBe(200);
      expect(responseEn.headers.get('X-Cache-Status')).toBe('MISS');

      // Mock 中文请求
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-zh',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [{
          index: 0,
          message: { role: 'assistant', content: 'ls -la' },
          finish_reason: 'stop',
        }],
      });

      const responseZh = await post('/?lang=zh', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'list files',
      });

      // 不同 locale 应该缓存未命中（因为 system prompt 不同）
      expect(responseZh.status).toBe(200);
      expect(responseZh.headers.get('X-Cache-Status')).toBe('MISS');
    });
  });
});
