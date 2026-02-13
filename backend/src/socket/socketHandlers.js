module.exports = (io, socket) => {
  console.log('Socket connected:', socket.id);

  // Handle driver location updates
  socket.on('location-update', async (data) => {
    try {
      const { tripId, lat, lng, speed } = data;
      socket.broadcast.emit('driver-location', {
        tripId,
        lat,
        lng,
        speed,
      });
    } catch (error) {
      console.error('Error handling location update:', error);
    }
  });

  // Join trip room for real-time updates
  socket.on('join-trip', (tripId) => {
    socket.join(`trip:${tripId}`);
    console.log(`Socket ${socket.id} joined trip room: ${tripId}`);
  });

  // Leave trip room
  socket.on('leave-trip', (tripId) => {
    socket.leave(`trip:${tripId}`);
    console.log(`Socket ${socket.id} left trip room: ${tripId}`);
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log('Socket disconnected:', socket.id);
  });
};
