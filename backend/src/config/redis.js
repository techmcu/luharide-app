/**
 * Optional Redis — Phase next: shared rate limits + Socket.IO multi-instance.
 * Enable: REDIS_ENABLED=true, REDIS_HOST, REDIS_PORT, REDIS_PASSWORD (optional)
 */
const logger = require('./logger');
const { sendTelegramAlert, formatInfraAlert } = require('../utils/telegramAlert');

function isRedisEnabled() {
  const v = process.env.REDIS_ENABLED;
  return v === 'true' || v === '1';
}

let mainClient = null;
let socketPub = null;
let socketSub = null;

function buildRedisOptions() {
  const host = process.env.REDIS_HOST || '127.0.0.1';
  const port = parseInt(process.env.REDIS_PORT || '6379', 10);
  const password = process.env.REDIS_PASSWORD;
  return {
    host,
    port,
    ...(password ? { password } : {}),
    maxRetriesPerRequest: 20,
    retryStrategy(times) {
      if (times > 15) return null;
      return Math.min(times * 200, 3000);
    },
  };
}

/**
 * Single shared connection for rate-limit scripts (and base for socket duplicates).
 */
function getRedisClient() {
  if (!isRedisEnabled()) return null;
  if (mainClient) return mainClient;
  try {
    const Redis = require('ioredis');
    mainClient = new Redis(buildRedisOptions());
    mainClient.on('error', (err) => {
      logger.warn({ msg: 'Redis client error', error: err.message });
      sendTelegramAlert(formatInfraAlert('Redis', err.message));
    });
    mainClient.on('connect', () => {
      logger.info('Redis connected (main client)');
    });
    return mainClient;
  } catch (e) {
    logger.warn({ msg: 'Redis init failed', error: e.message });
    return null;
  }
}

/**
 * Dedicated RedisStore per limiter (each has its own windowMs / prefix).
 */
function createRateLimitRedisStore(name) {
  const client = getRedisClient();
  if (!client) return undefined;
  try {
    const { RedisStore } = require('rate-limit-redis');
    return new RedisStore({
      sendCommand: (...args) => client.call(...args),
      prefix: `luha:rl:${name}:`,
    });
  } catch (e) {
    logger.warn({ msg: 'rate-limit-redis store failed', name, error: e.message });
    return undefined;
  }
}

/**
 * Pub/sub pair for @socket.io/redis-adapter (separate connections required).
 */
function getSocketIoRedisClients() {
  if (!isRedisEnabled()) return null;
  const base = getRedisClient();
  if (!base) return null;
  if (socketPub && socketSub) return { pub: socketPub, sub: socketSub };
  try {
    socketPub = base.duplicate();
    socketSub = base.duplicate();
    [socketPub, socketSub].forEach((c) => {
      c.on('error', (err) => logger.warn({ msg: 'Redis socket client error', error: err.message }));
    });
    return { pub: socketPub, sub: socketSub };
  } catch (e) {
    logger.warn({ msg: 'Socket.IO Redis clients failed', error: e.message });
    return null;
  }
}

module.exports = {
  isRedisEnabled,
  getRedisClient,
  createRateLimitRedisStore,
  getSocketIoRedisClients,
};
