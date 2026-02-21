const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
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

// Import middleware
const { errorConverter, errorHandler } = require('./src/middleware/errorHandler');
const logger = require('./src/config/logger');

// Import socket handlers
const socketHandlers = require('./src/socket/socketHandlers');
const rateNotificationJob = require('./src/jobs/rateNotificationJob');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.CLIENT_URL || '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

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

// API Routes
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
app.use('/api/payments', paymentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/reviews', reviewRoutes);

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
    endpoints: { trips: '/api/trips', search: '/api/trips/search', auth: '/api/auth', health: '/api/health' }
  });
});
app.get('/api/health', (req, res) => {
  res.status(200).json({ ok: true, status: 'running' });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  logger.info(`New client connected: ${socket.id}`);
  socketHandlers(io, socket);
});

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

server.listen(PORT, () => {
  logger.info(`🚀 Server running on port ${PORT}`);
  logger.info(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`🔗 API: http://localhost:${PORT}/api`);
  logger.info(`❤️  Health: http://localhost:${PORT}/health`);
  rateNotificationJob.start();
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
