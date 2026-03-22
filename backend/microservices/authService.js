/**
 * Auth microservice — /api/auth + /api/simple-auth
 * Port: AUTH_SERVICE_PORT (default 3001)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-auth';
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');

const authRoutes = require('../src/routes/auth');
const simpleAuthRoutes = require('../src/routes/simpleAuth');

const app = createBaseApp('auth');
app.use('/api/auth', authRoutes);
app.use('/api/simple-auth', simpleAuthRoutes);
attachErrorHandlers(app);

const PORT = parseInt(process.env.AUTH_SERVICE_PORT || '3001', 10);
app.listen(PORT, () => {
  console.log(`[auth-service] listening on ${PORT}`);
});
