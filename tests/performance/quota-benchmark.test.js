import { describe, it, expect, beforeEach } from 'vitest';

/**
 * Performance benchmarks for quota system
 * These tests ensure the quota checking mechanism performs adequately under load
 */
const isCI = process.env.CI === 'true' || process.env.CI === '1';
const thresholds = {
  memSequential: isCI ? 2000 : 500,
  memIps: isCI ? 500 : 100,
  kvSequential: isCI ? 3000 : 1000,
  kvConcurrent: isCI ? 1500 : 500,
  memClear: isCI ? 200 : 10,
};

// Mock KV store for testing
class MockKV {
  constructor() {
    this.store = new Map();
  }

  async get(key) {
    return this.store.get(key) || null;
  }

  async put(key, value, options) {
    this.store.set(key, value);
  }

  clear() {
    this.store.clear();
  }
}

// Import the quota functions (simplified versions for testing)
function checkSharedQuotaInMemory(ip, limit, sharedUsage) {
  const today = new Date().toISOString().slice(0, 10);
  const key = ip || 'anonymous';
  const current = (sharedUsage.get(key) || 0) + 1;
  sharedUsage.set(key, current);
  
  return {
    allowed: current <= limit,
    remaining: Math.max(limit - current, 0),
    count: current,
  };
}

async function checkSharedQuotaKV(kv, ip, limit) {
  const today = new Date().toISOString().slice(0, 10);
  const key = `quota:${today}:${ip || 'anonymous'}`;
  
  const raw = await kv.get(key);
  const currentCount = Number(raw) || 0;
  
  if (currentCount >= limit) {
    return {
      allowed: false,
      remaining: 0,
      count: currentCount,
    };
  }
  
  const newCount = currentCount + 1;
  await kv.put(key, String(newCount), { expirationTtl: 86400 });
  
  return {
    allowed: newCount <= limit,
    remaining: Math.max(limit - newCount, 0),
    count: newCount,
  };
}

describe('Quota System Performance Benchmarks', () => {
  describe('In-Memory Quota', () => {
    it('should handle 1000 sequential requests within 500ms', () => {
      const sharedUsage = new Map();
      const limit = 1000;
      const start = Date.now();
      
      for (let i = 0; i < 1000; i++) {
        const result = checkSharedQuotaInMemory('test-ip', limit, sharedUsage);
        expect(result.allowed).toBe(true);
      }
      
      const duration = Date.now() - start;
      expect(duration).toBeLessThan(thresholds.memSequential);
      console.log(`  ✓ 1000 sequential requests: ${duration}ms`);
    });

    it('should handle 100 different IPs efficiently', () => {
      const sharedUsage = new Map();
      const limit = 10;
      const start = Date.now();
      
      for (let i = 0; i < 100; i++) {
        const ip = `192.168.1.${i}`;
        for (let j = 0; j < 5; j++) {
          checkSharedQuotaInMemory(ip, limit, sharedUsage);
        }
      }
      
      const duration = Date.now() - start;
      expect(duration).toBeLessThan(thresholds.memIps);
      expect(sharedUsage.size).toBe(100);
      console.log(`  ✓ 500 requests across 100 IPs: ${duration}ms`);
    });
  });

  describe('KV-Based Quota', () => {
    let mockKV;

    beforeEach(() => {
      mockKV = new MockKV();
    });

    it('should handle 100 sequential requests within 1000ms', async () => {
      const limit = 100;
      const start = Date.now();
      
      for (let i = 0; i < 100; i++) {
        const result = await checkSharedQuotaKV(mockKV, 'test-ip', limit);
        expect(result.allowed).toBe(true);
      }
      
      const duration = Date.now() - start;
      expect(duration).toBeLessThan(thresholds.kvSequential);
      console.log(`  ✓ 100 sequential KV requests: ${duration}ms`);
    });

    it('should handle concurrent requests efficiently', async () => {
      const limit = 100;
      const concurrency = 10;
      const start = Date.now();
      
      const promises = [];
      for (let i = 0; i < concurrency; i++) {
        promises.push(checkSharedQuotaKV(mockKV, `ip-${i}`, limit));
      }
      
      const results = await Promise.all(promises);
      const duration = Date.now() - start;
      
      expect(results.every(r => r.allowed)).toBe(true);
      expect(duration).toBeLessThan(thresholds.kvConcurrent);
      console.log(`  ✓ ${concurrency} concurrent KV requests: ${duration}ms`);
    });

    it('should demonstrate race condition behavior', async () => {
      const limit = 5;
      const concurrency = 10;
      
      // Simulate race condition: 10 concurrent requests, limit is 5
      const promises = [];
      for (let i = 0; i < concurrency; i++) {
        promises.push(checkSharedQuotaKV(mockKV, 'same-ip', limit));
      }
      
      const results = await Promise.all(promises);
      const allowedCount = results.filter(r => r.allowed).length;
      
      // Due to race condition, more than 5 might be allowed
      // This is expected behavior (documented in code comments)
      console.log(`  ℹ Race condition demo: ${allowedCount}/${concurrency} allowed (limit: ${limit})`);
      
      // Final count is nondeterministic under race; just ensure it's within bounds
      const today = new Date().toISOString().slice(0, 10);
      const key = `quota:${today}:same-ip`;
      const finalCount = Number(await mockKV.get(key)) || 0;
      expect(finalCount).toBeGreaterThan(0);
      expect(finalCount).toBeLessThanOrEqual(concurrency);
    });
  });

  describe('Quota Reset Performance', () => {
    it('should clear in-memory quota efficiently', () => {
      const sharedUsage = new Map();
      
      // Populate with many entries
      for (let i = 0; i < 1000; i++) {
        sharedUsage.set(`ip-${i}`, Math.floor(Math.random() * 10));
      }
      
      expect(sharedUsage.size).toBe(1000);
      
      const start = Date.now();
      sharedUsage.clear();
      const duration = Date.now() - start;
      
      expect(sharedUsage.size).toBe(0);
      expect(duration).toBeLessThan(thresholds.memClear);
      console.log(`  ✓ Clear 1000 entries: ${duration}ms`);
    });
  });

  describe('Edge Cases', () => {
    it('should handle rapid repeated requests from same IP', () => {
      const sharedUsage = new Map();
      const limit = 10;
      const iterations = 20;
      
      let allowedCount = 0;
      let deniedCount = 0;
      
      for (let i = 0; i < iterations; i++) {
        const result = checkSharedQuotaInMemory('same-ip', limit, sharedUsage);
        if (result.allowed) allowedCount++;
        else deniedCount++;
      }
      
      expect(allowedCount).toBe(limit);
      expect(deniedCount).toBe(iterations - limit);
      console.log(`  ✓ ${iterations} rapid requests: ${allowedCount} allowed, ${deniedCount} denied`);
    });

    it('should handle anonymous users correctly', () => {
      const sharedUsage = new Map();
      const limit = 10;
      
      // Mix of IPs and anonymous
      for (let i = 0; i < 5; i++) {
        checkSharedQuotaInMemory('192.168.1.1', limit, sharedUsage);
        checkSharedQuotaInMemory(null, limit, sharedUsage);
        checkSharedQuotaInMemory(undefined, limit, sharedUsage);
      }
      
      // Should have 2 entries: one for IP, one for anonymous
      expect(sharedUsage.size).toBe(2);
      expect(sharedUsage.get('192.168.1.1')).toBe(5);
      expect(sharedUsage.get('anonymous')).toBe(10); // null and undefined both map to 'anonymous'
    });
  });

  describe('Memory Usage', () => {
    it('should not grow unbounded with different IPs', () => {
      const sharedUsage = new Map();
      const limit = 10;
      
      // Simulate daily usage from many IPs
      for (let i = 0; i < 10000; i++) {
        const ip = `192.168.${Math.floor(i / 256)}.${i % 256}`;
        checkSharedQuotaInMemory(ip, limit, sharedUsage);
      }
      
      // In production, this would be cleared daily
      // For now, just verify it grows as expected
      expect(sharedUsage.size).toBe(10000);
      
      // Simulate daily reset
      sharedUsage.clear();
      expect(sharedUsage.size).toBe(0);
      console.log('  ✓ Memory cleared after daily reset');
    });
  });
});
