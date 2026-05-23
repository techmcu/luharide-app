/**
 * LuhaRide API Gateway — single public port; proxies to microservices.
 * Preserves all /api/* paths (Flutter & clients unchanged).
 *
 * Run after: auth (3001), core (3002), union (3003), platform (3004)
 * Env: AUTH_URL, CORE_URL, UNION_URL, PLATFORM_URL (defaults below)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { validateConfig } = require('../src/config/env');
validateConfig();
require('../src/utils/processGuard').installProcessGuard();
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-gateway';
const path = require('path');
const os = require('os');
const http = require('http');
const express = require('express');
const { mountUploadsStatic } = require('../src/config/staticUploads');
const compression = require('compression');
const { createHelmetMiddleware } = require('../src/config/helmetConfig');
const {
  applyLuhaCors,
  applyCorsHeadersOnError,
  corsOptions,
} = require('../src/middleware/corsLuha');
const morgan = require('morgan');
const { createProxyMiddleware } = require('http-proxy-middleware');
const socketIo = require('socket.io');

const { pool } = require('../src/config/database');
const { apiLimiter } = require('../src/middleware/rateLimiter');
const { apiVersionRewrite } = require('../src/middleware/apiVersionRewrite');
const { attachSocketIoRedisAdapter } = require('../src/socket/socketRedisAdapter');
const attachSocketHandlers = require('../src/socket/socketHandlers');
const { setIo } = require('../src/socket/socketIoRegistry');
const { requestContext } = require('../src/middleware/requestContext');
const logger = require('../src/config/logger');
const { applyTrustProxy, trustProxyStatus, shouldWarnTrustProxyUnsetInProduction } = require('../src/config/trustProxy');
const { getBreaker, getAllBreakers } = require('./circuitBreaker');
const { recordMiddleware, getMetrics } = require('../src/middleware/metricsCollector');

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

app.use(createHelmetMiddleware());
app.use(requestContext);
app.use(compression());
applyLuhaCors(app);
app.use(recordMiddleware());
morgan.token('reqId', (req) => req.id || '-');
app.use(morgan(':reqId :method :url :status :response-time ms'));

// /api/v1/* → /api/* rewrite (backward compat: /api/ still works)
app.use(apiVersionRewrite);

mountUploadsStatic(app, path.join(__dirname, '../uploads'));

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

app.get('/health/metrics', async (req, res) => {
  const data = await getMetrics('gateway', pool);
  res.status(200).json(data);
});

app.get('/health/circuits', (req, res) => {
  const circuits = getAllBreakers();
  const allClosed = circuits.every((c) => c.state === 'CLOSED');
  res.status(allClosed ? 200 : 503).json({ ok: allClosed, circuits });
});

const _proxyTimeoutMs = Math.max(
  5000,
  parseInt(process.env.GATEWAY_PROXY_TIMEOUT_MS || '120000', 10) || 120000
);

const proxyOpts = (target, breakerName) => {
  const breaker = breakerName ? getBreaker(breakerName) : null;
  return {
    target,
    changeOrigin: true,
    timeout: _proxyTimeoutMs,
    logLevel: process.env.GATEWAY_PROXY_LOG === 'debug' ? 'debug' : 'warn',
    on: {
      proxyReq: (proxyReq, req) => {
        if (req.id) proxyReq.setHeader('X-Request-Id', req.id);
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
      proxyRes: (proxyRes) => {
        if (!breaker) return;
        if (proxyRes.statusCode >= 500) breaker.recordFailure();
        else breaker.recordSuccess();
      },
      error: (err, req, res, proxyTarget) => {
        if (breaker) breaker.recordFailure();
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
              'Server temporarily unavailable. Please try again in a few moments.',
          })
        );
      },
    },
  };
};

/**
 * http-proxy-middleware v3 + Express: app.use('/api/foo', proxy) strips req.url to the
 * suffix only, so upstream receives /ping instead of /api/foo/ping → 404 on microservices.
 * Use pathFilter at app root so req.url stays the full client path (see HPM + Express #4854).
 */
function circuitGuard(breakerName) {
  return (req, res, next) => {
    const breaker = getBreaker(breakerName);
    if (!breaker.isAvailable()) {
      applyCorsHeadersOnError(req, res);
      return res.status(503).json({
        success: false,
        message: 'Server temporarily unavailable. Please try again in a few moments.',
      });
    }
    next();
  };
}

const apiProxy = (target, pathFilter, breakerName) =>
  [
    circuitGuard(breakerName),
    createProxyMiddleware({
      pathFilter,
      ...proxyOpts(target, breakerName),
    }),
  ];

// Static may miss; then route uploads to the service that actually stores the files.
// Raw union JPEG/PNG live on platform (/uploads/union-raw); merged KYC PDFs on union (/uploads/union-merged + legacy /uploads/union-docs/*.pdf).
app.use(
  createProxyMiddleware({
    pathFilter: (pathname) => pathname.startsWith('/uploads/union-merged'),
    ...proxyOpts(UNION_URL),
  })
);
app.use(
  createProxyMiddleware({
    pathFilter: (pathname) => pathname.startsWith('/uploads/union-docs'),
    ...proxyOpts(UNION_URL),
  })
);
app.use(
  createProxyMiddleware({
    pathFilter: (pathname) => pathname.startsWith('/uploads/union-raw'),
    ...proxyOpts(PLATFORM_URL),
  })
);
app.use(
  createProxyMiddleware({
    pathFilter: (pathname) => pathname.startsWith('/uploads/driver-docs'),
    ...proxyOpts(PLATFORM_URL),
  })
);

// Global rate limit for /api (same behaviour as monolith)
app.use('/api', apiLimiter);

// Order: longest / most specific pathFilter first where prefixes could overlap
app.use(apiProxy(AUTH_URL, '/api/simple-auth', 'auth'));
app.use(apiProxy(AUTH_URL, '/api/auth', 'auth'));
app.use(apiProxy(UNION_URL, '/api/union', 'union'));
app.use(apiProxy(PLATFORM_URL, '/api/platform-admin', 'platform'));
app.use(apiProxy(PLATFORM_URL, '/api/admin', 'platform'));
app.use(apiProxy(PLATFORM_URL, '/api/payments', 'platform'));
app.use(apiProxy(PLATFORM_URL, '/api/notifications', 'platform'));
app.use(apiProxy(PLATFORM_URL, '/api/reviews', 'platform'));
app.use(apiProxy(PLATFORM_URL, '/api/uploads', 'platform'));
app.use(apiProxy(CORE_URL, '/api/kyc', 'core'));
app.use(apiProxy(CORE_URL, '/api/bookings', 'core'));
app.use(apiProxy(CORE_URL, '/api/trips', 'core'));
app.use(apiProxy(CORE_URL, '/api/drivers', 'core'));
app.use(apiProxy(CORE_URL, '/api/driver-verification', 'core'));

const server = http.createServer(app);
server.setMaxListeners(25);
// Same origin rules as REST (CORS_ALLOWED_ORIGINS / CLIENT_URL + localhost dev).
const io = socketIo(server, {
  cors: {
    origin: corsOptions.origin,
    methods: ['GET', 'POST'],
    credentials: false,
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
  logger.info(`🔒 ${trustProxyStatus()}`);
  if (shouldWarnTrustProxyUnsetInProduction()) {
    logger.warn(
      '⚠️  TRUST_PROXY not set — behind nginx/HTTPS all clients may share ONE rate-limit IP. Set TRUST_PROXY=1 in backend/.env'
    );
  }
});

module.exports = { app, server, io };
