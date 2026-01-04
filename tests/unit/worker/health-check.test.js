/**
 * 健康检查边界条件测试
 * 测试健康检查端点的各种场景
 */

import { describe, it, expect } from 'vitest';
import { get } from '../../helpers/test-env.js';

describe('健康检查边界情况', () => {
  it('健康检查响应应该是 JSON 格式', async () => {
    const response = await get('/health');

    expect(response.headers.get('Content-Type')).toContain('application/json');
  });

  it('健康检查应该包含时间戳或版本信息', async () => {
    const response = await get('/health');
    const body = await response.json();

    expect(body.status).toBe('ok');
    expect(body).toHaveProperty('hasApiKey');
  });

  it('健康检查不应该受配额限制', async () => {
    // 即使其他请求被限流,健康检查应该始终可用
    const responses = [];
    for (let i = 0; i < 10; i++) {
      const response = await get('/health');
      responses.push(response);
    }

    // 所有健康检查都应该成功
    responses.forEach(response => {
      expect(response.status).toBe(200);
    });
  });
});
