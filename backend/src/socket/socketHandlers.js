/**
 * Socket.IO — rooms: trip:{tripId}, user:{userId}
 * Handshake auth: client passes JWT in socket.handshake.auth.token (Flutter socket_io_client).
 */
const { verifyAccessToken } = require('../services/tokenService');
const logger = require('../config/logger');
const { socketRateLimit } = require('./socketRateLimit');

/**
 * @param {import('socket.io').Server} io
 */
function attachSocketHandlers(io) {
  const tripIdPattern = /^[a-zA-Z0-9-]{8,64}$/;

  const isFiniteNumber = (n) => typeof n === 'number' && Number.isFinite(n);

  const canTrackLocation = (lat, lng) =>
    isFiniteNumber(lat) &&
    isFiniteNumber(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180;

  const nowMs = () => Date.now();

  io.use(socketRateLimit());

  io.use((socket, next) => {
    socket.userId = null;
    socket._lastLocationAt = 0;
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.query?.token ||
      null;
    if (token) {
      try {
        const decoded = verifyAccessToken(String(token));
        socket.userId = decoded.userId;
      } catch (_) {
        // Allow connection for anonymous trip tracking; user room not joined
        socket.authFailed = true;
      }
    }
    next();
  });

  io.on('connection', (socket) => {
    if (socket.userId) {
      socket.join(`user:${socket.userId}`);
    }

    // Join a trip tracking room (authenticated users only).
    socket.on('join-trip', (tripId) => {
      if (!socket.userId) return;
      if (!tripId || !tripIdPattern.test(String(tripId))) return;
      socket.join(`trip:${String(tripId)}`);
    });

    socket.on('leave-trip', (tripId) => {
      if (!tripId || !tripIdPattern.test(String(tripId))) return;
      socket.leave(`trip:${String(tripId)}`);
    });

    // Driver live location → only authenticated users + sanitized payload.
    socket.on('location-update', (data) => {
      try {
        if (!socket.userId) return;
        // Soft per-socket throttle (~5 updates/sec max).
        const t = nowMs();
        if (t - (socket._lastLocationAt || 0) < 200) return;
        socket._lastLocationAt = t;

        const { tripId, lat, lng, speed } = data || {};
        if (!tripId || !tripIdPattern.test(String(tripId))) return;

        const latNum = typeof lat === 'string' ? Number(lat) : lat;
        const lngNum = typeof lng === 'string' ? Number(lng) : lng;
        const speedNum = typeof speed === 'string' ? Number(speed) : speed;
        if (!canTrackLocation(latNum, lngNum)) return;

        io.to(`trip:${String(tripId)}`).emit('driver-location', {
          tripId: String(tripId),
          lat: latNum,
          lng: lngNum,
          ...(isFiniteNumber(speedNum) ? { speed: speedNum } : {}),
          ts: new Date().toISOString(),
        });
      } catch (err) {
        logger.warn('Socket location-update error:', err.message);
      }
    });

    socket.on('disconnect', () => {
      socket.removeAllListeners();
    });
  });
}

module.exports = attachSocketHandlers;
