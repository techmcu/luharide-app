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
const http = require('http');
const express = require('express');
const compression = require('compression');
const { createHelmetMiddleware } = require('../src/config/helmetConfig');
const { applyLuhaCors } = require('../src/middleware/corsLuha');
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

const app = express();
applyTrustProxy(app);

app.use(createHelmetMiddleware());
app.use(requestContext);
app.use(compression());
applyLuhaCors(app);
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

const proxyOpts = (target) => ({
  target,
  changeOrigin: true,
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
  },
});

// Global rate limit for /api (same behaviour as monolith)
app.use('/api', apiLimiter);

// Order: longest / most specific prefixes first where paths could overlap
app.use('/api/simple-auth', createProxyMiddleware({ ...proxyOpts(AUTH_URL) }));
app.use('/api/auth', createProxyMiddleware({ ...proxyOpts(AUTH_URL) }));
app.use('/api/union', createProxyMiddleware({ ...proxyOpts(UNION_URL) }));
app.use('/api/admin', createProxyMiddleware({ ...proxyOpts(PLATFORM_URL) }));
app.use('/api/payments', createProxyMiddleware({ ...proxyOpts(PLATFORM_URL) }));
app.use('/api/notifications', createProxyMiddleware({ ...proxyOpts(PLATFORM_URL) }));
app.use('/api/reviews', createProxyMiddleware({ ...proxyOpts(PLATFORM_URL) }));
app.use('/api/uploads', createProxyMiddleware({ ...proxyOpts(PLATFORM_URL) }));
app.use('/api/bookings', createProxyMiddleware({ ...proxyOpts(CORE_URL) }));
app.use('/api/trips', createProxyMiddleware({ ...proxyOpts(CORE_URL) }));
app.use('/api/drivers', createProxyMiddleware({ ...proxyOpts(CORE_URL) }));
app.use('/api/driver-verification', createProxyMiddleware({ ...proxyOpts(CORE_URL) }));

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
