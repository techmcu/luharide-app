const { isRedisEnabled, getRedisClient } = require('../config/redis');

function redisCache(ttlSeconds = 30, keyPrefix = 'luha:cache') {
  return (req, res, next) => {
    if (req.method !== 'GET') return next();
    if (!isRedisEnabled()) return next();
    const client = getRedisClient();
    if (!client) return next();

    const key = `${keyPrefix}:${req.originalUrl}`;

    client
      .get(key)
      .then((cached) => {
        if (cached) {
          const parsed = JSON.parse(cached);
          return res.status(200).json(parsed);
        }

        const originalJson = res.json.bind(res);
        res.json = (body) => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            client
              .setex(key, ttlSeconds, JSON.stringify(body))
              .catch(() => {});
          }
          return originalJson(body);
        };
        next();
      })
      .catch(() => next());
  };
}

module.exports = { redisCache };
