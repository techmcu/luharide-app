const pg = require('pg');
const { Pool } = pg;

// Timestamp without TZ: treat as UTC when reading so API returns correct time for all clients
// OID 1114 = timestamp (without time zone)
pg.types.setTypeParser(1114, (stringValue) => {
  if (stringValue == null) return null;
  return new Date(stringValue.replace(' ', 'T') + 'Z');
});

function parseIntEnv(name, defaultVal, min, max) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return defaultVal;
  const v = parseInt(String(raw), 10);
  if (!Number.isFinite(v)) return defaultVal;
  return Math.min(max, Math.max(min, v));
}

const dbHost = process.env.DB_HOST || 'localhost';
const dbPort = parseInt(process.env.DB_PORT, 10) || 5432;
const dbName = process.env.DB_NAME || 'luharide';
const dbUser = process.env.DB_USER || 'postgres';
const dbPassword = process.env.DB_PASSWORD || '';

const SERVICE_POOL_DEFAULTS = {
  'luha-ms-auth':     { min: 3, max: 20 },
  'luha-ms-core':     { min: 3, max: 25 },
  'luha-ms-union':    { min: 2, max: 10 },
  'luha-ms-platform': { min: 2, max: 15 },
  'luha-gateway':     { min: 1, max: 5 },
  'luha-monolith':    { min: 2, max: 20 },
};

const serviceName = process.env.LUHA_SERVICE_NAME || '';
const serviceDefaults = SERVICE_POOL_DEFAULTS[serviceName] || { min: 2, max: 20 };

/** Primary pool. Auto-tuned per service; override with PG_POOL_MIN / PG_POOL_MAX. */
const poolMin = parseIntEnv('PG_POOL_MIN', serviceDefaults.min, 1, 80);
const poolMax = parseIntEnv('PG_POOL_MAX', serviceDefaults.max, poolMin, 100);

const sharedPoolOptions = {
  port: dbPort,
  database: dbName,
  user: dbUser,
  password: dbPassword,
  min: poolMin,
  max: poolMax,
  idleTimeoutMillis: parseIntEnv('PG_IDLE_TIMEOUT_MS', 30000, 5000, 600000),
  connectionTimeoutMillis: parseIntEnv('PG_CONNECTION_TIMEOUT_MS', 10000, 2000, 120000),
};

/**
 * Optional read replica: set DB_READ_HOST (same user/db/password/port as primary unless overridden).
 * If unset, read pool === write pool (no extra connections).
 */
const readHost = (process.env.DB_READ_HOST || '').trim();
const readPort = process.env.DB_READ_PORT ? parseInt(process.env.DB_READ_PORT, 10) : dbPort;
const readUser = process.env.DB_READ_USER || dbUser;
const readPassword = process.env.DB_READ_PASSWORD !== undefined ? process.env.DB_READ_PASSWORD : dbPassword;
const readDatabase = process.env.DB_READ_NAME || dbName;

const readMin = parseIntEnv('PG_POOL_READ_MIN', Math.min(2, poolMin), 1, 80);
const readMax = parseIntEnv('PG_POOL_READ_MAX', Math.min(poolMax, 40), readMin, 100);

function attachStatementTimeout(poolInstance) {
  const ms = parseIntEnv('PG_STATEMENT_TIMEOUT_MS', 30000, 0, 600000);
  if (ms <= 0) return;
  poolInstance.on('connect', (client) => {
    client.query(`SET statement_timeout TO ${ms}`).catch(() => {});
  });
}

const pool = new Pool({
  host: dbHost,
  ...sharedPoolOptions,
});

attachStatementTimeout(pool);

let poolRead = pool;
if (readHost && readHost !== dbHost) {
  poolRead = new Pool({
    host: readHost,
    port: readPort,
    database: readDatabase,
    user: readUser,
    password: readPassword,
    min: readMin,
    max: readMax,
    idleTimeoutMillis: sharedPoolOptions.idleTimeoutMillis,
    connectionTimeoutMillis: sharedPoolOptions.connectionTimeoutMillis,
  });
  attachStatementTimeout(poolRead);
}

const logger = require('./logger');
const { sendTelegramAlert, formatInfraAlert } = require('../utils/telegramAlert');

pool.on('error', (err) => {
  logger.error({ msg: 'Unexpected idle client error on primary pool', err: err.message });
  sendTelegramAlert(formatInfraAlert('PostgreSQL (primary)', err.message, err.stack));
});
if (poolRead !== pool) {
  poolRead.on('error', (err) => {
    logger.error({ msg: 'Unexpected idle client error on read pool', err: err.message });
    sendTelegramAlert(formatInfraAlert('PostgreSQL (read replica)', err.message, err.stack));
  });
}

let connectLogOnce = false;
pool.on('connect', () => {
  if (!connectLogOnce) {
    connectLogOnce = true;
    // eslint-disable-next-line no-console
    console.log(
      `✅ PostgreSQL pool (primary): ${dbHost}:${dbPort} min=${poolMin} max=${poolMax}` +
        (readHost && readHost !== dbHost ? ` | read replica: ${readHost}:${readPort} min=${readMin} max=${readMax}` : '')
    );
    const st = parseIntEnv('PG_STATEMENT_TIMEOUT_MS', 0, 0, 600000);
    if (st > 0) {
      // eslint-disable-next-line no-console
      console.log(`   statement_timeout=${st}ms`);
    }
  }
});

const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      logger.error('ROLLBACK failed:', rollbackErr.message);
    }
    throw error;
  } finally {
    client.release();
  }
};

const query = (text, params) => pool.query(text, params);

/** Use for SELECT-heavy paths when replica lag (usually <1s) is acceptable. Falls back to primary on failure. */
const queryRead = async (text, params) => {
  if (poolRead === pool) return pool.query(text, params);
  try {
    return await poolRead.query(text, params);
  } catch (err) {
    logger.warn('Read replica query failed, falling back to primary:', err.message);
    return pool.query(text, params);
  }
};

module.exports = {
  pool,
  poolRead,
  query,
  queryRead,
  transaction,
};
