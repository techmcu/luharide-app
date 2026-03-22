const logger = require('../config/logger');
const { getSocketIoRedisClients } = require('../config/redis');

/**
 * Multi-instance Socket.IO: same Redis → broadcast across all gateway/monolith nodes.
 * No-op if REDIS_ENABLED is false.
 */
function attachSocketIoRedisAdapter(io) {
  const pair = getSocketIoRedisClients();
  if (!pair || !pair.pub || !pair.sub) return false;
  try {
    const { createAdapter } = require('@socket.io/redis-adapter');
    io.adapter(createAdapter(pair.pub, pair.sub));
    logger.info('Socket.IO Redis adapter enabled (multi-node broadcasts)');
    return true;
  } catch (e) {
    logger.warn({ msg: 'Socket.IO Redis adapter failed', error: e.message });
    return false;
  }
}

module.exports = { attachSocketIoRedisAdapter };
