/**
 * 安全关键工具函数测试
 * 覆盖 sanitizeCommand、timingSafeEqual、createErrorResponse、generateRequestId
 */

import { describe, it, expect } from 'vitest';
import { sanitizeCommand, timingSafeEqual, createErrorResponse, generateRequestId, checkCommandSafety } from '../../../worker.js';

describe('sanitizeCommand', () => {
  it('空输入应该返回空字符串', () => {
    expect(sanitizeCommand('')).toBe('');
    expect(sanitizeCommand(null)).toBe('');
    expect(sanitizeCommand(undefined)).toBe('');
    expect(sanitizeCommand(123)).toBe('');
  });

  it('应该去除首尾空白', () => {
    expect(sanitizeCommand('  ls -la  ')).toBe('ls -la');
  });

  it('应该提取 fenced 代码块中的命令', () => {
    const input = 'Here is the command:\n```bash\nls -la\n```';
    expect(sanitizeCommand(input)).toBe('ls -la');
  });

  it('应该提取 sh 标签的 fenced 代码块', () => {
    const input = '```sh\necho hello\n```';
    expect(sanitizeCommand(input)).toBe('echo hello');
  });

  it('应该提取单行 fenced 代码块', () => {
    const input = 'Use ```ls -la``` to list files';
    expect(sanitizeCommand(input)).toBe('ls -la');
  });

  it('应该移除 shebang 行', () => {
    const input = '#!/bin/bash\nls -la';
    expect(sanitizeCommand(input)).toBe('ls -la');
  });

  it('应该移除 #!/usr/bin/env bash shebang', () => {
    const input = '#!/usr/bin/env bash\necho test';
    expect(sanitizeCommand(input)).toBe('echo test');
  });

  it('应该移除注释行', () => {
    const input = '# This is a comment\nls -la\n# Another comment';
    expect(sanitizeCommand(input)).toBe('ls -la');
  });

  it('不应该移除命令中的 #', () => {
    expect(sanitizeCommand('echo "#hello"')).toBe('echo "#hello"');
  });

  it('多行命令应该保留内部换行', () => {
    const input = 'echo hello\necho world';
    expect(sanitizeCommand(input)).toBe('echo hello\necho world');
  });

  it('纯空白输入应该返回空字符串', () => {
    expect(sanitizeCommand('   ')).toBe('');
    expect(sanitizeCommand('\n\n')).toBe('');
  });
});

describe('timingSafeEqual', () => {
  it('相同字符串应该返回 true', () => {
    expect(timingSafeEqual('hello', 'hello')).toBe(true);
  });

  it('不同字符串应该返回 false', () => {
    expect(timingSafeEqual('hello', 'world')).toBe(false);
  });

  it('不同长度字符串应该返回 false', () => {
    expect(timingSafeEqual('abc', 'abcd')).toBe(false);
    expect(timingSafeEqual('abcd', 'abc')).toBe(false);
  });

  it('空字符串应该返回 true（两个都为空）', () => {
    expect(timingSafeEqual('', '')).toBe(true);
  });

  it('空字符串与非空应该返回 false', () => {
    expect(timingSafeEqual('', 'a')).toBe(false);
    expect(timingSafeEqual('a', '')).toBe(false);
  });

  it('非字符串参数应该返回 false', () => {
    expect(timingSafeEqual(null, 'a')).toBe(false);
    expect(timingSafeEqual('a', null)).toBe(false);
    expect(timingSafeEqual(123, '123')).toBe(false);
    expect(timingSafeEqual('123', 123)).toBe(false);
  });

  it('单字符差异应该返回 false', () => {
    expect(timingSafeEqual('abcdef', 'abcdeg')).toBe(false);
  });

  it('完全不同的长字符串应该返回 false', () => {
    const a = 'a'.repeat(1000);
    const b = 'b'.repeat(1000);
    expect(timingSafeEqual(a, b)).toBe(false);
  });
});

describe('createErrorResponse', () => {
  it('应该返回正确的 JSON 结构', async () => {
    const response = createErrorResponse('TEST_ERROR', 'Test message', 400);
    expect(response.status).toBe(400);

    const body = await response.json();
    expect(body.error).toBe('TEST_ERROR');
    expect(body.message).toBe('Test message');
    expect(body.timestamp).toBeDefined();
  });

  it('应该包含 requestId', async () => {
    const response = createErrorResponse('TEST_ERROR', 'msg', 500, {}, 'req-123');
    const body = await response.json();
    expect(body.requestId).toBe('req-123');
    expect(response.headers.get('X-Request-ID')).toBe('req-123');
  });

  it('没有 requestId 时不应该包含该字段', async () => {
    const response = createErrorResponse('TEST_ERROR', 'msg', 400);
    const body = await response.json();
    expect(body.requestId).toBeUndefined();
    expect(response.headers.get('X-Request-ID')).toBeNull();
  });

  it('应该合并 extra 字段', async () => {
    const response = createErrorResponse('TEST_ERROR', 'msg', 400, { retryAfter: 60 });
    const body = await response.json();
    expect(body.retryAfter).toBe(60);
  });

  it('Content-Type 应该是 JSON', () => {
    const response = createErrorResponse('TEST_ERROR', 'msg', 400);
    expect(response.headers.get('Content-Type')).toContain('application/json');
  });
});

describe('generateRequestId', () => {
  it('应该返回 UUID v4 格式', () => {
    const id = generateRequestId();
    expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });

  it('每次调用应该返回不同的 ID', () => {
    const id1 = generateRequestId();
    const id2 = generateRequestId();
    expect(id1).not.toBe(id2);
  });
});

describe('checkCommandSafety', () => {
  it('安全命令不应被拦截', () => {
    expect(checkCommandSafety('ls -la')).toEqual({ blocked: false, reason: '' });
    expect(checkCommandSafety('echo hello')).toEqual({ blocked: false, reason: '' });
    expect(checkCommandSafety('git status')).toEqual({ blocked: false, reason: '' });
  });

  it('应该拦截 rm -rf /', () => {
    const result = checkCommandSafety('rm -rf /');
    expect(result.blocked).toBe(true);
    expect(result.reason).toContain('root');
  });

  it('应该拦截 rm -rf /*', () => {
    const result = checkCommandSafety('rm -rf /*');
    expect(result.blocked).toBe(true);
  });

  it('应该拦截 rm --no-preserve-root', () => {
    const result = checkCommandSafety('rm -rf --no-preserve-root /');
    expect(result.blocked).toBe(true);
  });

  it('应该拦截 rm -rf .*', () => {
    const result = checkCommandSafety('rm -rf .*');
    expect(result.blocked).toBe(true);
  });

  it('应该拦截 dd 磁盘写入', () => {
    const result = checkCommandSafety('dd if=/dev/zero of=/dev/sda');
    expect(result.blocked).toBe(true);
    expect(result.reason).toContain('dd');
  });

  it('应该拦截 mkfs 格式化', () => {
    const result = checkCommandSafety('mkfs.ext4 /dev/sda1');
    expect(result.blocked).toBe(true);
    expect(result.reason).toContain('Filesystem format');
  });

  it('应该拦截 fdisk 分区操作', () => {
    expect(checkCommandSafety('fdisk /dev/sda').blocked).toBe(true);
    expect(checkCommandSafety('parted /dev/sda').blocked).toBe(true);
    expect(checkCommandSafety('shred /dev/sda').blocked).toBe(true);
  });

  it('应该拦截 fork bomb', () => {
    const result = checkCommandSafety(':(){ :|:& };:');
    expect(result.blocked).toBe(true);
    expect(result.reason).toContain('Fork bomb');
  });

  it('空输入不应被拦截', () => {
    expect(checkCommandSafety('')).toEqual({ blocked: false, reason: '' });
    expect(checkCommandSafety(null)).toEqual({ blocked: false, reason: '' });
    expect(checkCommandSafety(undefined)).toEqual({ blocked: false, reason: '' });
  });
});
