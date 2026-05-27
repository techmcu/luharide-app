/**
 * Validated env config – fail fast if required vars missing
 * Scalability: single place to add feature flags / env-based limits
 */
function getEnv(key, defaultValue) {
  const value = process.env[key];
  if (value !== undefined && value !== '') return value;
  if (defaultValue !== undefined) return defaultValue;
  return undefined;
}

function requireEnv(key, label = key) {
  const value = getEnv(key);
  if (!value) {
    throw new Error(`Missing required env: ${label} (${key})`);
  }
  return value;
}

const config = {
  nodeEnv: getEnv('NODE_ENV', 'development'),
  port: parseInt(getEnv('PORT', '3000'), 10),
  db: {
    host: getEnv('DB_HOST', 'localhost'),
    port: parseInt(getEnv('DB_PORT', '5432'), 10),
    name: getEnv('DB_NAME', 'luharide'),
    user: getEnv('DB_USER', 'postgres'),
    password: getEnv('DB_PASSWORD', ''),
  },
  jwt: {
    secret: getEnv('JWT_SECRET', ''),
    expiresIn: getEnv('JWT_EXPIRES_IN', '7d'),
  },
  pagination: {
    defaultPageSize: 20,
    maxPageSize: 50,
  },
};

/** Known insecure placeholders — must not run in production with these */
const JWT_PLACEHOLDER_SECRETS = new Set([
  'your-secret-key-change-in-production',
  'your_jwt_secret_key_here_change_in_production',
  'changeme',
  'secret',
]);

const JWT_PROD_MIN_LEN = parseInt(process.env.JWT_SECRET_MIN_LENGTH || '16', 10) || 16;

function validateConfig() {
  if (!config.db.password && config.nodeEnv === 'production') {
    throw new Error('DB_PASSWORD is required in production');
  }

  if (config.nodeEnv !== 'production') {
    return;
  }

  const secret = String(config.jwt.secret || '').trim();
  if (!secret) {
    throw new Error('JWT_SECRET is required in production');
  }
  if (JWT_PLACEHOLDER_SECRETS.has(secret.toLowerCase())) {
    throw new Error('JWT_SECRET must not be a default placeholder; set a strong unique value');
  }
  if (secret.length < JWT_PROD_MIN_LEN) {
    throw new Error(
      `JWT_SECRET must be at least ${JWT_PROD_MIN_LEN} characters in production (set JWT_SECRET_MIN_LENGTH to relax)`
    );
  }

  const redisEnabled = process.env.REDIS_ENABLED === 'true' || process.env.REDIS_ENABLED === '1';
  if (!redisEnabled) {
    console.warn(
      '⚠️  REDIS_ENABLED is not set in production. Rate limits are per-process (not shared across PM2 instances). ' +
      'Set REDIS_ENABLED=true, REDIS_HOST, REDIS_PORT for production-grade rate limiting.'
    );
  }

  if (!process.env.GOOGLE_CLIENT_ID) {
    console.warn('⚠️  GOOGLE_CLIENT_ID not set — Google Sign-In will be unavailable.');
  }
}

module.exports = {
  config,
  getEnv,
  requireEnv,
  validateConfig,
};
