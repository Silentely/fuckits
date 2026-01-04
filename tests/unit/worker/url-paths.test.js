/**
 * URL 路径边界条件测试
 * 测试各种 URL 路径的处理逻辑
 */

import { describe, it, expect } from 'vitest';
import { get } from '../../helpers/test-env.js';

describe('URL 路径边界情况', () => {
  it('/zh/ 带尾斜杠应该返回中文脚本', async () => {
    const response = await get('/zh/', {
      'User-Agent': 'curl/7.68.0',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('FUCKITS_LOCALE="zh"');
  });

  it('/ZH 大写应该返回中文脚本', async () => {
    const response = await get('/ZH', {
      'User-Agent': 'curl/7.68.0',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('FUCKITS_LOCALE="zh"');
  });

  it('/en 路径应该返回英文脚本', async () => {
    const response = await get('/en', {
      'User-Agent': 'curl/7.68.0',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('FUCKITS_LOCALE="en"');
  });

  it('无效路径应该返回默认英文脚本', async () => {
    const response = await get('/invalid-path', {
      'User-Agent': 'curl/7.68.0',
    });

    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain('#!/bin/bash');
  });

  it('/health 路径是大小写敏感的', async () => {
    // /health 应该返回 JSON
    const response1 = await get('/health');
    expect(response1.status).toBe(200);
    const body1 = await response1.json();
    expect(body1.status).toBe('ok');

    // /HEALTH 应该返回安装脚本（大小写敏感）
    const response2 = await get('/HEALTH', {
      'User-Agent': 'curl/7.79.1',
    });
    expect(response2.status).toBe(200);
    const text = await response2.text();
    expect(text).toContain('#!/bin/bash');
  });
});
