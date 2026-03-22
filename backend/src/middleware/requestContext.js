const { randomUUID } = require('crypto');

/**
 * Correlation ID for logs & tracing — accepts X-Request-Id / X-Correlation-Id from gateway or client.
 */
function requestContext(req, res, next) {
  const raw = req.headers['x-request-id'] || req.headers['x-correlation-id'];
  const id = raw && String(raw).trim() ? String(raw).trim() : randomUUID();
  req.id = id;
  res.setHeader('X-Request-Id', id);
  next();
}

module.exports = { requestContext };
