/**
 * LuhaRide API Gateway — single public port; proxies to microservices.
 * Preserves all /api/* paths (Flutter & clients unchanged).
 *
 * Run after: auth (3001), core (3002), union (3003), platform (3004)
 * Env: AUTH_URL, CORE_URL, UNION_URL, PLATFORM_URL (defaults below)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-gateway';
const path = require('path');
const os = require('os');
const http = require('http');
const express = require('express');
const compression = require('compression');
const { createHelmetMiddleware } = require('../src/config/helmetConfig');
const { applyLuhaCors, applyCorsHeadersOnError } = require('../src/middleware/corsLuha');
const morgan = require('morgan');
const { createProxyMiddleware } = require('http-proxy-middleware');
const socketIo = require('socket.io');

const { pool } = require('../src/config/database');
const { apiLimiter } = require('../src/middleware/rateLimiter');
const { attachSocketIoRedisAdapter } = require('../src/socket/socketRedisAdapter');
const attachSocketHandlers = require('../src/socket/socketHandlers');
const { setIo } = require('../src/socket/socketIoRegistry');
const { requestContext } = require('../src/middleware/requestContext');
const logger = require('../src/config/logger');
const { applyTrustProxy, shouldWarnTrustProxyUnsetInProduction } = require('../src/config/trustProxy');

const AUTH_URL = process.env.AUTH_URL || 'http://127.0.0.1:3001';
const CORE_URL = process.env.CORE_URL || 'http://127.0.0.1:3002';
const UNION_URL = process.env.UNION_URL || 'http://127.0.0.1:3003';
const PLATFORM_URL = process.env.PLATFORM_URL || 'http://127.0.0.1:3004';

function checkUpstreamHealth(baseUrl, timeoutMs = 2500) {
  return new Promise((resolve) => {
    let settled = false;
    const done = (payload) => {
      if (settled) return;
      settled = true;
      resolve(payload);
    };

    try {
      const target = new URL('/health', baseUrl);
      const req = http.get(target, (resp) => {
        let body = '';
        resp.on('data', (chunk) => {
          body += chunk;
        });
        resp.on('end', () => {
          done({
            ok: resp.statusCode >= 200 && resp.statusCode < 300,
            status: resp.statusCode,
            body: body.slice(0, 300),
          });
        });
      });
      req.on('error', (e) => done({ ok: false, error: e.message }));
      req.setTimeout(timeoutMs, () => {
        req.destroy(new Error('timeout'));
      });
    } catch (e) {
      done({ ok: false, error: e.message });
    }
  });
}

const app = express();
applyTrustProxy(app);

const METRICS_WINDOW = 2000;
const metrics = {
  startedAt: Date.now(),
  requests: 0,
  status2xx: 0,
  status4xx: 0,
  status5xx: 0,
  latenciesMs: [],
};

function percentile(sortedValues, p) {
  if (!sortedValues.length) return 0;
  const idx = Math.ceil((p / 100) * sortedValues.length) - 1;
  return sortedValues[Math.max(0, Math.min(sortedValues.length - 1, idx))];
}

app.use(createHelmetMiddleware());
app.use(requestContext);
app.use(compression());
applyLuhaCors(app);
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    metrics.requests += 1;
    if (res.statusCode >= 500) metrics.status5xx += 1;
    else if (res.statusCode >= 400) metrics.status4xx += 1;
    else if (res.statusCode >= 200) metrics.status2xx += 1;
    metrics.latenciesMs.push(ms);
    if (metrics.latenciesMs.length > METRICS_WINDOW) {
      metrics.latenciesMs.shift();
    }
  });
  next();
});
morgan.token('reqId', (req) => req.id || '-');
app.use(morgan(':reqId :method :url :status :response-time ms'));

app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'ok',
      role: 'gateway',
      timestamp: new Date().toISOString(),
      database: 'connected',
    });
  } catch (error) {
    res.status(503).json({ status: 'error', message: error.message });
  }
});

app.get('/', (req, res) => {
  res.json({
    message: 'LuhaRide API Gateway',
    version: '1.0.0',
    mode: 'microservices',
  });
});

app.get('/api', (req, res) => {
  res.json({
    ok: true,
    message: 'LuhaRide API (gateway)',
    version: '1.0.0',
    search: 'GET /api/trips/search?from=Dehradun&to=Purola&date=2026-02-23',
  });
});

app.get('/api/health', (req, res) => {
  res.status(200).json({ ok: true, status: 'running', via: 'gateway' });
});

app.get('/api/health/upstreams', async (req, res) => {
  const checks = await Promise.all([
    checkUpstreamHealth(AUTH_URL),
    checkUpstreamHealth(CORE_URL),
    checkUpstreamHealth(UNION_URL),
    checkUpstreamHealth(PLATFORM_URL),
  ]);

  const data = {
    auth: { target: AUTH_URL, ...checks[0] },
    core: { target: CORE_URL, ...checks[1] },
    union: { target: UNION_URL, ...checks[2] },
    platform: { target: PLATFORM_URL, ...checks[3] },
  };
  const allOk = checks.every((c) => c.ok);
  res.status(allOk ? 200 : 503).json({
    ok: allOk,
    via: 'gateway',
    upstreams: data,
  });
});

app.get('/health/metrics', (req, res) => {
  const sorted = [...metrics.latenciesMs].sort((a, b) => a - b);
  const mem = process.memoryUsage();
  const uptimeSec = Math.floor(process.uptime());
  const total = metrics.requests || 1;
  res.status(200).json({
    ok: true,
    service: 'gateway',
    uptime_sec: uptimeSec,
    requests_total: metrics.requests,
    status_2xx: metrics.status2xx,
    status_4xx: metrics.status4xx,
    status_5xx: metrics.status5xx,
    error_rate_5xx_pct: Number(((metrics.status5xx / total) * 100).toFixed(2)),
    latency_ms: {
      p50: Number(percentile(sorted, 50).toFixed(2)),
      p95: Number(percentile(sorted, 95).toFixed(2)),
      p99: Number(percentile(sorted, 99).toFixed(2)),
      sample_size: sorted.length,
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
    db_pool: {
      total: pool.totalCount,
      idle: pool.idleCount,
      waiting: pool.waitingCount,
    },
    metrics_started_at: new Date(metrics.startedAt).toISOString(),
  });
});

const _proxyTimeoutMs = Math.max(
  5000,
  parseInt(process.env.GATEWAY_PROXY_TIMEOUT_MS || '120000', 10) || 120000
);

const proxyOpts = (target) => ({
  target,
  changeOrigin: true,
  timeout: _proxyTimeoutMs,
  logLevel: process.env.GATEWAY_PROXY_LOG === 'debug' ? 'debug' : 'warn',
  on: {
    proxyReq: (proxyReq, req) => {
      if (req.id) proxyReq.setHeader('X-Request-Id', req.id);
      // Microservices apply rate limits per IP — forward real client (nginx) or direct peer.
      const xff = req.headers['x-forwarded-for'];
      if (xff) {
        proxyReq.setHeader(
          'X-Forwarded-For',
          Array.isArray(xff) ? xff.join(', ') : String(xff)
        );
      } else {
        const peer = req.socket?.remoteAddress;
        if (peer) {
          const ip = peer.replace(/^::ffff:/, '');
          proxyReq.setHeader('X-Forwarded-For', ip);
          if (!proxyReq.getHeader('x-real-ip')) {
            proxyReq.setHeader('X-Real-IP', ip);
          }
        }
      }
    },
    /**
     * Without CORS headers on this response, browsers hide the error from JS → Dio shows ERROR[null].
     */
    error: (err, req, res, proxyTarget) => {
      logger.error({
        msg: 'Gateway proxy upstream error',
        target: proxyTarget || target,
        code: err && err.code,
        message: err && err.message,
        path: req && req.originalUrl,
      });
      if (res.headersSent) {
        return;
      }
      applyCorsHeadersOnError(req, res);
      res.statusCode = 502;
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.end(
        JSON.stringify({
          success: false,
          message:
            'Gateway could not reach an upstream microservice. Run all services: cd backend && npm run dev:stack (needs auth:3001, core:3002, union:3003, platform:3004).',
          error: (err && err.code) || 'EPROXY',
          upstream: String(target),
        })
      );
    },
  },
});

/**
 * http-proxy-middleware v3 + Express: app.use('/api/foo', proxy) strips req.url to the
 * suffix only, so upstream receives /ping instead of /api/foo/ping → 404 on microservices.
 * Use pathFilter at app root so req.url stays the full client path (see HPM + Express #4854).
 */
const apiProxy = (target, pathFilter) =>
  createProxyMiddleware({
    pathFilter,
    ...proxyOpts(target),
  });

// Global rate limit for /api (same behaviour as monolith)
app.use('/api', apiLimiter);

// Order: longest / most specific pathFilter first where prefixes could overlap
app.use(apiProxy(AUTH_URL, '/api/simple-auth'));
app.use(apiProxy(AUTH_URL, '/api/auth'));
app.use(apiProxy(UNION_URL, '/api/union'));
app.use(apiProxy(PLATFORM_URL, '/api/admin'));
app.use(apiProxy(PLATFORM_URL, '/api/payments'));
app.use(apiProxy(PLATFORM_URL, '/api/notifications'));
app.use(apiProxy(PLATFORM_URL, '/api/reviews'));
app.use(apiProxy(PLATFORM_URL, '/api/uploads'));
app.use(apiProxy(CORE_URL, '/api/bookings'));
app.use(apiProxy(CORE_URL, '/api/trips'));
app.use(apiProxy(CORE_URL, '/api/drivers'));
app.use(apiProxy(CORE_URL, '/api/driver-verification'));

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.CLIENT_URL || '*',
    methods: ['GET', 'POST'],
  },
});
attachSocketIoRedisAdapter(io);

attachSocketHandlers(io);
setIo(io);

const PORT = parseInt(process.env.GATEWAY_PORT || process.env.PORT || '3000', 10);
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    logger.error(
      `Gateway: port ${PORT} is already in use (e.g. monolith \`node server.js\` on 3000). Stop it or set GATEWAY_PORT in .env. Local dev stack uses GATEWAY_PORT=3010 via npm script.`
    );
  } else {
    logger.error({ msg: 'Gateway server error', error: err.message, code: err.code });
  }
  process.exit(1);
});

server.listen(PORT, LISTEN_HOST, () => {
  logger.info(`🚀 API Gateway on ${LISTEN_HOST}:${PORT}`);
  logger.info(`   → ${AUTH_URL} (auth)`);
  logger.info(`   → ${CORE_URL} (core)`);
  logger.info(`   → ${UNION_URL} (union)`);
  logger.info(`   → ${PLATFORM_URL} (platform)`);
  if (PORT === 3010) {
    logger.info(
      '📱 Flutter (local microservices stack): gateway is on 3010 — use '
      + '`--dart-define=USE_LOCAL_API=true --dart-define=LOCAL_API_PORT=3010` '
      + '(monolith uses default port 3000, no LOCAL_API_PORT).'
    );
  }
  if (shouldWarnTrustProxyUnsetInProduction()) {
    logger.warn(
      '⚠️  TRUST_PROXY not set — behind nginx/HTTPS all clients may share ONE rate-limit IP. Set TRUST_PROXY=1 in backend/.env (see docs/TRUST_PROXY_AND_NGINX_A_TO_Z.md)'
    );
  }
});

module.exports = { app, server, io };
