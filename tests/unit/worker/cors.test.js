/**
 * CORS 边界条件测试
 * 测试跨域资源共享的各种场景
 */

import { describe, it, expect } from 'vitest';
import { options } from '../../helpers/test-env.js';

describe('CORS 边界情况', () => {
  it('OPTIONS 请求应该处理多种方法', async () => {
    const methods = ['GET', 'POST', 'PUT', 'DELETE'];

    for (const method of methods) {
      const response = await options('/', {
        'Access-Control-Request-Method': method,
      });

      expect(response.headers.get('Access-Control-Allow-Methods')).toBeTruthy();
    }
  });

  it('自定义 Origin 应该被接受', async () => {
    const response = await options('/', {
      'Origin': 'https://custom-domain.com',
      'Access-Control-Request-Method': 'POST',
    });

    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
  });

  it('预检请求应该包含所有必要的 CORS 头', async () => {
    const response = await options('/');

    expect(response.headers.get('Access-Control-Allow-Origin')).toBeTruthy();
    expect(response.headers.get('Access-Control-Allow-Methods')).toBeTruthy();
  });
});
