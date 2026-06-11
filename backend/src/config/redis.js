/**
 * Redis client with circuit-breaker alerting and infinite reconnect.
 *
 * - Alerts only on state transitions (up→down, down→up) — no spam.
 * - Never gives up reconnecting (30s max backoff).
 * - getRedisHealth() for health endpoints + memory monitoring.
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

// State-aware alerting: only fire on transitions
let _redisUp = null; // null = unknown, true = connected, false = disconnected

function _alertTransition(up, detail) {
  if (_redisUp === up) return;
  const wasDown = _redisUp === false;
  _redisUp = up;
  if (up) {
    logger.info({ msg: 'Redis connected', detail });
    if (wasDown) {
      sendTelegramAlert(formatInfraAlert('Redis', `RECOVERED — ${detail}`, null, { severity: 'ok' }));
    }
  } else {
    logger.error({ msg: 'Redis DOWN', detail });
    sendTelegramAlert(formatInfraAlert('Redis', `DOWN — ${detail}. Rate-limits falling back to in-memory.`));
  }
}

function buildRedisOptions() {
  const host = process.env.REDIS_HOST || '127.0.0.1';
  const port = parseInt(process.env.REDIS_PORT || '6379', 10);
  const password = process.env.REDIS_PASSWORD;
  return {
    host,
    port,
    ...(password ? { password } : {}),
    maxRetriesPerRequest: 3,
    connectTimeout: 5000,
    lazyConnect: false,
    retryStrategy(times) {
      return Math.min(times * 500, 30000);
    },
  };
}

function getRedisClient() {
  if (!isRedisEnabled()) return null;
  if (mainClient) return mainClient;
  try {
    const Redis = require('ioredis');
    mainClient = new Redis(buildRedisOptions());

    mainClient.on('error', (err) => {
      _alertTransition(false, err.message);
    });

    mainClient.on('ready', () => {
      _alertTransition(true, 'connection restored');
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
      c.on('error', () => {}); // errors already tracked via mainClient
    });
    return { pub: socketPub, sub: socketSub };
  } catch (e) {
    logger.warn({ msg: 'Socket.IO Redis clients failed', error: e.message });
    return null;
  }
}

async function getRedisHealth() {
  if (!isRedisEnabled()) return { enabled: false };
  if (!mainClient) return { enabled: true, status: 'not_initialized' };
  const health = {
    enabled: true,
    status: mainClient.status,
    up: mainClient.status === 'ready',
  };
  if (health.up) {
    try {
      const info = await mainClient.info('memory');
      const used = info.match(/used_memory_human:(\S+)/);
      const max = info.match(/maxmemory_human:(\S+)/);
      const keys = await mainClient.dbsize();
      health.memory = used ? used[1] : 'unknown';
      health.maxmemory = max ? max[1] : 'not set';
      health.keys = keys;
    } catch (_) {}
  }
  return health;
}

const REDIS_MEM_WARN_BYTES = parseInt(process.env.REDIS_MEM_WARN_MB || '80', 10) * 1024 * 1024;

async function checkRedisMemory() {
  const client = getRedisClient();
  if (!client || client.status !== 'ready') return null;
  try {
    const info = await client.info('memory');
    const usedMatch = info.match(/used_memory:(\d+)/);
    const maxMatch = info.match(/maxmemory:(\d+)/);
    const used = usedMatch ? parseInt(usedMatch[1], 10) : 0;
    const max = maxMatch ? parseInt(maxMatch[1], 10) : 0;

    if (max === 0) {
      logger.warn('Redis maxmemory is NOT set — set it to prevent OOM kills (e.g. maxmemory 100mb in redis.conf)');
    }
    if (used > REDIS_MEM_WARN_BYTES) {
      const usedMB = (used / 1024 / 1024).toFixed(1);
      sendTelegramAlert(formatInfraAlert('Redis', `Memory high: ${usedMB}MB used (warn threshold: ${REDIS_MEM_WARN_BYTES / 1024 / 1024}MB).`));
    }
    return { used, max, policy: info.match(/maxmemory_policy:(\S+)/)?.[1] || 'unknown' };
  } catch (e) {
    return null;
  }
}

async function flushExpiredKeys() {
  const client = getRedisClient();
  if (!client || client.status !== 'ready') return 0;
  try {
    const dbsize = await client.dbsize();
    if (dbsize > 10000) {
      logger.warn(`Redis has ${dbsize} keys — unexpectedly high, investigate stale keys`);
    }
    return dbsize;
  } catch (e) {
    return 0;
  }
}

module.exports = {
  isRedisEnabled,
  getRedisClient,
  createRateLimitRedisStore,
  getSocketIoRedisClients,
  getRedisHealth,
  checkRedisMemory,
  flushExpiredKeys,
};
