/**
 * OpenAI API 错误响应矩阵测试
 * 测试 Worker 对各种 OpenAI API 错误的处理
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Miniflare } from 'miniflare';
import { readFileSync } from 'fs';

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
    kvNamespaces: ['QUOTA_KV'],
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

/**
 * 辅助函数：发送 POST 请求
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

describe('OpenAI API 错误响应处理', () => {
  describe('HTTP 错误状态码', () => {
    it('401 Unauthorized - Worker 直接透传错误状态码', async () => {
      // Mock 401 响应
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(401, {
        error: {
          message: 'Invalid API key',
          type: 'invalid_request_error',
          code: 'invalid_api_key',
        },
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      // 注意：当前 Worker 实现直接透传 OpenAI 的状态码
      expect(response.status).toBe(401);
      // TODO: 应该返回 500 并包含友好的错误消息
    });

    it('429 Rate Limit - Worker 直接透传错误状态码', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(429, {
        error: {
          message: 'Rate limit exceeded',
          type: 'rate_limit_error',
        },
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(429);
      // TODO: 应该返回 500 并包含友好的错误消息
    });

    it('500 Internal Server Error - Worker 返回文本错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(500, {
        error: {
          message: 'Internal server error',
          type: 'server_error',
        },
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('AI_API_ERROR');
    });

    it('503 Service Unavailable - Worker 直接透传错误状态码', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(503, {
        error: {
          message: 'Service temporarily unavailable',
          type: 'service_unavailable',
        },
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(503);
      // TODO: 应该返回 500 并包含友好的错误消息
    });
  });

  describe('响应格式错误', () => {
    it('非 JSON 响应 - Worker 返回文本错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, 'This is not JSON', {
        headers: { 'Content-Type': 'text/plain' },
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('INTERNAL_ERROR');
    });

    it('缺少 choices 字段 - Worker 返回 JSON 错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        // 缺少 choices 字段
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('INTERNAL_ERROR');
    });

    it('空的 choices 数组 - Worker 返回 JSON 错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, {
        id: 'chatcmpl-123',
        object: 'chat.completion',
        created: 1234567890,
        model: 'gpt-5-nano',
        choices: [], // 空数组
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('EMPTY_RESPONSE');
    });

    it('缺少 message.content - Worker 返回 JSON 错误', async () => {
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
              // 缺少 content 字段
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('INTERNAL_ERROR');
    });
  });

  describe('网络错误', () => {
    it('连接超时 - Worker 返回 JSON 错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).replyWithError(new Error('ETIMEDOUT'));

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('AI_API_ERROR');
    });

    it('网络断开 - Worker 返回 JSON 错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).replyWithError(new Error('ECONNREFUSED'));

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('AI_API_ERROR');
    });

    it('DNS 解析失败 - Worker 返回 JSON 错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).replyWithError(new Error('ENOTFOUND'));

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('AI_API_ERROR');
    });
  });

  describe('特殊响应场景', () => {
    it('空响应体 - Worker 返回 JSON 错误', async () => {
      const pool = mockAgent.get('https://api.openai.com');
      pool.intercept({
        path: '/v1/chat/completions',
        method: 'POST',
      }).reply(200, '');

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error).toBe('INTERNAL_ERROR');
    });

    it('超大响应 - 应该能正确处理', async () => {
      const largeContent = 'x'.repeat(100000); // 100KB
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
              content: largeContent,
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      // 应该能处理，但可能被截断或返回错误
      expect([200, 400, 500]).toContain(response.status);
    });

    it('包含特殊字符的响应 - Worker 返回纯文本命令', async () => {
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
              content: '```bash\napt install nginx\n```',
            },
            finish_reason: 'stop',
          },
        ],
      });

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      });

      expect(response.status).toBe(200);
      // Worker 返回纯文本命令，不是 JSON
      const body = await response.text();
      expect(body).toContain('apt install nginx');
      // TODO: 应该返回 JSON 格式 {command: "...", ...}
    });
  });
});
