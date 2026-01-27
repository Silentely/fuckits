/**
 * Worker 配额管理测试
 * 测试 KV 存储配额管理和内存降级功能
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { getMiniflare, clearKV, setKV, getKV, post, get } from '../../helpers/test-env.js';

describe('配额管理系统', () => {
  beforeEach(async () => {
    // 每个测试前清空 KV 存储
    await clearKV();
  });

  describe('KV 配额测试', () => {
    it('应该正确持久化配额计数到 KV', async () => {
      const ip = '192.168.1.1';
      const today = new Date().toISOString().slice(0, 10);
      const key = `quota:${today}:${ip}`;

      // 发送第一个请求
      const response1 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response1.status).toBe(200);

      // 检查 KV 中的计数
      const count = await getKV(key);
      expect(count).toBe('1');

      // 发送第二个请求
      const response2 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command 2',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response2.status).toBe(200);

      // 检查计数递增
      const count2 = await getKV(key);
      expect(count2).toBe('2');
    });

    it('应该在达到限额后拒绝请求', async () => {
      const ip = '192.168.1.2';
      const limit = 3; // 假设限额为 3

      // 发送 3 个请求（达到限额）
      for (let i = 0; i < limit; i++) {
        const response = await post('/', {
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: `test command ${i + 1}`,
        }, {
          'CF-Connecting-IP': ip,
        });

        expect(response.status).toBe(200);
      }

      // 第 4 个请求应该被拒绝
      const response4 = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test command 4',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response4.status).toBe(429);
      const body = await response4.json();
      expect(body.error).toContain('DEMO_LIMIT_EXCEEDED');
    });

    it('不同 IP 应该独立计数', async () => {
      const ip1 = '192.168.1.3';
      const ip2 = '192.168.1.4';

      // IP1 发送 2 个请求
      await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test 1',
      }, {
        'CF-Connecting-IP': ip1,
      });

      await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test 2',
      }, {
        'CF-Connecting-IP': ip1,
      });

      // IP2 发送 1 个请求
      await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test 3',
      }, {
        'CF-Connecting-IP': ip2,
      });

      // 验证计数
      const today = new Date().toISOString().slice(0, 10);
      const count1 = await getKV(`quota:${today}:${ip1}`);
      const count2 = await getKV(`quota:${today}:${ip2}`);

      expect(count1).toBe('2');
      expect(count2).toBe('1');
    });
  });

  describe('管理员绕过测试', () => {
    it('正确的 adminKey 应该绕过限额', async () => {
      const ip = '192.168.1.5';
      const limit = 2;

      // 用完正常配额
      for (let i = 0; i < limit; i++) {
        await post('/', {
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: `test ${i + 1}`,
        }, {
          'CF-Connecting-IP': ip,
        });
      }

      // 使用 adminKey 应该能绕过限额
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test admin',
        adminKey: 'test-admin-key', // 与 test-env.js 中的配置一致
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response.status).toBe(200);
    });

    it('错误的 adminKey 不应该绕过限额', async () => {
      const ip = '192.168.1.6';
      const limit = 3; // 与环境变量 SHARED_DAILY_LIMIT 一致

      // 用完正常配额
      for (let i = 0; i < limit; i++) {
        await post('/', {
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: `test ${i + 1}`,
        }, {
          'CF-Connecting-IP': ip,
        });
      }

      // 使用错误的 adminKey 应该被拒绝
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test wrong admin',
        adminKey: 'wrong-admin-key',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response.status).toBe(429);
    });
  });

  describe('健康检查端点', () => {
    it('GET /health 应该返回 JSON 状态', async () => {
      const response = await get('/health');

      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toContain('application/json');

      const body = await response.json();
      expect(body.status).toBe('ok');
      expect(body).toHaveProperty('services');
      expect(body.services).toHaveProperty('apiKey');
      expect(typeof body.services.apiKey).toBe('boolean');
      expect(body).toHaveProperty('stats');
      expect(body.stats).toHaveProperty('totalCalls');
      expect(body.stats).toHaveProperty('uniqueIPs');
    });
  });
});
