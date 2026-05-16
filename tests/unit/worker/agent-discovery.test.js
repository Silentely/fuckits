/**
 * Agent 可发现性端点测试
 * 覆盖 robots.txt、sitemap.xml、.well-known 元数据、Link 头、Markdown 协商、WebMCP
 */

import { describe, it, expect } from 'vitest';
import { get } from '../../helpers/test-env.js';
import {
  handleRobotsTxt,
  handleSitemap,
  handleWellKnown,
  generateMarkdownContent,
  generateWebMcpHtml,
} from '../../../worker.js';

describe('robots.txt (Content Signals)', () => {
  it('应该返回 200 和 text/plain', async () => {
    const res = await get('/robots.txt');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('text/plain');
  });

  it('应该包含 Content-Signal 指令', async () => {
    const res = await get('/robots.txt');
    const body = await res.text();
    expect(body).toContain('Content-Signal: ai-train=no, search=yes, ai-input=no');
  });

  it('应该引用 sitemap.xml', async () => {
    const res = await get('/robots.txt');
    const body = await res.text();
    expect(body).toContain('Sitemap: https://fuckits.25500552.xyz/sitemap.xml');
  });

  it('应该包含 User-agent 和 Allow 指令', async () => {
    const res = await get('/robots.txt');
    const body = await res.text();
    expect(body).toContain('User-agent: *');
    expect(body).toContain('Allow: /');
  });
});

describe('sitemap.xml', () => {
  it('应该返回 200 和 application/xml', async () => {
    const res = await get('/sitemap.xml');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('application/xml');
  });

  it('应该包含所有规范 URL', async () => {
    const res = await get('/sitemap.xml');
    const body = await res.text();
    expect(body).toContain('https://fuckits.25500552.xyz/');
    expect(body).toContain('https://fuckits.25500552.xyz/zh');
    expect(body).toContain('https://fuckits.25500552.xyz/health');
  });

  it('应该是有效的 XML 格式', async () => {
    const res = await get('/sitemap.xml');
    const body = await res.text();
    expect(body).toContain('<?xml version="1.0"');
    expect(body).toContain('<urlset');
    expect(body).toContain('</urlset>');
  });
});

describe('API Catalog (RFC 9727)', () => {
  it('应该返回 application/linkset+json', async () => {
    const res = await get('/.well-known/api-catalog');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('application/linkset+json');
  });

  it('应该包含 linkset 数组', async () => {
    const res = await get('/.well-known/api-catalog');
    const body = await res.json();
    expect(body).toHaveProperty('linkset');
    expect(Array.isArray(body.linkset)).toBe(true);
    expect(body.linkset.length).toBeGreaterThan(0);
  });

  it('每个 linkset 条目应该有 anchor 和 link relations', async () => {
    const res = await get('/.well-known/api-catalog');
    const body = await res.json();
    const entry = body.linkset[0];
    expect(entry).toHaveProperty('anchor');
    expect(entry).toHaveProperty('service-desc');
    expect(entry).toHaveProperty('service-doc');
    expect(entry).toHaveProperty('status');
  });
});

describe('OAuth Discovery Metadata', () => {
  it('应该返回 200 和 application/json', async () => {
    const res = await get('/.well-known/openid-configuration');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });

  it('应该包含 issuer 和端点', async () => {
    const res = await get('/.well-known/openid-configuration');
    const body = await res.json();
    expect(body.issuer).toBe('https://fuckits.25500552.xyz');
    expect(body).toHaveProperty('authorization_endpoint');
    expect(body).toHaveProperty('token_endpoint');
  });
});

describe('OAuth Protected Resource Metadata (RFC 9728)', () => {
  it('应该返回 200 和 application/json', async () => {
    const res = await get('/.well-known/oauth-protected-resource');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });

  it('应该包含 resource 和 authorization_servers', async () => {
    const res = await get('/.well-known/oauth-protected-resource');
    const body = await res.json();
    expect(body.resource).toBe('https://fuckits.25500552.xyz');
    expect(Array.isArray(body.authorization_servers)).toBe(true);
    expect(body.authorization_servers.length).toBeGreaterThan(0);
  });
});

describe('MCP Server Card (SEP-1649)', () => {
  it('应该返回 200 和 application/json', async () => {
    const res = await get('/.well-known/mcp/server-card.json');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });

  it('应该包含 serverInfo、endpoint 和 capabilities', async () => {
    const res = await get('/.well-known/mcp/server-card.json');
    const body = await res.json();
    expect(body.serverInfo).toHaveProperty('name');
    expect(body.serverInfo).toHaveProperty('version');
    expect(body).toHaveProperty('endpoint');
    expect(body).toHaveProperty('capabilities');
    expect(body.capabilities.tools).toBe(true);
  });
});

describe('Agent Skills Discovery Index', () => {
  it('应该返回 200 和 application/json', async () => {
    const res = await get('/.well-known/agent-skills/index.json');
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('application/json');
  });

  it('应该包含 $schema 和 skills 数组', async () => {
    const res = await get('/.well-known/agent-skills/index.json');
    const body = await res.json();
    expect(body.$schema).toContain('agentskills.io');
    expect(Array.isArray(body.skills)).toBe(true);
    expect(body.skills.length).toBeGreaterThan(0);
  });

  it('每个 skill 条目应该有 name、type、description、url、digest', async () => {
    const res = await get('/.well-known/agent-skills/index.json');
    const body = await res.json();
    const skill = body.skills[0];
    expect(skill).toHaveProperty('name');
    expect(skill).toHaveProperty('type');
    expect(skill).toHaveProperty('description');
    expect(skill).toHaveProperty('url');
    expect(skill).toHaveProperty('digest');
    expect(skill.digest).toMatch(/^sha256:/);
  });
});

describe('Link 响应头 (RFC 8288)', () => {
  it('浏览器请求应该包含 Link 头指向 api-catalog', async () => {
    const res = await get('/', {
      'User-Agent': 'Mozilla/5.0 Chrome/120.0.0.0',
    });
    const link = res.headers.get('Link');
    expect(link).toBeTruthy();
    expect(link).toContain('rel="api-catalog"');
    expect(link).toContain('/.well-known/api-catalog');
  });
});

describe('Markdown 协商', () => {
  it('Accept: text/markdown 应该返回 text/markdown', async () => {
    const res = await get('/', {
      Accept: 'text/markdown',
    });
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('text/markdown');
  });

  it('Markdown 响应应该包含项目信息', async () => {
    const res = await get('/', {
      Accept: 'text/markdown',
    });
    const body = await res.text();
    expect(body).toContain('fuckits');
  });

  it('Accept: text/html 不应该返回 markdown', async () => {
    const res = await get('/', {
      Accept: 'text/html',
      'User-Agent': 'Mozilla/5.0 Chrome/120.0.0.0',
    });
    expect(res.headers.get('Content-Type')).not.toContain('text/markdown');
  });
});

describe('WebMCP HTML 页面', () => {
  it('浏览器请求应该返回 HTML', async () => {
    const res = await get('/', {
      'User-Agent': 'Mozilla/5.0 Chrome/120.0.0.0',
    });
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toContain('text/html');
  });

  it('HTML 应该包含 navigator.modelContext.provideContext', async () => {
    const res = await get('/', {
      'User-Agent': 'Mozilla/5.0 Chrome/120.0.0.0',
    });
    const body = await res.text();
    expect(body).toContain('navigator.modelContext.provideContext');
    expect(body).toContain('generate-command');
  });
});

describe('未知 .well-known 路径', () => {
  it('应该返回空响应（落入通用 GET 处理）', async () => {
    const res = await get('/.well-known/unknown-endpoint');
    // 未知 .well-known 路径会落入通用 handleGetRequest
    expect(res.status).toBe(200);
  });
});

describe('handler 函数直接调用', () => {
  it('handleRobotsTxt 应该返回有效 Response', () => {
    const res = handleRobotsTxt();
    expect(res).toBeInstanceOf(Response);
    expect(res.status).toBe(200);
  });

  it('handleSitemap 应该返回有效 Response', () => {
    const res = handleSitemap();
    expect(res).toBeInstanceOf(Response);
    expect(res.status).toBe(200);
  });

  it('handleWellKnown 应该路由到正确的处理器', () => {
    expect(handleWellKnown('/.well-known/api-catalog')).toBeInstanceOf(Response);
    expect(handleWellKnown('/.well-known/openid-configuration')).toBeInstanceOf(Response);
    expect(handleWellKnown('/.well-known/oauth-protected-resource')).toBeInstanceOf(Response);
    expect(handleWellKnown('/.well-known/mcp/server-card.json')).toBeInstanceOf(Response);
    expect(handleWellKnown('/.well-known/agent-skills/index.json')).toBeInstanceOf(Response);
  });

  it('handleWellKnown 对未知路径应该返回 null', () => {
    expect(handleWellKnown('/.well-known/unknown')).toBeNull();
  });

  it('generateMarkdownContent 应该返回包含项目名的字符串', () => {
    expect(generateMarkdownContent('en')).toContain('fuckits');
    expect(generateMarkdownContent('zh')).toContain('fuckits');
  });

  it('generateWebMcpHtml 应该返回包含 provideContext 的 HTML', () => {
    const html = generateWebMcpHtml('en', 'https://github.com/test');
    expect(html).toContain('navigator.modelContext.provideContext');
    expect(html).toContain('generate-command');
  });
});
