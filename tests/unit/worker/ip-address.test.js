/**
 * IP 地址边界条件测试
 * 测试各种 IP 地址格式的处理逻辑
 */

import { describe, it, expect } from 'vitest';
import { post } from '../../helpers/test-env.js';

describe('IP 地址边界情况', () => {
  it('IPv6 地址应该正确处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'test ipv6',
    }, {
      'CF-Connecting-IP': '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
    });

    expect(response.status).toBe(200);
  });

  it('本地回环地址应该正确处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'test localhost',
    }, {
      'CF-Connecting-IP': '127.0.0.1',
    });

    expect(response.status).toBe(200);
  });

  it('私有 IP 地址应该正确处理', async () => {
    const privateIPs = ['192.168.1.1', '10.0.0.1', '172.16.0.1'];

    for (const ip of privateIPs) {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response.status).toBeLessThanOrEqual(429);
    }
  });
});
