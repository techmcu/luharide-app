/**
 * Helmet defaults include Cross-Origin-Resource-Policy: same-origin, which blocks
 * browsers from reading API responses when the SPA runs on another origin
 * (e.g. Flutter Web at http://localhost:xxxxx calling http://127.0.0.1:3000/api).
 * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cross-Origin-Resource-Policy
 */
const helmet = require('helmet');

function createHelmetMiddleware() {
  return helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    // JSON API — avoid default CSP header on responses (harmless for most clients; keeps dev simple).
    contentSecurityPolicy: false,
  });
}

module.exports = { createHelmetMiddleware };
