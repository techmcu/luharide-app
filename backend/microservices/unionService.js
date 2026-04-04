/**
 * Union microservice — /api/union/*
 * Port: UNION_SERVICE_PORT (default 3003)
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { validateConfig } = require('../src/config/env');
validateConfig();
process.env.LUHA_SERVICE_NAME = process.env.LUHA_SERVICE_NAME || 'luha-ms-union';
const path = require('path');
const express = require('express');
const { createBaseApp, attachErrorHandlers } = require('./sharedApp');

const unionRoutes = require('../src/routes/union');

const app = createBaseApp('union');
// Merged union KYC PDFs are written here; gateway proxies GET /uploads/union-docs → this service.
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/api/union', unionRoutes);
attachErrorHandlers(app);

const PORT = parseInt(process.env.UNION_SERVICE_PORT || '3003', 10);
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';
app.listen(PORT, LISTEN_HOST, () => {
  console.log(`[union-service] listening on ${LISTEN_HOST}:${PORT}`);
});
