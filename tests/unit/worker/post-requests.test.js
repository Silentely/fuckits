/**
 * POST 请求边界条件测试
 * 测试各种边界输入的处理逻辑
 */

import { describe, it, expect } from 'vitest';
import { post, postRaw } from '../../helpers/test-env.js';

describe('POST 请求边界情况', () => {
  it('极短的 prompt 应该被处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'ls',
    }, {
      'CF-Connecting-IP': '10.0.0.1',
    });

    expect(response.status).toBe(200);
  });

  it('包含特殊字符的 prompt 应该被处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'find files with "quotes" and $variables',
    }, {
      'CF-Connecting-IP': '10.0.0.2',
    });

    expect(response.status).toBe(200);
  });

  it('包含换行符的 prompt 应该被处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'line1\nline2\nline3',
    }, {
      'CF-Connecting-IP': '10.0.0.3',
    });

    expect(response.status).toBe(200);
  });

  it('包含 Unicode 的 prompt 应该被处理', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: '查找所有 中文 文件 🔍',
    }, {
      'CF-Connecting-IP': '10.0.0.4',
    });

    expect(response.status).toBe(200);
  });

  it('只有空白的 prompt 应该返回 400', async () => {
    const response = await post('/', {
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: '   \t\n   ',
    });

    expect(response.status).toBe(400);
  });

  it('缺少 Content-Type 的 POST 应该尝试解析', async () => {
    // 使用 postRaw 不自动添加 Content-Type
    const response = await postRaw('/', JSON.stringify({
      sysinfo: 'OS=Linux; PkgMgr=apt',
      prompt: 'test',
    }));

    // 缺少 Content-Type 可能导致解析失败或成功（取决于 Worker 实现）
    expect([200, 400, 429]).toContain(response.status);
  });
});
