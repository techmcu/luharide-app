const { isRedisEnabled, getRedisClient } = require('../config/redis');

const METRICS_KEY = 'luha:metrics';
const METRICS_WINDOW = 2000;

const local = {
  startedAt: Date.now(),
  requests: 0,
  status2xx: 0,
  status4xx: 0,
  status5xx: 0,
  latenciesMs: [],
};

function recordMiddleware() {
  return (req, res, next) => {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - start) / 1e6;
      local.requests += 1;
      if (res.statusCode >= 500) local.status5xx += 1;
      else if (res.statusCode >= 400) local.status4xx += 1;
      else if (res.statusCode >= 200) local.status2xx += 1;
      local.latenciesMs.push(ms);
      if (local.latenciesMs.length > METRICS_WINDOW) {
        local.latenciesMs.shift();
      }

      if (isRedisEnabled()) {
        const client = getRedisClient();
        if (client) {
          const bucket =
            res.statusCode >= 500 ? 'status5xx' :
            res.statusCode >= 400 ? 'status4xx' : 'status2xx';
          client.pipeline()
            .hincrby(METRICS_KEY, 'requests', 1)
            .hincrby(METRICS_KEY, bucket, 1)
            .exec()
            .catch(() => {});
        }
      }
    });
    next();
  };
}

function percentile(sortedValues, p) {
  if (!sortedValues.length) return 0;
  const idx = Math.ceil((p / 100) * sortedValues.length) - 1;
  return sortedValues[Math.max(0, Math.min(sortedValues.length - 1, idx))];
}

async function getMetrics(serviceName, pool) {
  const workerId = process.env.NODE_APP_INSTANCE || '0';
  let counters = {
    requests: local.requests,
    status2xx: local.status2xx,
    status4xx: local.status4xx,
    status5xx: local.status5xx,
  };
  let aggregated = false;

  if (isRedisEnabled()) {
    const client = getRedisClient();
    if (client) {
      try {
        const all = await client.hgetall(METRICS_KEY);
        if (all && all.requests) {
          counters = {
            requests: parseInt(all.requests, 10) || 0,
            status2xx: parseInt(all.status2xx, 10) || 0,
            status4xx: parseInt(all.status4xx, 10) || 0,
            status5xx: parseInt(all.status5xx, 10) || 0,
          };
          aggregated = true;
        }
      } catch (_) {}
    }
  }

  const sorted = [...local.latenciesMs].sort((a, b) => a - b);
  const os = require('os');
  const mem = process.memoryUsage();
  const uptimeSec = Math.floor(process.uptime());
  const total = counters.requests || 1;

  return {
    ok: true,
    service: serviceName,
    worker_id: workerId,
    aggregated,
    uptime_sec: uptimeSec,
    requests_total: counters.requests,
    status_2xx: counters.status2xx,
    status_4xx: counters.status4xx,
    status_5xx: counters.status5xx,
    error_rate_5xx_pct: Number(((counters.status5xx / total) * 100).toFixed(2)),
    latency_ms: {
      p50: Number(percentile(sorted, 50).toFixed(2)),
      p95: Number(percentile(sorted, 95).toFixed(2)),
      p99: Number(percentile(sorted, 99).toFixed(2)),
      sample_size: sorted.length,
      note: aggregated ? 'latency from this worker only' : undefined,
    },
    memory_mb: {
      rss: Number((mem.rss / 1024 / 1024).toFixed(2)),
      heap_used: Number((mem.heapUsed / 1024 / 1024).toFixed(2)),
      heap_total: Number((mem.heapTotal / 1024 / 1024).toFixed(2)),
    },
    cpu: {
      loadavg: os.loadavg(),
      cores: os.cpus().length,
    },
    db_pool: pool ? {
      total: pool.totalCount,
      idle: pool.idleCount,
      waiting: pool.waitingCount,
    } : undefined,
    metrics_started_at: new Date(local.startedAt).toISOString(),
  };
}

module.exports = { recordMiddleware, getMetrics };
