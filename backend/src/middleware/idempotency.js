const { isRedisEnabled, getRedisClient } = require('../config/redis');
const logger = require('../config/logger');

const KEY_PREFIX = 'luha:idem';
const DEFAULT_TTL_SECONDS = 24 * 60 * 60; // remember a key for 24h

/**
 * Idempotency middleware (Stripe-style) — makes an unsafe write safe to retry.
 *
 * If the client sends an `Idempotency-Key` header, the same logical operation
 * runs AT MOST ONCE: the first request executes and its successful response is
 * cached in Redis; any retry carrying the same key replays that cached response
 * instead of running the handler again. This kills duplicates from network
 * retries / lost responses (e.g. a 502 where the first request actually
 * succeeded but the reply was lost).
 *
 * Design:
 *  - Key scoped per (user, method, path, client-key) so keys can't collide
 *    across users or endpoints.
 *  - Atomic claim via Redis `SET key val NX EX ttl` (ioredis returns 'OK' / null).
 *    A retry that arrives while the first is still running gets 409 (so the
 *    handler is never run twice in parallel).
 *  - Graceful degradation: no header, or Redis unavailable → behaves exactly
 *    like a normal request. An idempotency hiccup must NEVER block a real write.
 *  - Only 2xx responses are cached. A failed attempt releases the key so the
 *    client can legitimately retry.
 */
function idempotency(ttlSeconds = DEFAULT_TTL_SECONDS) {
  return (req, res, next) => {
    const key = req.get('Idempotency-Key');
    if (!key) return next();
    if (!isRedisEnabled()) return next();
    const client = getRedisClient();
    if (!client) return next();

    const userId = (req.user && req.user.id) || 'anon';
    const path = `${req.baseUrl || ''}${req.path || ''}`;
    const redisKey = `${KEY_PREFIX}:${userId}:${req.method}:${path}:${key}`;

    client
      .set(redisKey, 'PENDING', 'NX', 'EX', ttlSeconds)
      .then((claimed) => {
        if (claimed === 'OK') {
          // First request for this key — run the handler, capture its response.
          const originalJson = res.json.bind(res);
          res.json = (body) => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              client
                .set(redisKey, JSON.stringify({ status: res.statusCode, body }), 'EX', ttlSeconds)
                .catch(() => {});
            } else {
              // Non-2xx → don't cache a failure; let a genuine retry proceed.
              client.del(redisKey).catch(() => {});
            }
            return originalJson(body);
          };
          return next();
        }

        // Key already claimed → this is a duplicate. Replay or tell to wait.
        return client
          .get(redisKey)
          .then((stored) => {
            if (!stored || stored === 'PENDING') {
              return res.status(409).json({
                success: false,
                message: 'This request is already being processed. Please wait.',
              });
            }
            const parsed = JSON.parse(stored);
            return res.status(parsed.status).json(parsed.body);
          })
          .catch((e) => {
            logger.warn('Idempotency replay failed (continuing):', e.message);
            next();
          });
      })
      .catch((e) => {
        logger.warn('Idempotency claim failed (continuing without):', e.message);
        next();
      });
  };
}

module.exports = { idempotency };
