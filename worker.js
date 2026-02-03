// --- FUCKIT.SH Cloudflare Worker ---

// This is the content of your main.sh installer script.
// It will be served when a user makes a GET request.
function b64_to_utf8(str) {
  try {
    // This is a more robust way to decode base64 to UTF-8
    const binaryString = atob(str);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return new TextDecoder().decode(bytes);
  } catch (e) {
    console.error("Failed to decode base64 string:", e);
    return ""; // Return empty string on failure
  }
}

// const INSTALLER_SCRIPT = ... (removed - now served from R2)
// const INSTALLER_SCRIPT_ZH = ... (removed - now served from R2)

const README_URL_EN = 'https://github.com/Silentely/fuckits/blob/main/README.en.md';
const README_URL_ZH = 'https://github.com/Silentely/fuckits';
const INSTALLER_FILENAME_EN = 'fuckits.sh';
const INSTALLER_FILENAME_ZH = 'fuckits-zh.sh';
const SHARED_DEFAULT_LIMIT = 10;
const SECONDS_IN_DAY = 24 * 60 * 60;

let lastQuotaDate = null;
const sharedUsage = new Map();

function resolveSharedLimit(env) {
  const raw = Number(env?.SHARED_DAILY_LIMIT ?? env?.SHARED_DEFAULT_LIMIT);
  if (Number.isFinite(raw) && raw > 0) {
    return Math.floor(raw);
  }
  return SHARED_DEFAULT_LIMIT;
}

/**
 * 常量时间字符串比较，防止时序攻击
 * @param {string} a 第一个字符串
 * @param {string} b 第二个字符串
 * @returns {boolean} 是否相等
 */
function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') {
    return false;
  }

  // 确保比较时间恒定，不受字符串长度差异影响
  const lenA = a.length;
  const lenB = b.length;

  // 使用较长字符串的长度进行比较，防止长度泄露
  const maxLen = Math.max(lenA, lenB);

  let result = lenA ^ lenB; // 长度不等时结果非零

  for (let i = 0; i < maxLen; i++) {
    // 使用模运算确保索引不越界，同时保持恒定时间
    const charA = a.charCodeAt(i % lenA) || 0;
    const charB = b.charCodeAt(i % lenB) || 0;
    result |= charA ^ charB;
  }

  return result === 0;
}

function resolveQuotaStore(env) {
  if (env?.QUOTA_KV && typeof env.QUOTA_KV.get === 'function') {
    return env.QUOTA_KV;
  }

  const alias = env?.QUOTA_KV_BINDING;
  if (alias && env?.[alias] && typeof env[alias].get === 'function') {
    return env[alias];
  }

  if (env?.fuckits && typeof env.fuckits.get === 'function') {
    return env.fuckits;
  }

  return null;
}

async function checkSharedQuota(ip, limit, env) {
  const quotaStore = resolveQuotaStore(env);
  if (quotaStore) {
    return checkSharedQuotaKV(quotaStore, ip, limit);
  }
  return checkSharedQuotaInMemory(ip, limit);
}

function checkSharedQuotaInMemory(ip, limit) {
  const today = new Date().toISOString().slice(0, 10);
  if (lastQuotaDate !== today) {
    sharedUsage.clear();
    lastQuotaDate = today;
  }
  const key = ip || 'anonymous';
  const current = (sharedUsage.get(key) || 0) + 1;
  sharedUsage.set(key, current);
  return {
    allowed: current <= limit,
    remaining: Math.max(limit - current, 0),
    count: current,
  };
}

/**
 * 使用 KV 存储检查并更新配额计数器
 *
 * ⚠️ 竞态条件警告 (Race Condition Notice)
 * =========================================
 * 此函数采用非原子的 get → check → put 模式，存在以下已知限制：
 *
 * 1. 竞态窗口：在 kv.get() 和 kv.put() 之间（约 10-50ms），
 *    并发请求可能读取到相同的旧计数值，导致多个请求同时"通过"检查
 *
 * 2. 最坏情况：如果 N 个请求在竞态窗口内同时到达，
 *    理论上所有 N 个请求都可能被放行，实际超出限额 N-1 次
 *
 * 3. KV 最终一致性：跨 PoP 边缘节点的传播延迟（通常 < 60s）
 *    可能导致不同地区看到的计数值不一致
 *
 * 设计决策：对于演示配额系统，这是可接受的权衡：
 * - 目标是防止明显滥用，而非提供计费级别精度
 * - 简单实现优于复杂的分布式锁
 * - 偶发的超额（可能 1-3 次/天）不影响核心功能
 *
 * 如需严格配额：请迁移到 Cloudflare Durable Objects（提供强一致性）
 *
 * @param {object} kv - KV 命名空间绑定
 * @param {string} ip - 客户端 IP 地址
 * @param {number} limit - 每日请求限额
 * @returns {Promise<{allowed: boolean, remaining: number, count: number}>}
 */
async function checkSharedQuotaKV(kv, ip, limit) {
  const today = new Date().toISOString().slice(0, 10);
  const key = `quota:${today}:${ip || 'anonymous'}`;
  const ttl = secondsUntilNextUtcMidnight();

  try {
    const raw = await kv.get(key);
    const currentCount = Number(raw) || 0;

    // 预检查：如果已达到或超过限额，立即拒绝
    // 这减少（但不能完全消除）竞态条件的影响
    if (currentCount >= limit) {
      return {
        allowed: false,
        remaining: 0,
        count: currentCount,
      };
    }

    const newCount = currentCount + 1;
    await kv.put(key, String(newCount), { expirationTtl: ttl > 0 ? ttl : SECONDS_IN_DAY });

    return {
      allowed: newCount <= limit,
      remaining: Math.max(limit - newCount, 0),
      count: newCount,
    };
  } catch (error) {
    console.error('Failed to persist quota counter, falling back to in-memory map', error);
    return checkSharedQuotaInMemory(ip, limit);
  }
}

function secondsUntilNextUtcMidnight() {
  const now = new Date();
  const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1);
  return Math.ceil((midnight - now.getTime()) / 1000);
}

/**
 * 获取当日调用统计信息
 * @param {object|null} quotaStore - KV 存储或 null
 * @returns {Promise<{totalCalls: number, uniqueIPs: number}>}
 */
async function getDailyStats(quotaStore) {
  const today = new Date().toISOString().slice(0, 10);

  // 内存存储统计
  if (!quotaStore) {
    if (lastQuotaDate !== today) {
      return { totalCalls: 0, uniqueIPs: 0 };
    }
    let totalCalls = 0;
    for (const count of sharedUsage.values()) {
      totalCalls += count;
    }
    return { totalCalls, uniqueIPs: sharedUsage.size };
  }

  // KV 存储统计
  try {
    const prefix = `quota:${today}:`;
    const keys = await quotaStore.list({ prefix });
    let totalCalls = 0;
    const uniqueIPs = keys.keys.length;

    // 并行获取所有计数值
    const counts = await Promise.all(
      keys.keys.map(async (k) => {
        const raw = await quotaStore.get(k.name);
        return Number(raw) || 0;
      })
    );

    for (const count of counts) {
      totalCalls += count;
    }

    return { totalCalls, uniqueIPs };
  } catch (error) {
    console.error('Failed to get daily stats from KV', error);
    return { totalCalls: -1, uniqueIPs: -1 };
  }
}

function isBrowserRequest(userAgent = '') {
  return /Mozilla|Chrome|Safari|Firefox|Edg/.test(userAgent);
}

/**
 * 清理和验证 AI 返回的命令
 * 从各种 AI 响应格式中提取可执行命令
 *
 * 支持的格式:
 * 1. 纯命令文本 (无 markdown)
 * 2. 单个 fenced 代码块 (```bash ... ```)
 * 3. 带解释文字的响应 (提取首个代码块)
 * 4. 内联代码 (`command`)
 * 5. 多个代码块 (提取首个)
 *
 * @param {string} rawCommand AI 返回的原始命令
 * @returns {string} 清理后的命令
 */
function sanitizeCommand(rawCommand) {
  if (!rawCommand || typeof rawCommand !== 'string') {
    return '';
  }

  let command = rawCommand.trim();

  // 策略 1: 尝试提取首个 fenced 代码块 (```bash ... ``` 或 ```sh ... ``` 等)
  // 注意: 不使用 ^ 和 $ 锚点，允许代码块出现在任意位置
  const fencedBlockPattern = /```(?:bash|sh|shell|zsh|command)?\s*\n([\s\S]*?)\n```/;
  const fencedMatch = command.match(fencedBlockPattern);
  if (fencedMatch && fencedMatch[1].trim()) {
    command = fencedMatch[1].trim();
  } else {
    // 策略 2: 尝试提取单行 fenced 代码块 (```command```)
    const inlineFencedPattern = /```(?:bash|sh|shell|zsh|command)?\s*([^\n`]+?)\s*```/;
    const inlineFencedMatch = command.match(inlineFencedPattern);
    if (inlineFencedMatch && inlineFencedMatch[1].trim()) {
      command = inlineFencedMatch[1].trim();
    } else {
      // 策略 3: 尝试提取内联代码 (`command`)
      // 只在响应看起来像是带解释文字时使用
      if (command.includes('`') && /[a-zA-Z].*:/.test(command)) {
        const inlineCodePattern = /`([^`]+)`/;
        const inlineMatch = command.match(inlineCodePattern);
        if (inlineMatch && inlineMatch[1].trim()) {
          // 验证提取的内容看起来像命令 (包含常见命令或路径)
          const extracted = inlineMatch[1].trim();
          if (/^[a-zA-Z_\/\.]/.test(extracted) && !extracted.includes(' is ')) {
            command = extracted;
          }
        }
      }
    }
  }

  // 移除 shebang 行 (#!/bin/bash, #!/usr/bin/env bash, 等)
  command = command.replace(/^#!\/(?:usr\/)?(?:bin\/)?(?:env\s+)?(?:ba)?sh\s*\n?/gm, '');

  // 移除 shell 注释行 (以 # 开头的行，但保留 #! 开头的已处理)
  // 注意: 只移除整行注释，不处理行内注释以避免破坏合法命令
  command = command.replace(/^[^\S\n]*#(?!!)[^\n]*\n?/gm, '');

  // 移除开头的空行
  command = command.replace(/^\s*\n+/, '');

  // 移除结尾的空行
  command = command.replace(/\n+\s*$/, '');

  return command.trim();
}

function resolveLocale(url, headers) {
  const pathname = url.pathname.toLowerCase();
  if (pathname === '/zh' || pathname.startsWith('/zh/')) {
    return 'zh';
  }

  const langParam = (url.searchParams.get('lang') || '').toLowerCase();
  if (langParam) {
    // 明确指定的 lang 参数优先级最高（仅次于 URL 路径）
    if (langParam.startsWith('zh')) {
      return 'zh';
    }
    if (langParam.startsWith('en')) {
      return 'en';
    }
  }

  const acceptLanguage = (headers.get('Accept-Language') || '').toLowerCase();
  if (acceptLanguage.split(',').some((token) => token.trim().startsWith('zh'))) {
    return 'zh';
  }

  return 'en';
}


export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return addCorsHeaders(handleOptionsRequest());
    }

    if (request.method === 'GET' && url.pathname === '/health') {
      return addCorsHeaders(await handleHealthCheck(env));
    }

    if (request.method === 'GET') {
      return addCorsHeaders(await handleGetRequest(request, env));
    } else if (request.method === 'POST') {
      return addCorsHeaders(await handlePostRequest(request, env, ctx));
    } else {
      return addCorsHeaders(new Response('Expected GET or POST', { status: 405 }));
    }
  },
};

// 错误码定义
const ERROR_CODES = {
  MISSING_SYSINFO: 'MISSING_SYSINFO',
  MISSING_PROMPT: 'MISSING_PROMPT',
  MISSING_API_KEY: 'MISSING_API_KEY',
  DEMO_LIMIT_EXCEEDED: 'DEMO_LIMIT_EXCEEDED',
  AI_API_ERROR: 'AI_API_ERROR',
  EMPTY_RESPONSE: 'EMPTY_RESPONSE',
  INVALID_RESPONSE: 'INVALID_RESPONSE',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  REQUEST_TOO_LARGE: 'REQUEST_TOO_LARGE',
};

// 请求体大小限制 (64KB)
const MAX_REQUEST_BODY_SIZE = 64 * 1024;

/**
 * 生成唯一请求追踪 ID
 * @returns {string} UUID v4 格式的请求 ID
 */
function generateRequestId() {
  return crypto.randomUUID();
}

/**
 * 使用 SHA-256 生成缓存 key
 * @param {string} prompt 用户提示词
 * @param {string} sysinfo 系统信息
 * @param {string} model AI 模型名称
 * @param {string} locale 语言环境 (en/zh)
 * @returns {Promise<string>} 十六进制 hash 字符串
 */
async function generateCacheKey(prompt, sysinfo, model, locale) {
  const input = `${model}:${locale}:${sysinfo}:${prompt}`;
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return `ai:${hashHex}`;
}

/**
 * 从缓存中获取 AI 响应
 * @param {string} cacheKey 缓存键
 * @param {object} env 环境变量
 * @returns {Promise<string|null>} 缓存的命令,不存在则返回 null
 */
async function getCachedResponse(cacheKey, env) {
  if (!env.AI_CACHE) {
    return null;
  }
  try {
    const cached = await env.AI_CACHE.get(cacheKey);
    return cached;
  } catch (error) {
    console.error('Cache read error:', error);
    return null;
  }
}

/**
 * 将 AI 响应写入缓存
 * @param {string} cacheKey 缓存键
 * @param {string} command 生成的命令
 * @param {object} env 环境变量
 * @returns {Promise<void>}
 */
async function setCachedResponse(cacheKey, command, env) {
  if (!env.AI_CACHE) {
    return;
  }
  try {
    // 缓存 24 小时 (86400 秒)
    await env.AI_CACHE.put(cacheKey, command, {
      expirationTtl: 86400,
    });
  } catch (error) {
    console.error('Cache write error:', error);
  }
}

/**
 * 获取缓存统计信息
 * @param {object} env 环境变量
 * @returns {Promise<object>} 缓存统计 {hits, misses, hitRate}
 */
async function getCacheStats(env) {
  if (!env.AI_CACHE) {
    return { enabled: false };
  }
  try {
    const today = new Date().toISOString().slice(0, 10);
    const hitsKey = `stats:hits:${today}`;
    const missesKey = `stats:misses:${today}`;

    // 并行读取 KV 以减少延迟 (Codex 优化建议)
    const [hitsValue, missesValue] = await Promise.all([
      env.AI_CACHE.get(hitsKey),
      env.AI_CACHE.get(missesKey)
    ]);
    const hits = parseInt(hitsValue || '0', 10);
    const misses = parseInt(missesValue || '0', 10);
    const total = hits + misses;
    const hitRate = total > 0 ? (hits / total * 100).toFixed(2) : '0.00';

    return {
      enabled: true,
      hits,
      misses,
      total,
      hitRate: `${hitRate}%`,
    };
  } catch (error) {
    console.error('Cache stats error:', error);
    return { enabled: true, error: error.message };
  }
}

/**
 * 增加缓存统计计数
 * @param {string} type 'hit' 或 'miss'
 * @param {object} env 环境变量
 * @returns {Promise<void>}
 */
async function incrementCacheStats(type, env) {
  if (!env.AI_CACHE) {
    return;
  }
  try {
    const today = new Date().toISOString().slice(0, 10);
    const key = `stats:${type}s:${today}`;
    const current = parseInt(await env.AI_CACHE.get(key) || '0', 10);
    await env.AI_CACHE.put(key, String(current + 1), {
      expirationTtl: 172800, // 48 小时,确保统计数据留存
    });
  } catch (error) {
    console.error('Cache stats increment error:', error);
  }
}

/**
 * 生成结构化错误响应
 * @param {string} code 错误码
 * @param {string} message 错误消息
 * @param {number} status HTTP 状态码
 * @param {object} extra 额外字段
 * @param {string} [requestId] 请求追踪 ID
 * @returns {Response}
 */
function createErrorResponse(code, message, status, extra = {}, requestId = null) {
  const payload = {
    error: code,
    message,
    timestamp: new Date().toISOString(),
    ...(requestId && { requestId }),
    ...extra,
  };
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };
  if (requestId) {
    headers['X-Request-ID'] = requestId;
  }
  return new Response(JSON.stringify(payload), { status, headers });
}

function handleOptionsRequest() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}

function addCorsHeaders(response) {
  const newHeaders = new Headers(response.headers);
  newHeaders.set('Access-Control-Allow-Origin', '*');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: newHeaders,
  });
}

/**
 * 健康检查端点处理函数
 * 返回服务状态、版本信息、依赖服务连接状态和当日调用统计
 * @param {object} env 环境变量
 * @returns {Promise<Response>} JSON 格式的健康状态响应
 */
async function handleHealthCheck(env) {
  const quotaStore = resolveQuotaStore(env);
  const stats = await getDailyStats(quotaStore);
  const cacheStats = await getCacheStats(env);

  const payload = {
    status: 'ok',
    version: '2.1.0',
    timestamp: new Date().toISOString(),
    services: {
      apiKey: Boolean(env?.OPENAI_API_KEY),
      adminKey: Boolean(env?.ADMIN_ACCESS_KEY),
      kvStorage: quotaStore !== null,
      aiCache: Boolean(env?.AI_CACHE),
    },
    config: {
      model: env?.OPENAI_API_MODEL || 'gpt-5-nano',
      sharedLimit: resolveSharedLimit(env),
    },
    stats: {
      totalCalls: stats.totalCalls,
      uniqueIPs: stats.uniqueIPs,
    },
    cache: cacheStats,
  };

  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

/**
 * Handles GET requests to serve the installer script from R2 or redirect browsers to GitHub.
 * @param {Request} request The incoming request.
 * @param {object} env The environment variables (including R2 bindings).
 * @returns {Promise<Response>} A promise that resolves to a response with the shell script or a redirect.
 */
async function handleGetRequest(request, env) {
  const userAgent = request.headers.get('User-Agent') || '';

  const url = new URL(request.url);
  const locale = resolveLocale(url, request.headers);
  const isBrowser = isBrowserRequest(userAgent);

  // If the request comes from a browser, redirect to the appropriate README.
  if (isBrowser) {
    const docsUrl = locale === 'zh' ? README_URL_ZH : README_URL_EN;
    return Response.redirect(docsUrl, 302);
  }

  // Serve the installer script from R2
  const scriptPath = locale === 'zh' ? 'zh/main.sh' : 'en/main.sh';
  const filename = locale === 'zh' ? INSTALLER_FILENAME_ZH : INSTALLER_FILENAME_EN;

  // 检查 R2 绑定是否存在
  if (!env.SCRIPTS_BUCKET) {
    console.error('R2 bucket binding (SCRIPTS_BUCKET) is not configured');
    return new Response(
      'Service temporarily unavailable: R2 storage not configured. Please contact the administrator.',
      {
        status: 503,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-store', // 不缓存配置错误
          'Retry-After': '300', // 5 分钟后重试
        },
      }
    );
  }

  try {
    // 从 R2 获取脚本
    const object = await env.SCRIPTS_BUCKET.get(scriptPath);

    if (!object) {
      // R2 中找不到脚本,返回 404
      console.warn(`Script not found in R2: ${scriptPath}`);
      return new Response(
        `Script not found: ${scriptPath}\nPlease ensure scripts are uploaded to R2 bucket.`,
        {
          status: 404,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-store', // 不缓存 404,避免修复后仍 404
          },
        }
      );
    }

    // 构建响应头
    const headers = {
      'Content-Type': 'text/plain; charset=utf-8',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Cache-Control': 'public, max-age=3600', // 缓存 1 小时
    };

    // 添加 ETag 支持 (如果 R2 对象提供)
    if (object.httpEtag) {
      headers['ETag'] = object.httpEtag;
    }

    return new Response(object.body, { headers });
  } catch (error) {
    console.error('Failed to fetch script from R2:', error);
    // 区分不同类型的错误
    const errorMessage = error.message || 'Unknown error';
    if (errorMessage.includes('permission') || errorMessage.includes('access')) {
      return new Response(
        'Service temporarily unavailable: R2 storage access denied. Please contact the administrator.',
        {
          status: 503,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-store',
            'Retry-After': '300',
          },
        }
      );
    }
    return new Response('Internal Server Error: Failed to retrieve installation script.', {
      status: 500,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
  }
}

/**
 * Handles POST requests by forwarding the prompt to an AI model.
 * @param {Request} request The incoming request.
 * @param {object} env The environment variables.
 * @param {ExecutionContext} ctx The execution context for waitUntil.
 * @returns {Promise<Response>} A promise that resolves to the AI's response.
 */
async function handlePostRequest(request, env, ctx) {
  // 生成请求追踪 ID
  const requestId = generateRequestId();

  // 请求体大小检查（在解析 JSON 之前）
  const contentLength = parseInt(request.headers.get('Content-Length') || '0', 10);
  if (contentLength > MAX_REQUEST_BODY_SIZE) {
    return createErrorResponse(
      ERROR_CODES.REQUEST_TOO_LARGE,
      `Request body too large: ${contentLength} bytes exceeds limit of ${MAX_REQUEST_BODY_SIZE} bytes`,
      413,
      {},
      requestId
    );
  }

  try {
    const { sysinfo, prompt, adminKey } = await request.json();

    // 验证 sysinfo
    if (!sysinfo || sysinfo.trim() === '') {
      return createErrorResponse(
        ERROR_CODES.MISSING_SYSINFO,
        'Missing or empty "sysinfo" in request body',
        400,
        {},
        requestId
      );
    }

    // 验证 prompt
    if (!prompt || prompt.trim() === '') {
      return createErrorResponse(
        ERROR_CODES.MISSING_PROMPT,
        'Missing or empty "prompt" in request body',
        400,
        {},
        requestId
      );
    }

    if (!env.OPENAI_API_KEY) {
      return createErrorResponse(
        ERROR_CODES.MISSING_API_KEY,
        'Server configuration error: missing API key',
        500,
        {},
        requestId
      );
    }

    const normalizedAdminKey = typeof adminKey === 'string' ? adminKey.trim() : '';
    const hasAdminBypass = Boolean(
      normalizedAdminKey && env?.ADMIN_ACCESS_KEY && timingSafeEqual(normalizedAdminKey, env.ADMIN_ACCESS_KEY),
    );

    const clientIp = request.headers.get('CF-Connecting-IP') ||
      request.headers.get('X-Forwarded-For') ||
      'anonymous';
    if (!hasAdminBypass) {
      const sharedLimit = resolveSharedLimit(env);
      const quota = await checkSharedQuota(clientIp, sharedLimit, env);

      // 配额消耗日志
      console.log(JSON.stringify({
        event: 'quota_check',
        requestId,
        clientIp: clientIp.substring(0, 8) + '***', // 脱敏处理
        allowed: quota.allowed,
        remaining: quota.remaining,
        limit: sharedLimit,
        timestamp: new Date().toISOString(),
      }));

      if (!quota.allowed) {
        return createErrorResponse(
          ERROR_CODES.DEMO_LIMIT_EXCEEDED,
          `Shared demo quota exceeded (max ${sharedLimit} calls per day).`,
          429,
          {
            hint: 'Configure FUCK_OPENAI_API_KEY in ~/.fuck/config.sh to use your own key.',
            remaining: quota.remaining,
            limit: sharedLimit,
          },
          requestId
        );
      }
    }

    const model = env.OPENAI_API_MODEL || 'gpt-5-nano';
    const apiBase = (env.OPENAI_API_BASE || 'https://api.openai.com/v1').replace(/\/$/, '');
    const apiUrl = `${apiBase}/chat/completions`;

    const url = new URL(request.url);
    const locale = resolveLocale(url, request.headers);
    const isChinese = locale === 'zh';

    // 🔍 缓存检查:尝试从缓存中获取响应
    const cacheKey = await generateCacheKey(prompt, sysinfo, model, locale);
    const cachedCommand = await getCachedResponse(cacheKey, env);

    if (cachedCommand) {
      // 缓存命中!直接返回缓存的命令
      // 使用 waitUntil 异步更新统计,不阻塞响应 (Codex 优化建议)
      ctx.waitUntil(incrementCacheStats('hit', env));
      console.log(JSON.stringify({
        event: 'cache_hit',
        requestId,
        cacheKey: cacheKey.substring(0, 16) + '...',
        timestamp: new Date().toISOString(),
      }));

      return new Response(cachedCommand, {
        headers: {
          'Content-Type': 'text/plain',
          'X-Request-ID': requestId,
          'X-Cache-Status': 'HIT',
        },
      });
    }

    // 缓存未命中,记录统计并继续调用 AI API
    // 使用 waitUntil 异步更新统计,不阻塞响应 (Codex 优化建议)
    ctx.waitUntil(incrementCacheStats('miss', env));
    console.log(JSON.stringify({
      event: 'cache_miss',
      requestId,
      cacheKey: cacheKey.substring(0, 16) + '...',
      timestamp: new Date().toISOString(),
    }));

    const system_prompt = isChinese
      ? `你是一个专业的 shell 命令生成器。用户会用自然语言描述他们想要完成的任务。你的任务是生成直接可执行的 shell 命令来完成用户的目标。

重要规则：
1. 用户输入是自然语言描述意图，不是命令参数。例如"列出目录"意思是执行 ls 命令，而不是 ls "列出目录"
2. 生成直接可执行的命令，不要生成带参数判断的脚本模板（如 if [ $# -eq 0 ]）
3. 对于简单任务直接返回单条命令，复杂任务可以是多行脚本
4. 不要提供任何解释、注释、markdown 格式（比如 \`\`\`bash）或 shebang（例如 #!/bin/bash）

示例：
- 用户说"列出目录" → 输出: ls
- 用户说"显示详细文件列表" → 输出: ls -la
- 用户说"查找大于10MB的文件" → 输出: find . -type f -size +10M

用户的系统信息是：${sysinfo}`
      : `You are an expert shell command generator. Users describe tasks in natural language. Your task is to generate directly executable shell commands to accomplish their goals.

Important rules:
1. User input is natural language intent, NOT command arguments. For example, "list directory" means run ls, not ls "list directory"
2. Generate directly executable commands, not script templates with parameter handling (like if [ $# -eq 0 ])
3. For simple tasks return single commands, complex tasks can be multi-line scripts
4. Do not provide any explanation, comments, markdown formatting (like \`\`\`bash), or a shebang (e.g., #!/bin/bash)

Examples:
- User says "list directory" → Output: ls
- User says "show detailed file list" → Output: ls -la
- User says "find files larger than 10MB" → Output: find . -type f -size +10M

The user's system info is: ${sysinfo}`;

    const aiRequestPayload = {
      model: model,
      messages: [
        {
          role: 'system',
          content: system_prompt,
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      max_tokens: 1024,
      temperature: 0.2,
    };

    const aiResponse = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify(aiRequestPayload),
    });

    if (!aiResponse.ok) {
      const errorText = await aiResponse.text();
      // 统一返回 500 状态码，提供友好的错误消息
      let friendlyMessage = 'AI service is temporarily unavailable. Please try again later.';

      // 根据 OpenAI 错误状态码提供更具体的友好提示
      if (aiResponse.status === 401) {
        friendlyMessage = 'AI API authentication failed. Please check your API key configuration.';
      } else if (aiResponse.status === 429) {
        friendlyMessage = 'AI service rate limit exceeded. Please try again in a few moments.';
      } else if (aiResponse.status === 503) {
        friendlyMessage = 'AI service is temporarily overloaded. Please try again later.';
      }

      return createErrorResponse(
        ERROR_CODES.AI_API_ERROR,
        friendlyMessage,
        500, // 统一返回 500 而非透传原始状态码
        { originalStatus: aiResponse.status, details: errorText },
        requestId
      );
    }

    const aiJson = await aiResponse.json();
    const command = aiJson.choices[0]?.message?.content.trim();

    if (!command) {
      return createErrorResponse(
        ERROR_CODES.EMPTY_RESPONSE,
        'The AI returned an empty command.',
        500,
        {},
        requestId
      );
    }

    // 清理 AI 返回的命令(移除 markdown 格式、shebang 等)
    const cleanedCommand = sanitizeCommand(command);

    if (!cleanedCommand) {
      return createErrorResponse(
        ERROR_CODES.INVALID_RESPONSE,
        'The AI returned an invalid command after sanitization.',
        500,
        {},
        requestId
      );
    }

    // 💾 将成功的响应存入缓存
    // 使用 waitUntil 异步写入缓存,不阻塞响应返回 (Codex 优化建议)
    if (env.AI_CACHE) {
      ctx.waitUntil(setCachedResponse(cacheKey, cleanedCommand, env));
    }

    // 构建响应头
    const responseHeaders = {
      'Content-Type': 'text/plain',
      'X-Request-ID': requestId,
    };

    // 只有在缓存可用时才添加缓存状态头
    if (env.AI_CACHE) {
      responseHeaders['X-Cache-Status'] = 'MISS';
    }

    return new Response(cleanedCommand, { headers: responseHeaders });
  } catch (error) {
    return createErrorResponse(
      ERROR_CODES.INTERNAL_ERROR,
      `Internal server error: ${error.message}`,
      500,
      {},
      requestId
    );
  }
}
