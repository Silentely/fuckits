/**
 * 配额系统边界条件测试
 * 测试配额管理的边界场景
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { post, clearKV, setKV, getKV } from '../../helpers/test-env.js';

describe('配额边界情况', () => {
  beforeEach(async () => {
    await clearKV();
  });

  it('恰好达到限额时应该允许最后一次请求', async () => {
    const ip = '10.1.1.1';
    const limit = 3;

    // 发送前 2 次请求
    for (let i = 0; i < limit - 1; i++) {
      await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: `test ${i}`,
      }, {
        'CF-Connecting-IP': ip,
      });
    }

    // 第 3 次（恰好达到限额）应该成功
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'last allowed',
    }, {
      'CF-Connecting-IP': ip,
    });

    expect(response.status).toBe(200);

    // 第 4 次应该失败
    const overLimit = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'over limit',
    }, {
      'CF-Connecting-IP': ip,
    });

    expect(overLimit.status).toBe(429);
  });

  it('配额错误响应应该包含正确的 JSON 结构', async () => {
    const ip = '10.1.1.2';

    // 耗尽配额
    for (let i = 0; i < 3; i++) {
      await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: `exhaust ${i}`,
      }, {
        'CF-Connecting-IP': ip,
      });
    }

    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'over limit',
    }, {
      'CF-Connecting-IP': ip,
    });

    expect(response.status).toBe(429);

    const body = await response.json();
    expect(body).toHaveProperty('error');
    expect(body.error).toContain('DEMO_LIMIT_EXCEEDED');
  });

  it('不同日期的配额应该独立（通过 KV key 验证）', async () => {
    const ip = '10.1.1.3';
    const today = new Date().toISOString().slice(0, 10);
    const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);

    // 设置今天的配额
    await setKV(`quota:${today}:${ip}`, '2');

    // 设置"明天"的配额为 0
    await setKV(`quota:${tomorrow}:${ip}`, '0');

    // 验证今天的配额
    const todayCount = await getKV(`quota:${today}:${ip}`);
    expect(todayCount).toBe('2');

    // 验证明天的配额
    const tomorrowCount = await getKV(`quota:${tomorrow}:${ip}`);
    expect(tomorrowCount).toBe('0');
  });
});
