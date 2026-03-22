/**
 * Holds the Socket.IO server instance so HTTP controllers / jobs can emit realtime events.
 * Set once from server.js or gateway/server.js after creating `io`.
 */
let ioInstance = null;

function setIo(io) {
  ioInstance = io;
}

function getIo() {
  return ioInstance;
}

module.exports = { setIo, getIo };
