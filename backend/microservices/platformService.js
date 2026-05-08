/**
 * Platform microservice — admin, payments, notifications, reviews, uploads
 * Port: PLATFORM_SERVICE_PORT (default 3004)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { validateConfig } = require('../src/config/env');
validateConfig();
require('../src/utils/processGuard').installProcessGuard();
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-platform';
const path = require('path');
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');
const { mountUploadsStatic } = require('../src/config/staticUploads');

const adminRoutes = require('../src/routes/admin');
const platformAdminRoutes = require('../src/routes/platformAdmin');
const paymentRoutes = require('../src/routes/payments');
const notificationRoutes = require('../src/routes/notifications');
const reviewRoutes = require('../src/routes/reviews');
const uploadRoutes = require('../src/routes/uploads');

const app = createBaseApp('platform');
mountUploadsStatic(app, path.join(__dirname, '../uploads'));
app.use('/api/admin', adminRoutes);
app.use('/api/platform-admin', platformAdminRoutes);
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
const { getPublicAppConfig } = require('../src/controllers/platformAdminController');
app.get('/api/app-config', getPublicAppConfig);
app.use('/api/notifications', notificationRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/uploads', uploadRoutes);
attachErrorHandlers(app);

const PORT = parseInt(process.env.PLATFORM_SERVICE_PORT || '3004', 10);
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';
app.listen(PORT, LISTEN_HOST, () => {
  console.log(`[platform-service] listening on ${LISTEN_HOST}:${PORT}`);
});
