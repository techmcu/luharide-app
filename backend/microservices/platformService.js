/**
 * Platform microservice — admin, payments, notifications, reviews, uploads
 * Port: PLATFORM_SERVICE_PORT (default 3004)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-platform';
const path = require('path');
const express = require('express');
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');

const adminRoutes = require('../src/routes/admin');
const paymentRoutes = require('../src/routes/payments');
const notificationRoutes = require('../src/routes/notifications');
const reviewRoutes = require('../src/routes/reviews');
const uploadRoutes = require('../src/routes/uploads');

const app = createBaseApp('platform');
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/api/admin', adminRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/uploads', uploadRoutes);
attachErrorHandlers(app);

const PORT = parseInt(process.env.PLATFORM_SERVICE_PORT || '3004', 10);
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';
app.listen(PORT, LISTEN_HOST, () => {
  console.log(`[platform-service] listening on ${LISTEN_HOST}:${PORT}`);
});
