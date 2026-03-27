/**
 * Union microservice — /api/union/*
 * Port: UNION_SERVICE_PORT (default 3003)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { validateConfig } = require('../src/config/env');
validateConfig();
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-union';
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');

const unionRoutes = require('../src/routes/union');

const app = createBaseApp('union');
app.use('/api/union', unionRoutes);
attachErrorHandlers(app);

const PORT = parseInt(process.env.UNION_SERVICE_PORT || '3003', 10);
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';
app.listen(PORT, LISTEN_HOST, () => {
  console.log(`[union-service] listening on ${LISTEN_HOST}:${PORT}`);
});
