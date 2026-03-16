const pg = require('pg');
const { Pool } = pg;

// Timestamp without TZ: treat as UTC when reading so API returns correct time for all clients
// OID 1114 = timestamp (without time zone)
pg.types.setTypeParser(1114, (stringValue) => {
  if (stringValue == null) return null;
  return new Date(stringValue.replace(' ', 'T') + 'Z');
});

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'luharide',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  min: 2,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

// Test connection
pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL database');
});

// Removed error handler that was causing crashes
// pool.on('error', (err) => {
//   console.error('❌ Unexpected error on idle client', err);
// });

// Helper function for transactions
const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  pool,
  transaction,
  query: (text, params) => pool.query(text, params),
};
