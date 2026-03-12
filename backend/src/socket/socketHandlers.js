/**
 * Socket.IO event handlers.
 *
 * Room naming convention: 'trip:{tripId}'
 * Each passenger tracking a trip joins that room via 'join-trip'.
 * Driver location updates are broadcast only to that room — not globally.
 * This is O(room_subscribers) per emit instead of O(all_connected_sockets),
 * which keeps the system scalable under high concurrency.
 */
module.exports = (io, socket) => {
  // Join a trip tracking room (called by passengers and drivers)
  socket.on('join-trip', (tripId) => {
    if (!tripId) return;
    socket.join(`trip:${tripId}`);
  });

  // Leave a trip tracking room
  socket.on('leave-trip', (tripId) => {
    if (!tripId) return;
    socket.leave(`trip:${tripId}`);
  });

  // Driver sends live location — broadcast only to passengers in that trip's room.
  // Old code used socket.broadcast.emit() which sent to ALL connected clients globally.
  socket.on('location-update', (data) => {
    try {
      const { tripId, lat, lng, speed } = data;
      if (!tripId) return;
      io.to(`trip:${tripId}`).emit('driver-location', { tripId, lat, lng, speed });
    } catch (err) {
      console.error('Socket location-update error:', err.message);
    }
  });

  socket.on('disconnect', () => {
    // Socket.IO automatically cleans up room memberships on disconnect
  });
};
