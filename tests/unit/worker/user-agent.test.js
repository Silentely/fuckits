/**
 * User-Agent 边界条件测试
 * 测试不同 User-Agent 的处理逻辑
 */

import { describe, it, expect } from 'vitest';
import { get } from '../../helpers/test-env.js';

describe('User-Agent 边界情况', () => {
  it('空 User-Agent 应该返回安装脚本', async () => {
    const response = await get('/', {
      'User-Agent': '',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('#!/bin/bash');
  });

  it('未知 User-Agent 应该返回安装脚本', async () => {
    const response = await get('/', {
      'User-Agent': 'UnknownAgent/1.0',
    });

    // 非浏览器 UA 应该返回脚本
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('#!/bin/bash');
  });

  it('PowerShell User-Agent 应该返回安装脚本', async () => {
    const response = await get('/', {
      'User-Agent': 'PowerShell/7.0',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('#!/bin/bash');
  });

  it('HTTPie User-Agent 应该返回安装脚本', async () => {
    const response = await get('/', {
      'User-Agent': 'HTTPie/3.0',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('#!/bin/bash');
  });

  it('各种浏览器 UA 应该重定向', async () => {
    const browserUAs = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
      'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
    ];

    for (const ua of browserUAs) {
      const response = await get('/', {
        'User-Agent': ua,
      });
      expect(response.status).toBe(302);
    }
  });
});
