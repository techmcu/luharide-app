/**
 * PostgreSQL advisory try-lock — Phase 5 scaling guard without Redis.
 * Only one session holds (key1, key2) at a time; others skip immediately.
 *
 * @param {import('pg').Pool} pool
 * @param {number} key1
 * @param {number} key2
 * @param {(client: import('pg').PoolClient) => Promise<void>} fn
 * @returns {Promise<boolean>} true if fn ran, false if lock busy
 */
async function withPgAdvisoryTryLock(pool, key1, key2, fn) {
  const client = await pool.connect();
  let locked = false;
  try {
    const { rows } = await client.query(
      'SELECT pg_try_advisory_lock($1::integer, $2::integer) AS ok',
      [key1, key2]
    );
    if (!rows[0].ok) return false;
    locked = true;
    await fn(client);
    return true;
  } finally {
    if (locked) {
      await client
        .query('SELECT pg_advisory_unlock($1::integer, $2::integer)', [key1, key2])
        .catch(() => {});
    }
    client.release();
  }
}

/** LuhaRide job key namespace (arbitrary int pair space). */
const JOB_NS = 884001;
const JOB_RATE_NOTIFICATIONS = 1;
const JOB_RIDE_CLEANUP = 2;
const JOB_PENDING_BOOKING_EXPIRY = 3;
const JOB_TRIP_AUTO_COMPLETE = 4;

module.exports = {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_RATE_NOTIFICATIONS,
  JOB_RIDE_CLEANUP,
  JOB_PENDING_BOOKING_EXPIRY,
  JOB_TRIP_AUTO_COMPLETE,
};
