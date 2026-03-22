/**
 * Flutter Web / Chrome dev: page is often `http://localhost:<port>` while API was
 * `http://127.0.0.1:3000` — that triggers Private Network Access preflight.
 * Without `Access-Control-Allow-Private-Network: true`, the browser fails the request
 * and Dio reports `XMLHttpRequest onError` with no HTTP status.
 *
 * Also use `origin: true` so any dev origin (localhost, 127.0.0.1, LAN IP) is echoed.
 * @see https://developer.chrome.com/blog/private-network-access-preflight
 */
const cors = require('cors');

const corsOptions = {
  origin: true,
  credentials: true,
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With'],
  optionsSuccessStatus: 204,
};

function privateNetworkAccessHeader(req, res, next) {
  const v = req.headers['access-control-request-private-network'];
  if (String(v).toLowerCase() === 'true') {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
  }
  next();
}

/** Register CORS + PNA on an Express app (call after helmet, before body parsers). */
function applyLuhaCors(app) {
  app.use(privateNetworkAccessHeader);
  app.use(cors(corsOptions));
}

module.exports = { applyLuhaCors, corsOptions, privateNetworkAccessHeader };
