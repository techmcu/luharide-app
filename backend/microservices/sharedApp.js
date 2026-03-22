/**
 * Shared Express baseline for LuhaRide microservices (reuse src/ controllers & routes).
 */
const express = require('express');
const compression = require('compression');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { errorConverter, errorHandler } = require('../src/middleware/errorHandler');

function createBaseApp(serviceName) {
  const app = express();
  if (process.env.TRUST_PROXY === '1' || process.env.TRUST_PROXY === 'true') {
    app.set('trust proxy', 1);
  }
  app.use(helmet());
  app.use(compression());
  app.use(cors());
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

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
