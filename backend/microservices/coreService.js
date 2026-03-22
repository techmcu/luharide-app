/**
 * Core domain — trips, bookings, drivers, driver-verification + background jobs
 * Port: CORE_SERVICE_PORT (default 3002)
 * Socket.IO is NOT here when using gateway (gateway owns /socket.io).
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-core';
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');
const { authenticate } = require('../src/middleware/auth');
const { submitVerification, getMyStatus } = require('../src/controllers/driverVerificationController');

const bookingRoutes = require('../src/routes/bookings');
const tripRoutes = require('../src/routes/trips');
const driverRoutes = require('../src/routes/drivers');

const rateNotificationJob = require('../src/jobs/rateNotificationJob');
const rideCleanupJob = require('../src/jobs/rideCleanupJob');
const logger = require('../src/config/logger');

const app = createBaseApp('core');
app.use('/api/bookings', bookingRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/drivers', driverRoutes);
app.get('/api/driver-verification', authenticate, getMyStatus);
app.post('/api/driver-verification', authenticate, submitVerification);
attachErrorHandlers(app);

const PORT = parseInt(process.env.CORE_SERVICE_PORT || '3002', 10);
app.listen(PORT, () => {
  logger.info(`[core-service] listening on ${PORT}`);
  rateNotificationJob.start();
  rideCleanupJob.start();
});
