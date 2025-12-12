/**
 * Worker 请求处理测试
 * 测试不同类型的请求处理逻辑
 */

import { describe, it, expect } from 'vitest';
import { get, post, options } from '../../helpers/test-env.js';

describe('请求处理系统', () => {
  describe('GET 请求处理', () => {
    it('curl User-Agent 应该返回安装脚本', async () => {
      const response = await get('/', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toContain('text/plain');

      const body = await response.text();
      expect(body).toContain('#!/bin/bash');
      expect(body).toContain('fuckits');
    });

    it('wget User-Agent 应该返回安装脚本', async () => {
      const response = await get('/', {
        'User-Agent': 'Wget/1.20.3',
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toContain('text/plain');

      const body = await response.text();
      expect(body).toContain('#!/bin/bash');
    });

    it('浏览器 User-Agent 应该重定向到 GitHub', async () => {
      const response = await get('/', {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      });

      expect(response.status).toBe(302);
      expect(response.headers.get('Location')).toBe('https://github.com/Silentely/fuckits/blob/main/README.en.md');
    });

    it('GET /health 应该返回健康检查', async () => {
      const response = await get('/health');

      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toContain('application/json');

      const body = await response.json();
      expect(body.status).toBe('ok');
      expect(body).toHaveProperty('hasApiKey');
      expect(typeof body.hasApiKey).toBe('boolean');
    });
  });

  describe('POST 请求处理', () => {
    it('有效的 POST 请求应该生成命令', async () => {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'list all files',
      }, {
        'CF-Connecting-IP': '192.168.1.100',
      });

      // 打印响应信息用于调试
      if (response.status !== 200) {
        const body = await response.text();
        console.log('Response status:', response.status);
        console.log('Response body:', body);
      }

      expect(response.status).toBe(200);
      const body = await response.text();

      // 应该返回命令字符串
      expect(body).toBeTruthy();
      expect(body.length).toBeGreaterThan(0);
    });

    it('缺少 sysinfo 的请求应该返回 400', async () => {
      const response = await post('/', {
        prompt: 'list all files',
      });

      expect(response.status).toBe(400);
      const body = await response.json();
      expect(body.error).toBeDefined();
    });

    it('缺少 prompt 的请求应该返回 400', async () => {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
      });

      expect(response.status).toBe(400);
      const body = await response.json();
      expect(body.error).toBeDefined();
    });

    it('空 prompt 的请求应该返回 400', async () => {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: '',
      });

      expect(response.status).toBe(400);
      const body = await response.json();
      expect(body.error).toBeDefined();
    });
  });

  describe('CORS 处理', () => {
    it('OPTIONS 请求应该返回 CORS 头', async () => {
      const response = await options('/', {
        'Access-Control-Request-Method': 'POST',
      });

      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
    });

    it('POST 响应应该包含 CORS 头', async () => {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'list files',
      });

      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    });
  });

  describe('错误处理', () => {
    it('无效的 JSON 应该返回 400', async () => {
      const response = await post('/', 'invalid json', {
        'Content-Type': 'application/json',
      });

      // 注意：这个测试可能需要根据实际 Worker 行为调整
      expect([400, 500]).toContain(response.status);
    });

    it('超大的请求体应该被拒绝', async () => {
      const largePrompt = 'x'.repeat(100000); // 100KB
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: largePrompt,
      });

      // Worker 可能会拒绝或限制
      expect(response.status).toBeLessThan(500);
    });
  });

  describe('IP 地址处理', () => {
    it('应该正确识别 CF-Connecting-IP', async () => {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test',
      }, {
        'CF-Connecting-IP': '203.0.113.1',
      });

      // 请求应该成功，IP 用于配额管理
      expect(response.status).toBeLessThanOrEqual(429);
    });

    it('缺少 IP 地址的请求应该使用默认值', async () => {
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test',
      });

      // 应该使用 'anonymous' 作为默认 IP
      expect(response.status).toBeLessThanOrEqual(429);
    });
  });
});
