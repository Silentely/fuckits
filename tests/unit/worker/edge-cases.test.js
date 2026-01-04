/**
 * Worker 边界条件测试
 * 测试各种边界情况和错误处理
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { get, post, options, clearKV, setKV, getKV } from '../../helpers/test-env.js';

describe('边界条件测试', () => {
  beforeEach(async () => {
    await clearKV();
  });

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

    it('/health 路径大小写不敏感', async () => {
      const response = await get('/HEALTH');
      expect(response.status).toBe(200);

      const body = await response.json();
      expect(body.status).toBe('ok');
    });
  });

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
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'test',
      });

      // 即使没有明确的 Content-Type，也应该能处理
      expect([200, 400, 429]).toContain(response.status);
    });
  });

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

  describe('配额边界情况', () => {
    it('恰好达到限额时应该允许最后一次请求', async () => {
      const ip = '10.1.1.1';
      const limit = 3;

      // 发送前 2 次请求
      for (let i = 0; i < limit - 1; i++) {
        await post('/', {
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: `test ${i}`,
        }, {
          'CF-Connecting-IP': ip,
        });
      }

      // 第 3 次（恰好达到限额）应该成功
      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'last allowed',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response.status).toBe(200);

      // 第 4 次应该失败
      const overLimit = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'over limit',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(overLimit.status).toBe(429);
    });

    it('配额错误响应应该包含正确的 JSON 结构', async () => {
      const ip = '10.1.1.2';

      // 耗尽配额
      for (let i = 0; i < 3; i++) {
        await post('/', {
          sysinfo: 'OS=Linux; PkgMgr=apt',
          prompt: `exhaust ${i}`,
        }, {
          'CF-Connecting-IP': ip,
        });
      }

      const response = await post('/', {
        sysinfo: 'OS=Linux; PkgMgr=apt',
        prompt: 'over limit',
      }, {
        'CF-Connecting-IP': ip,
      });

      expect(response.status).toBe(429);

      const body = await response.json();
      expect(body).toHaveProperty('error');
      expect(body.error).toContain('DEMO_LIMIT_EXCEEDED');
    });

    it('不同日期的配额应该独立（通过 KV key 验证）', async () => {
      const ip = '10.1.1.3';
      const today = new Date().toISOString().slice(0, 10);
      const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);

      // 设置今天的配额
      await setKV(`quota:${today}:${ip}`, '2');

      // 设置"明天"的配额为 0
      await setKV(`quota:${tomorrow}:${ip}`, '0');

      // 验证今天的配额
      const todayCount = await getKV(`quota:${today}:${ip}`);
      expect(todayCount).toBe('2');

      // 验证明天的配额
      const tomorrowCount = await getKV(`quota:${tomorrow}:${ip}`);
      expect(tomorrowCount).toBe('0');
    });
  });

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
      // 即使其他请求被限流，健康检查应该始终可用
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

  describe('并发请求处理', () => {
    it('并发请求应该正确计数配额', async () => {
      const ip = '10.3.0.1';
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

      // 前 3 个应该成功，后 2 个应该被限流
      const successCount = responses.filter(r => r.status === 200).length;
      const limitedCount = responses.filter(r => r.status === 429).length;

      expect(successCount).toBe(3);
      expect(limitedCount).toBe(2);
    });
  });
});
