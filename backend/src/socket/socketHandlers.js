/**
 * Socket.IO — rooms: trip:{tripId}, user:{userId}
 * Handshake auth: client passes JWT in socket.handshake.auth.token (Flutter socket_io_client).
 */
const { verifyAccessToken } = require('../services/tokenService');
const logger = require('../config/logger');

/**
 * @param {import('socket.io').Server} io
 */
function attachSocketHandlers(io) {
  io.use((socket, next) => {
    socket.userId = null;
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

    // Join a trip tracking room (passengers, drivers viewing trip)
    socket.on('join-trip', (tripId) => {
      if (!tripId) return;
      socket.join(`trip:${tripId}`);
    });

    socket.on('leave-trip', (tripId) => {
      if (!tripId) return;
      socket.leave(`trip:${tripId}`);
    });

    // Driver live location → only subscribers of this trip room
    socket.on('location-update', (data) => {
      try {
        const { tripId, lat, lng, speed } = data || {};
        if (!tripId) return;
        io.to(`trip:${tripId}`).emit('driver-location', { tripId, lat, lng, speed });
      } catch (err) {
        logger.warn('Socket location-update error:', err.message);
      }
    });

    socket.on('disconnect', () => {});
  });
}

module.exports = attachSocketHandlers;
