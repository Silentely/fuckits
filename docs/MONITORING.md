# fuckits Monitoring & Observability

This document outlines monitoring strategies and observability practices for the fuckits project.

---

## Table of Contents

- [Overview](#overview)
- [Health Checks](#health-checks)
- [Metrics Collection](#metrics-collection)
- [Logging](#logging)
- [Alerting](#alerting)
- [Dashboards](#dashboards)
- [Incident Response](#incident-response)

---

## Overview

fuckits uses a multi-layered monitoring approach:

1. **Application Health**: `/health` endpoint for uptime monitoring
2. **Cloudflare Analytics**: Built-in Worker analytics
3. **Custom Metrics**: Quota usage, error rates, response times
4. **Audit Logs**: Client-side command execution tracking
5. **External Monitoring**: Third-party uptime monitors

---

## Health Checks

### Endpoint: GET /health

**Response Example:**
```json
{
  "status": "ok",
  "version": "2.1.0",
  "timestamp": "2025-01-27T12:00:00.000Z",
  "services": {
    "apiKey": true,
    "adminKey": false,
    "kvStorage": true,
    "aiCache": true
  },
  "config": {
    "model": "gpt-5-nano",
    "sharedLimit": 10
  },
  "stats": {
    "totalCalls": 42,
    "uniqueIPs": 15
  },
  "cache": {
    "enabled": true,
    "hits": 156,
    "misses": 42,
    "total": 198,
    "hitRate": "78.79%"
  }
}
```

**Fields Explained:**
- `status`: Worker running state ("ok")
- `version`: Current version number
- `timestamp`: Server UTC time
- `services`: Dependency status
  - `apiKey`: OpenAI API key configured
  - `adminKey`: Admin bypass key configured
  - `kvStorage`: KV storage available for quota persistence
  - `aiCache`: KV storage available for AI response caching (new in v2.1.0)
- `config`: Runtime configuration
  - `model`: AI model in use
  - `sharedLimit`: Daily demo quota limit
- `stats`: Daily usage statistics (excludes admin bypass requests)
  - `totalCalls`: Total API calls today (non-admin only)
  - `uniqueIPs`: Unique client IPs today (non-admin only)
- `cache`: AI response cache performance (new in v2.1.0)
  - `enabled`: Whether AI_CACHE KV namespace is configured
  - `hits`: Requests served from cache (response time ~50-100ms)
  - `misses`: Requests requiring AI API call (response time ~2000-3000ms)
  - `total`: Total requests today (hits + misses)
  - `hitRate`: Percentage of requests served from cache

> **Note:** Requests using `adminKey` bypass the quota system and are **not** counted in `stats`. This is by design—admin users do not consume shared quota.

**Monitoring Checks:**

```bash
# Basic availability check
curl -f https://fuckits.25500552.xyz/health || echo "DOWN"

# Check API key configuration
curl -s https://fuckits.25500552.xyz/health | jq -r '.services.apiKey'

# Check KV storage status
curl -s https://fuckits.25500552.xyz/health | jq -r '.services.kvStorage'

# Check AI cache status (new in v2.1.0)
curl -s https://fuckits.25500552.xyz/health | jq -r '.services.aiCache'

# Monitor cache performance
curl -s https://fuckits.25500552.xyz/health | jq '.cache'

# Check cache hit rate
curl -s https://fuckits.25500552.xyz/health | jq -r '.cache.hitRate'

# Check daily usage stats
curl -s https://fuckits.25500552.xyz/health | jq '.stats'

# Monitor response time
time curl -s https://fuckits.25500552.xyz/health

# Full health status
curl -s https://fuckits.25500552.xyz/health | jq '.'
```

### Recommended Monitoring Tools

**Free Options:**
- [UptimeRobot](https://uptimerobot.com/) - 5-minute intervals
- [StatusCake](https://www.statuscake.com/) - Free tier available
- [Better Uptime](https://betteruptime.com/) - Status pages + monitoring

**Configuration Example (UptimeRobot):**
- **Monitor Type**: HTTP(s)
- **URL**: `https://fuckits.25500552.xyz/health`
- **Keyword**: `"status":"ok"`
- **Interval**: 5 minutes
- **Alert Contacts**: Email, Slack, Discord
- **Advanced Check**: Verify `services.apiKey` is `true`

---

## Metrics Collection

### Cloudflare Workers Analytics

Access via Cloudflare Dashboard → Workers → fuckits → Metrics

**Key Metrics:**
- **Requests**: Total requests over time
- **Errors**: 4xx and 5xx error rates
- **Duration**: P50, P75, P99 response times
- **CPU Time**: Execution time per request

### Custom Metrics (Future Enhancement)

For advanced monitoring, consider implementing:

```javascript
// In worker.js
async function trackMetric(env, metric, value) {
  // Option 1: Cloudflare Analytics Engine (paid)
  // await env.ANALYTICS.writeDataPoint({
  //   blobs: [metric],
  //   doubles: [value],
  //   indexes: [new Date().toISOString().slice(0, 10)]
  // });
  
  // Option 2: Send to external service
  // await fetch('https://metrics.example.com/api/v1/metrics', {
  //   method: 'POST',
  //   body: JSON.stringify({ metric, value, timestamp: Date.now() })
  // });
}

// Usage
await trackMetric(env, 'quota_exceeded', 1);
await trackMetric(env, 'command_generated', 1);
await trackMetric(env, 'response_time_ms', duration);
```

---

## Logging

### Worker Logs

**View Real-Time Logs:**
```bash
# Via wrangler CLI
npx wrangler tail

# Filter for errors only
npx wrangler tail --format pretty | grep ERROR
```

**Production Logging Strategy:**

```javascript
// Structured logging in worker.js
function log(level, message, metadata = {}) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...metadata
  };
  
  if (level === 'ERROR') {
    console.error(JSON.stringify(logEntry));
  } else {
    console.log(JSON.stringify(logEntry));
  }
}

// Usage
log('INFO', 'Command generated successfully', { 
  ip: clientIP, 
  model: env.OPENAI_API_MODEL 
});

log('ERROR', 'OpenAI API failure', { 
  statusCode: response.status, 
  error: errorMessage 
});
```

### Client-Side Audit Logs

**Enable in Configuration:**
```bash
# In ~/.fuck/config.sh
export FUCK_AUDIT_LOG=true
export FUCK_AUDIT_LOG_FILE="$HOME/.fuck/.audit.log"
```

**Log Format:**
```
timestamp|user|event|exit_code|command
```

**Example Entries:**
```
2025-01-25 12:00:00 UTC|alice|EXEC|0|docker ps -a
2025-01-25 12:01:15 UTC|alice|BLOCK|-|rm -rf /
2025-01-25 12:02:30 UTC|bob|ABORT|-|sudo systemctl restart nginx
```

**Analysis Queries:**
```bash
# Count blocked commands
grep "|BLOCK|" ~/.fuck/.audit.log | wc -l

# Find failed executions
awk -F'|' '$4 != "0" && $4 != "-" {print $0}' ~/.fuck/.audit.log

# Most common commands
awk -F'|' '{print $5}' ~/.fuck/.audit.log | sort | uniq -c | sort -rn | head -10
```

---

## Alerting

### Recommended Alerts

**Critical (Immediate Response):**

1. **Health Check Failure**
   - Condition: `/health` returns non-200 or missing `"status":"ok"`
   - Action: Page on-call engineer
   - Channels: SMS, Phone call

2. **High Error Rate**
   - Condition: 5xx errors > 5% of requests over 5 minutes
   - Action: Create incident, notify team
   - Channels: Slack, Email

3. **API Key Missing**
   - Condition: `services.apiKey: false` in health check
   - Action: Immediate investigation
   - Channels: Slack, Email

**Warning (Review Within Hours):**

1. **Elevated 4xx Rate**
   - Condition: 4xx errors > 10% of requests over 15 minutes
   - Action: Review logs, investigate client issues

2. **Slow Response Times**
   - Condition: P99 latency > 5 seconds over 10 minutes
   - Action: Check OpenAI API status, Worker performance

3. **Quota System Anomalies**
   - Condition: Unusual spike in quota exceeded responses
   - Action: Review for potential abuse or misconfiguration

**Info (Daily Review):**

1. **Daily Usage Report**
   - Condition: Daily at 09:00 UTC
   - Content: Total requests, error rate, top users (by IP)

2. **Deployment Success/Failure**
   - Condition: After each deployment
   - Content: Deployment status, test results

### Alert Configuration Example (Better Uptime)

```yaml
# Example configuration
monitors:
  - name: "fuckits Health Check"
    url: "https://fuckits.25500552.xyz/health"
    interval: 300  # 5 minutes
    expected_status: 200
    expected_body: '{"status":"ok"}'
    alert_channels:
      - type: slack
        webhook: $SLACK_WEBHOOK_URL
      - type: email
        address: alerts@example.com

  - name: "fuckits Main Endpoint"
    url: "https://fuckits.25500552.xyz"
    interval: 600  # 10 minutes
    expected_status: 200
```

---

## Dashboards

### Cloudflare Dashboard

**Default Metrics:**
- Request volume (timeline graph)
- Error rate (4xx/5xx breakdown)
- Response time percentiles
- Geographic distribution
- Top paths

**Access:** Cloudflare Dashboard → Workers → fuckits → Metrics

### Custom Dashboard (Grafana/Datadog - Optional)

If using external metrics collection:

**Key Panels:**

1. **Requests Overview**
   - Total requests (gauge)
   - Requests/min (graph)
   - Success rate (gauge)

2. **Performance**
   - P50/P95/P99 latency (graph)
   - Worker CPU time (graph)
   - OpenAI API response time (graph)

3. **Quota System**
   - Daily quota usage (bar chart)
   - Quota exceeded rate (graph)
   - Unique IPs per day (counter)

4. **Errors**
   - Error rate by type (pie chart)
   - Recent errors (table)
   - Error trends (graph)

**Example PromQL Queries (if using Prometheus):**

```promql
# Request rate
rate(fuckits_requests_total[5m])

# Error percentage
(rate(fuckits_requests_total{status=~"5.."}[5m]) / 
 rate(fuckits_requests_total[5m])) * 100

# P99 latency
histogram_quantile(0.99, 
  rate(fuckits_request_duration_seconds_bucket[5m]))
```

---

## Incident Response

### Incident Severity Levels

**P0 (Critical - Respond Immediately):**
- Complete service outage
- Data breach or security incident
- API keys exposed

**P1 (High - Respond Within 1 Hour):**
- Partial outage (>50% errors)
- Significant performance degradation
- Quota system failure

**P2 (Medium - Respond Within 4 Hours):**
- Elevated error rates (<50%)
- Non-critical feature broken
- Quota exceeded for legitimate users

**P3 (Low - Respond Within 24 Hours):**
- Minor bugs
- Documentation issues
- Non-urgent feature requests

### Incident Response Playbook

**Step 1: Detect & Acknowledge (0-5 minutes)**
- Alert fires
- On-call engineer acknowledges
- Initial assessment of impact

**Step 2: Investigate (5-15 minutes)**
```bash
# Check Worker health
curl https://fuckits.25500552.xyz/health

# Check Cloudflare status
curl https://www.cloudflarestatus.com/api/v2/status.json

# Check OpenAI status
curl https://status.openai.com/api/v2/status.json

# View recent logs
npx wrangler tail --format pretty | head -100

# Check recent deployments
git log --oneline -10
```

**Step 3: Mitigate (15-30 minutes)**

- **If Worker is down**: Check Cloudflare dashboard for errors
- **If API errors**: Verify `OPENAI_API_KEY` is set and valid
- **If quota issues**: Temporarily increase `SHARED_DAILY_LIMIT`
- **If bad deployment**: Trigger rollback workflow

```bash
# Manual rollback via GitHub Actions
# Go to: Actions → Rollback Deployment → Run workflow
# Input: reason="Prod outage - reverting bad deploy"
```

**Step 4: Communicate (Ongoing)**
- Update status page (if available)
- Post in team Slack/Discord
- Create GitHub issue for tracking

**Step 5: Resolve & Document (Post-Incident)**
- Root cause analysis
- Create postmortem document
- Update runbooks
- Implement preventive measures

### Rollback Procedure

**Automated (Recommended):**
```bash
# Via GitHub Actions
# 1. Go to: .github/workflows/rollback.yml
# 2. Click "Run workflow"
# 3. Enter reason and target deployment
# 4. Confirm execution
```

**Manual (Emergency):**
```bash
# 1. Checkout previous stable version
git checkout <previous-stable-commit>

# 2. Build and deploy
npm run build
npx wrangler deploy --env production

# 3. Verify health
curl https://fuckits.25500552.xyz/health
```

---

## Quick Reference

### Common Monitoring Commands

```bash
# Health check
curl -s https://fuckits.25500552.xyz/health | jq

# Response time test
time curl -s https://fuckits.25500552.xyz/health

# Test POST endpoint
curl -X POST https://fuckits.25500552.xyz \
  -H "Content-Type: application/json" \
  -d '{"sysinfo":"OS=Linux","prompt":"test"}'

# View Worker logs
npx wrangler tail

# Check deployment status
git log --oneline -5
```

### Key Metrics Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Availability | <99.5% | <99% |
| Error Rate (5xx) | >1% | >5% |
| P99 Latency | >3s | >10s |
| Health Check | Fails 1x | Fails 3x |
| Quota Exceeded Rate | >20% | >50% |

---

## Related Documentation

- [API Documentation](./API.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
- [Contributing Guide](../CONTRIBUTING.md)

---

**Last Updated**: 2025-01-27
**Maintainer**: faithleysath
