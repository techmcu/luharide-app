/**
 * Push events to connected Flutter/web clients (Socket.IO rooms).
 * Rooms: user:{uuid} — per-user notifications; trip:{uuid} — trip detail / seat sync.
 */
const { getIo } = require('./socketIoRegistry');
const logger = require('../config/logger');
const { sendPushToUser } = require('../utils/pushNotification');

function emitToTrip(tripId, event, payload) {
  const io = getIo();
  if (!io || !tripId) return;
  try {
    io.to(`trip:${tripId}`).emit(event, { tripId, ...payload });
  } catch (e) {
    logger.warn('emitToTrip failed:', e.message);
  }
}

/** Notify clients watching this trip to refresh seats / booking state */
function emitTripUpdated(tripId, extra = {}) {
  emitToTrip(tripId, 'trip-updated', extra);
}

/**
 * Push a new in-app notification to a user's devices.
 * @param {string} userId
 * @param {object} notification - shape similar to API row (id, type, title, body, data, is_read, created_at)
 */
function emitNotificationToUser(userId, notification) {
  if (!userId) return;

  if (notification && notification.title) {
    sendPushToUser(userId, notification.title, notification.body || '').catch(() => {});
  }

  const io = getIo();
  if (!io) return;
  try {
    io.to(`user:${userId}`).emit('notification:new', { notification });
  } catch (e) {
    logger.warn('emitNotificationToUser failed:', e.message);
  }
}

function emitMaintenanceBroadcast(maintenanceMode, message) {
  const io = getIo();
  if (!io) return;
  try {
    io.emit('maintenance:update', { maintenanceMode, message });
  } catch (e) {
    logger.warn('emitMaintenanceBroadcast failed:', e.message);
  }
}

module.exports = {
  emitToTrip,
  emitTripUpdated,
  emitNotificationToUser,
  emitMaintenanceBroadcast,
};
