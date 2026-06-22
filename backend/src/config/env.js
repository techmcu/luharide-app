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
    expiresIn: getEnv('JWT_EXPIRES_IN', '1h'),
  },
  pagination: {
    defaultPageSize: 20,
    maxPageSize: 50,
  },
  // Ola Maps (Krutrim) — optional. Powers location autocomplete, geocoding,
  // road distance for fare estimation. Absent key → maps features degrade
  // gracefully (text-only search), never crash.
  olaMaps: {
    apiKey: getEnv('OLA_MAPS_API_KEY', ''),
    baseUrl: getEnv('OLA_MAPS_BASE_URL', 'https://api.olamaps.io'),
    enabled: !!getEnv('OLA_MAPS_API_KEY', ''),
    timeoutMs: parseInt(getEnv('OLA_MAPS_TIMEOUT_MS', '6000'), 10) || 6000,
    // Bias autocomplete toward our service region (Uttarakhand) so same-named
    // places resolve locally first (e.g. Purola/Chandeli in Uttarakhand, not MP/UP).
    biasLat: parseFloat(getEnv('OLA_MAPS_BIAS_LAT', '30.0668')) || 30.0668,
    biasLng: parseFloat(getEnv('OLA_MAPS_BIAS_LNG', '79.0193')) || 79.0193,
    biasRadiusM: parseInt(getEnv('OLA_MAPS_BIAS_RADIUS_M', '200000'), 10) || 200000,
  },
  // Distance-based fare ceiling for SHARED rides (per seat, INR).
  // Calibrated to real Uttarakhand shared fares (Purola↔Dehradun ≈145km ≈ ₹450).
  //   fair (internal) = baseFare + perKm × distanceKm
  //   maxAllowed      = fair × maxMultiplier   ← the only ENFORCED limit
  // The driver is NOT shown the fair/suggested price; they just enter a price.
  // They may go as LOW as they want, but cannot exceed maxAllowed (anti-overcharge).
  // Every knob is env-overridable — admin re-tunes from .env, no code change:
  //   FARE_BASE_FARE, FARE_PER_KM, FARE_MAX_MULTIPLIER, FARE_MIN_FARE, FARE_ROUND_TO
  fare: {
    baseFare: parseFloat(getEnv('FARE_BASE_FARE', '40')) || 40,          // flat base → makes short rides' effective ₹/km higher (natural decay)
    perKm: parseFloat(getEnv('FARE_PER_KM', '2.8')) || 2.8,              // marginal per-km rate (145km→₹445)
    maxMultiplier: parseFloat(getEnv('FARE_MAX_MULTIPLIER', '1.6')) || 1.6, // ceiling = fair × this (₹435→~₹700)
    minFare: parseFloat(getEnv('FARE_MIN_FARE', '10')) || 10,             // absolute sanity floor
    roundTo: parseInt(getEnv('FARE_ROUND_TO', '5'), 10) || 5,             // round to nearest N
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

  if (!process.env.OTP_HMAC_KEY) {
    console.warn(
      '⚠️  OTP_HMAC_KEY not set — falling back to JWT_SECRET for OTP hashing. ' +
      'Set a separate OTP_HMAC_KEY for better key isolation.'
    );
  }

  if (!process.env.GOOGLE_CLIENT_ID) {
    console.warn('⚠️  GOOGLE_CLIENT_ID not set — Google Sign-In will be unavailable.');
  }

  if (!process.env.OLA_MAPS_API_KEY) {
    console.warn(
      '⚠️  OLA_MAPS_API_KEY not set — location autocomplete, geocoding and ' +
      'road-distance fare estimation will fall back to text-only mode.'
    );
  }
}

module.exports = {
  config,
  getEnv,
  requireEnv,
  validateConfig,
};
