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

function validateConfig() {
  if (!config.db.password && config.nodeEnv === 'production') {
    throw new Error('DB_PASSWORD is required in production');
  }
  if (!config.jwt.secret && config.nodeEnv === 'production') {
    throw new Error('JWT_SECRET is required in production');
  }
}

module.exports = {
  config,
  getEnv,
  requireEnv,
  validateConfig,
};
