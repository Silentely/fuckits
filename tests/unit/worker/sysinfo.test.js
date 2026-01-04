/**
 * sysinfo 边界条件测试
 * 测试系统信息输入的各种边界场景
 */

import { describe, it, expect } from 'vitest';
import { post } from '../../helpers/test-env.js';

describe('sysinfo 边界情况', () => {
  it('极长的 sysinfo 应该被处理', async () => {
    const longSysinfo = 'OS=Linux; PkgMgr=apt; ' + 'Extra=data; '.repeat(100);

    const response = await post('/', {
      sysinfo: longSysinfo,
      prompt: 'test',
    }, {
      'CF-Connecting-IP': '10.2.0.1',
    });

    expect([200, 400]).toContain(response.status);
  });

  it('包含特殊字符的 sysinfo 应该被处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt; Path=/usr/bin:/usr/local/bin; User=$USER',
      prompt: 'test',
    }, {
      'CF-Connecting-IP': '10.2.0.2',
    });

    expect(response.status).toBe(200);
  });

  it('空 sysinfo 应该返回错误', async () => {
    const response = await post('/', {
      sysinfo: '',
      prompt: 'test',
    });

    expect(response.status).toBe(400);
  });
});
