/**
 * Shared Express baseline for LuhaRide microservices (reuse src/ controllers & routes).
 */
const express = require('express');
const compression = require('compression');
const { createHelmetMiddleware } = require('../src/config/helmetConfig');
const { applyLuhaCors } = require('../src/middleware/corsLuha');
const morgan = require('morgan');
const { errorConverter, errorHandler } = require('../src/middleware/errorHandler');
const { requestContext } = require('../src/middleware/requestContext');
const { applyTrustProxy } = require('../src/config/trustProxy');

function createBaseApp(serviceName) {
  const app = express();
  applyTrustProxy(app);
  app.use(createHelmetMiddleware());
  app.use(requestContext);
  app.use(compression());
  applyLuhaCors(app);
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));
  morgan.token('reqId', (req) => req.id || '-');
  app.use(morgan(':reqId :method :url :status :response-time ms'));

  app.get('/health', async (req, res) => {
    try {
      const { pool } = require('../src/config/database');
      await pool.query('SELECT 1');
      res.json({
        ok: true,
        service: serviceName,
        database: 'connected',
        timestamp: new Date().toISOString(),
      });
    } catch (e) {
      res.status(503).json({ ok: false, service: serviceName, error: e.message });
    }
  });

  return app;
}

function attachErrorHandlers(app) {
  app.use(errorConverter);
  app.use(errorHandler);
  app.use((req, res) => {
    res.status(404).json({ error: 'Not Found', message: 'The requested endpoint does not exist' });
  });
}

module.exports = { createBaseApp, attachErrorHandlers };
