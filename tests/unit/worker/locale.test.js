/**
 * Worker 语言检测测试
 * 测试 locale 检测逻辑（URL 路径、query 参数、Accept-Language header）
 */

import { describe, it, expect } from 'vitest';
import { get } from '../../helpers/test-env.js';

describe('语言检测系统', () => {
  describe('URL 路径检测', () => {
    it('访问 /zh 路径应该返回中文脚本', async () => {
      const response = await get('/zh', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toContain('text/plain');

      const body = await response.text();
      // 检查中文特征字符串
      expect(body).toContain('FUCKITS_LOCALE="zh"');
    });

    it('访问根路径应该返回英文脚本', async () => {
      const response = await get('/', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      const body = await response.text();

      // 检查英文特征字符串
      expect(body).toContain('FUCKITS_LOCALE="en"');
    });
  });

  describe('Query 参数检测', () => {
    it('?lang=zh 参数应该返回中文脚本', async () => {
      const response = await get('/?lang=zh', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      expect(body).toContain('FUCKITS_LOCALE="zh"');
    });

    it('?lang=en 参数应该返回英文脚本', async () => {
      const response = await get('/?lang=en', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      expect(body).toContain('FUCKITS_LOCALE="en"');
    });
  });

  describe('Accept-Language Header 检测', () => {
    it('Accept-Language: zh-CN 应该返回中文脚本', async () => {
      const response = await get('/', {
        'User-Agent': 'curl/7.68.0',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      expect(body).toContain('FUCKITS_LOCALE="zh"');
    });

    it('Accept-Language: en-US 应该返回英文脚本', async () => {
      const response = await get('/', {
        'User-Agent': 'curl/7.68.0',
        'Accept-Language': 'en-US,en;q=0.9',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      expect(body).toContain('FUCKITS_LOCALE="en"');
    });
  });

  describe('默认行为', () => {
    it('无任何语言标识时应该返回英文脚本', async () => {
      const response = await get('/', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      expect(body).toContain('FUCKITS_LOCALE="en"');
    });
  });

  describe('优先级测试', () => {
    it('URL 路径优先级高于 query 参数', async () => {
      const response = await get('/zh?lang=en', {
        'User-Agent': 'curl/7.68.0',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      // URL 路径的 /zh 应该优先
      expect(body).toContain('FUCKITS_LOCALE="zh"');
    });

    it('query 参数优先级高于 Accept-Language', async () => {
      const response = await get('/?lang=en', {
        'User-Agent': 'curl/7.68.0',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      });

      expect(response.status).toBe(200);
      const body = await response.text();
      // query 参数 lang=en 应该优先
      expect(body).toContain('FUCKITS_LOCALE="en"');
    });
  });
});
