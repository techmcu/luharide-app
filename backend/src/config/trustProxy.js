/**
 * Express `trust proxy` — real client IP for express-rate-limit & req.ip when behind
 * Nginx, Cloudflare, or another reverse proxy (X-Forwarded-For / X-Real-IP).
 *
 * @see docs/TRUST_PROXY_AND_NGINX_A_TO_Z.md
 */

/**
 * @returns {number|null|0} null = unset (Express default: do not trust). 0 = explicitly off. >=1 = hop count.
 */
function parseTrustProxy() {
  const raw = (process.env.TRUST_PROXY || '').trim();
  if (raw === '') return null;
  const v = raw.toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(v)) return 1;
  if (['0', 'false', 'no', 'off'].includes(v)) return 0;
  if (/^\d+$/.test(raw)) {
    const n = parseInt(raw, 10);
    if (n >= 1 && n <= 32) return n;
  }
  return null;
}

/**
 * Value suitable for app.set('trust proxy', …)
 * @returns {boolean|number|null} null means caller should not change Express default
 */
function trustProxyExpressValue() {
  const p = parseTrustProxy();
  if (p === null) return null;
  if (p === 0) return false;
  return p;
}

/**
 * Apply trust proxy to an Express app. Safe to call on gateway, monolith, and each microservice.
 * @returns {{ applied: boolean, hops: number|false|null }}
 */
function applyTrustProxy(app) {
  const val = trustProxyExpressValue();
  if (val === null) {
    return { applied: false, hops: null };
  }
  app.set('trust proxy', val);
  return { applied: true, hops: val };
}

/** User explicitly disabled (TRUST_PROXY=0|false|…) */
function isTrustProxyExplicitlyDisabled() {
  return parseTrustProxy() === 0;
}

/** User enabled or set hop count (1–32) */
function isTrustProxyEnabled() {
  const p = parseTrustProxy();
  return p !== null && p !== 0;
}

/**
 * Log once in production if TRUST_PROXY was never set — likely nginx/HTTPS in front.
 */
function shouldWarnTrustProxyUnsetInProduction() {
  return process.env.NODE_ENV === 'production' && parseTrustProxy() === null;
}

module.exports = {
  parseTrustProxy,
  trustProxyExpressValue,
  applyTrustProxy,
  isTrustProxyExplicitlyDisabled,
  isTrustProxyEnabled,
  shouldWarnTrustProxyUnsetInProduction,
};
