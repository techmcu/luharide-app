const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { validateConfig } = require('./src/config/env');
validateConfig();
// Production VPS: standard = PM2 gateway + 4 microservices (see pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs).
// Monolith (this file): local dev / emergency rollback only — do not run both on port 3000.
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-monolith';
const os = require('os');
const express = require('express');
const compression = require('compression');
const { createHelmetMiddleware } = require('./src/config/helmetConfig');
const { applyLuhaCors } = require('./src/middleware/corsLuha');
const morgan = require('morgan');
const http = require('http');
const socketIo = require('socket.io');

// Import configurations
const { pool } = require('./src/config/database');

// Import routes
const authRoutes = require('./src/routes/auth');
const simpleAuthRoutes = require('./src/routes/simpleAuth');
const bookingRoutes = require('./src/routes/bookings');
const tripRoutes = require('./src/routes/trips');
const driverRoutes = require('./src/routes/drivers');
const { authenticate } = require('./src/middleware/auth');
const { submitVerification, getMyStatus } = require('./src/controllers/driverVerificationController');
const adminRoutes = require('./src/routes/admin');
const unionRoutes = require('./src/routes/union');
const paymentRoutes = require('./src/routes/payments');
const notificationRoutes = require('./src/routes/notifications');
const reviewRoutes = require('./src/routes/reviews');
const uploadRoutes = require('./src/routes/uploads');

// Import middleware
const { errorConverter, errorHandler } = require('./src/middleware/errorHandler');
const { apiLimiter } = require('./src/middleware/rateLimiter');
const { requestContext } = require('./src/middleware/requestContext');
const logger = require('./src/config/logger');
const { applyTrustProxy, shouldWarnTrustProxyUnsetInProduction } = require('./src/config/trustProxy');

// Import socket handlers
const { attachSocketIoRedisAdapter } = require('./src/socket/socketRedisAdapter');
const attachSocketHandlers = require('./src/socket/socketHandlers');
const { setIo } = require('./src/socket/socketIoRegistry');
const rateNotificationJob = require('./src/jobs/rateNotificationJob');
const rideCleanupJob = require('./src/jobs/rideCleanupJob');

const app = express();

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

// If behind nginx / load balancer, set TRUST_PROXY=1 so express-rate-limit uses real client IP
// (X-Forwarded-For). Without this, all traffic can look like one IP → shared limit → random 429s.
if (process.env.TRUST_PROXY === '1' || process.env.TRUST_PROXY === 'true') {
  app.set('trust proxy', 1);
}

const server = http.createServer(app);

// Basic VPS: drop stuck clients so pool/FDs don't pile up (nginx may also timeout)
const httpTimeoutMs = Math.min(
  600000,
  Math.max(30000, parseInt(process.env.HTTP_SERVER_TIMEOUT_MS || '120000', 10) || 120000)
);
server.timeout = httpTimeoutMs;
server.headersTimeout = httpTimeoutMs + 5000;
server.keepAliveTimeout = 65000;

const io = socketIo(server, {
  cors: {
    origin: process.env.CLIENT_URL || '*',
    methods: ['GET', 'POST']
  }
});
attachSocketIoRedisAdapter(io);

// Middleware
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
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
morgan.token('reqId', (req) => req.id || '-');
app.use(morgan(':reqId :method :url :status :response-time ms'));
// Static assets for uploaded documents
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      database: 'connected'
    });
  } catch (error) {
    res.status(503).json({
      status: 'error',
      message: 'Service unavailable',
      error: error.message
    });
  }
});

// API Routes — global /api limit + stricter limits on auth & simple-auth (see rateLimiter.js)
app.use('/api', apiLimiter);
app.use('/api/auth', authRoutes);
app.use('/api/simple-auth', simpleAuthRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/drivers', driverRoutes);
// Driver verification - explicit routes (avoids router mount 404)
app.get('/api/driver-verification', authenticate, getMyStatus);
app.post('/api/driver-verification', authenticate, submitVerification);
app.use('/api/admin', adminRoutes);
app.use('/api/union', unionRoutes);
if (String(process.env.PAYMENTS_ENABLED || 'false').toLowerCase() === 'true') {
  app.use('/api/payments', paymentRoutes);
} else {
  app.use('/api/payments', (req, res) => {
    return res.status(503).json({
      success: false,
      message: 'Online payment is temporarily disabled. Please pay offline to the driver.',
      code: 'PAYMENTS_DISABLED',
    });
  });
}
app.use('/api/notifications', notificationRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/uploads', uploadRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'LuhaRide API',
    version: '1.0.0',
    status: 'running'
  });
});

// GET /api and GET /api/health – so opening in browser shows OK instead of 404
app.get('/api', (req, res) => {
  res.json({
    ok: true,
    message: 'LuhaRide API is running',
    version: '1.0.0',
    search: 'GET /api/trips/search?from=Dehradun&to=Purola&date=2026-02-23',
    endpoints: {
      trips: '/api/trips',
      search: '/api/trips/search',
      auth: '/api/auth',
      simpleAuth: '/api/simple-auth',
      simpleAuthPing: 'GET /api/simple-auth/ping',
      health: '/api/health',
    },
  });
});
app.get('/api/health', (req, res) => {
  res.status(200).json({ ok: true, status: 'running' });
});

app.get('/health/metrics', (req, res) => {
  const sorted = [...metrics.latenciesMs].sort((a, b) => a - b);
  const mem = process.memoryUsage();
  const uptimeSec = Math.floor(process.uptime());
  const total = metrics.requests || 1;
  res.status(200).json({
    ok: true,
    service: 'monolith',
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

// Socket.IO — rooms, JWT auth, realtime registry for controllers
attachSocketHandlers(io);
setIo(io);

// Error handling middleware (must be last)
app.use(errorConverter);
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested endpoint does not exist'
  });
});

// Start server
const PORT = process.env.PORT || 3000;
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';

server.listen(PORT, LISTEN_HOST, () => {
  logger.info(`🚀 Server on ${LISTEN_HOST}:${PORT} (HTTP timeout ${httpTimeoutMs}ms)`);
  logger.info(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`🔗 API: http://127.0.0.1:${PORT}/api  |  http://localhost:${PORT}/api`);
  logger.info(`❤️  Health: http://localhost:${PORT}/health`);
  if (shouldWarnTrustProxyUnsetInProduction()) {
    logger.warn(
      '⚠️  TRUST_PROXY not set — behind nginx/Cloudflare all clients may share ONE rate-limit IP. Set TRUST_PROXY=1 in .env (see docs/TRUST_PROXY_AND_NGINX_A_TO_Z.md)'
    );
  }
  rateNotificationJob.start();
  rideCleanupJob.start();
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(async () => {
    await pool.end();
    console.log('HTTP server closed');
    process.exit(0);
  });
});

module.exports = { app, server, io };
