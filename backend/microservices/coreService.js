/**
 * Core domain — trips, bookings, drivers, driver-verification + background jobs
 * Port: CORE_SERVICE_PORT (default 3002)
 * Socket.IO is NOT here when using gateway (gateway owns /socket.io).
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { validateConfig } = require('../src/config/env');
validateConfig();
require('../src/utils/processGuard').installProcessGuard();
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-core';
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');
const { authenticate } = require('../src/middleware/auth');
const { submitVerification, getMyStatus } = require('../src/controllers/driverVerificationController');
const { getMySubmittedDocuments } = require('../src/controllers/kycDocumentsController');
const { streamMyKycDocumentFile } = require('../src/controllers/kycDocumentStreamController');

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
app.get('/api/kyc/submitted-documents', authenticate, getMySubmittedDocuments);
app.get('/api/kyc/document-file', authenticate, streamMyKycDocumentFile);
attachErrorHandlers(app);

const PORT = parseInt(process.env.CORE_SERVICE_PORT || '3002', 10);
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';
app.listen(PORT, LISTEN_HOST, () => {
  logger.info(`[core-service] listening on ${LISTEN_HOST}:${PORT}`);
  rateNotificationJob.start();
  rideCleanupJob.start();
});
