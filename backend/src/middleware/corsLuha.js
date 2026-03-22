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

// credentials: false — JWT is in Authorization header, not cookies. credentials:true
// + browser can break CORS on some error responses (XHR shows ERROR[null] in Flutter).
const corsOptions = {
  origin: true,
  credentials: false,
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With'],
  optionsSuccessStatus: 204,
};

/** Use when http-proxy (or similar) sends an error before normal cors() runs on the body. */
function applyCorsHeadersOnError(req, res) {
  const origin = req.headers.origin;
  if (origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  } else {
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS'
  );
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, Accept, X-Requested-With'
  );
}

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

module.exports = {
  applyLuhaCors,
  corsOptions,
  privateNetworkAccessHeader,
  applyCorsHeadersOnError,
};
