/**
 * 并发请求处理测试
 * 测试高并发场景下的系统行为
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { post, clearKV } from '../../helpers/test-env.js';

describe('并发请求处理', () => {
  beforeEach(async () => {
    await clearKV();
  });

  it('并发请求应该正确处理', async () => {
    // 使用固定 IP 以触发配额限制
    const ip = '192.168.100.100';
    const requests = [];

    // 发送 5 个并发请求
    for (let i = 0; i < 5; i++) {
      requests.push(
        post('/', {
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: `concurrent ${i}`,
        }, {
          'CF-Connecting-IP': ip,
        })
      );
    }

    const responses = await Promise.all(requests);

    // 所有请求都应该得到响应
    expect(responses.length).toBe(5);

    // 应该有成功和/或被限流的请求（具体数量取决于竞态）
    const successCount = responses.filter(r => r.status === 200).length;
    const limitedCount = responses.filter(r => r.status === 429).length;

    expect(successCount + limitedCount).toBe(5);
    // 至少有一些请求被处理（成功或限流）
    expect(successCount + limitedCount).toBeGreaterThan(0);
  });
});
