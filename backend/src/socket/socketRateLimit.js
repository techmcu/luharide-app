const logger = require('../config/logger');

const connections = new Map();

const DEFAULT_MAX = parseInt(process.env.WS_RATE_LIMIT_MAX || '20', 10);
const DEFAULT_WINDOW_MS = parseInt(process.env.WS_RATE_LIMIT_WINDOW_MS || '60000', 10);

function cleanupExpired(windowMs) {
  const now = Date.now();
  for (const [ip, entry] of connections) {
    entry.timestamps = entry.timestamps.filter((t) => now - t < windowMs);
    if (entry.timestamps.length === 0) connections.delete(ip);
  }
}

let cleanupTimer = null;
function ensureCleanup(windowMs) {
  if (cleanupTimer) return;
  cleanupTimer = setInterval(() => cleanupExpired(windowMs), windowMs).unref();
}

function socketRateLimit(options = {}) {
  const max = options.max || DEFAULT_MAX;
  const windowMs = options.windowMs || DEFAULT_WINDOW_MS;

  ensureCleanup(windowMs);

  return (socket, next) => {
    const ip =
      socket.handshake.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
      socket.handshake.address?.replace(/^::ffff:/, '') ||
      'unknown';

    const now = Date.now();
    let entry = connections.get(ip);
    if (!entry) {
      entry = { timestamps: [] };
      connections.set(ip, entry);
    }

    entry.timestamps = entry.timestamps.filter((t) => now - t < windowMs);
    entry.timestamps.push(now);

    if (entry.timestamps.length > max) {
      logger.warn(`WebSocket rate limit exceeded for ${ip} (${entry.timestamps.length}/${max} in ${windowMs}ms)`);
      return next(new Error('Too many connections. Please try again later.'));
    }
    next();
  };
}

module.exports = { socketRateLimit };
