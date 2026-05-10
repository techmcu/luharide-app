const { pool } = require('../config/database');
const asyncHandler = require('../utils/asyncHandler');
const ApiResponse = require('../utils/ApiResponse');
const ApiError = require('../utils/ApiError');

const COOLDOWN_MS = 2 * 60 * 1000; // 2 minutes per caller+driver pair

const logContact = asyncHandler(async (req, res) => {
  const callerId = req.user.id;
  const { driver_id, union_id, contact_type } = req.body;

  if (!driver_id || !union_id) {
    throw ApiError.badRequest('driver_id and union_id required');
  }
  if (!['call', 'whatsapp'].includes(contact_type)) {
    throw ApiError.badRequest('contact_type must be call or whatsapp');
  }

  const driverId = String(driver_id).trim();
  if (!driverId) {
    throw ApiError.badRequest('Invalid driver_id');
  }

  // Anti-spam: same caller → same driver within 2 minutes = skip (don't count)
  const recent = await pool.query(
    `SELECT 1 FROM contact_logs
     WHERE caller_id = $1 AND driver_id = $2 AND contact_type = $3
       AND created_at > NOW() - INTERVAL '2 minutes'
     LIMIT 1`,
    [callerId, driverId, contact_type]
  );

  if (recent.rows.length > 0) {
    return ApiResponse.success(
      { counted: false },
      'Already logged recently'
    ).send(res);
  }

  await pool.query(
    `INSERT INTO contact_logs (caller_id, driver_id, union_id, contact_type)
     VALUES ($1, $2, $3, $4)`,
    [callerId, driverId, union_id, contact_type]
  );

  ApiResponse.success({ counted: true }, 'Contact logged').send(res);
});

const getContactStats = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  // Get union_id for this admin
  const unionRes = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [userId]
  );

  if (unionRes.rows.length === 0) {
    return ApiResponse.success({
      today: { calls: 0, whatsapp: 0 },
      week: { calls: 0, whatsapp: 0 },
      month: { calls: 0, whatsapp: 0 },
      drivers: [],
    }, 'No union').send(res);
  }

  const unionId = unionRes.rows[0].union_id;

  const [todayRes, weekRes, monthRes, driverRes] = await Promise.all([
    pool.query(
      `SELECT contact_type, COUNT(*)::int AS count
       FROM contact_logs
       WHERE union_id = $1 AND created_at >= CURRENT_DATE::timestamp
       GROUP BY contact_type`,
      [unionId]
    ),
    pool.query(
      `SELECT contact_type, COUNT(*)::int AS count
       FROM contact_logs
       WHERE union_id = $1 AND created_at >= (CURRENT_DATE - INTERVAL '7 days')::timestamp
       GROUP BY contact_type`,
      [unionId]
    ),
    pool.query(
      `SELECT contact_type, COUNT(*)::int AS count
       FROM contact_logs
       WHERE union_id = $1 AND created_at >= (CURRENT_DATE - INTERVAL '30 days')::timestamp
       GROUP BY contact_type`,
      [unionId]
    ),
    pool.query(
      `SELECT d.id, d.name, d.phone, d.whatsapp_number,
              COUNT(*) FILTER (WHERE cl.contact_type = 'call')::int AS calls,
              COUNT(*) FILTER (WHERE cl.contact_type = 'whatsapp')::int AS whatsapp_clicks
       FROM union_drivers d
       LEFT JOIN contact_logs cl ON cl.driver_id = d.id
         AND cl.created_at >= (CURRENT_DATE - INTERVAL '30 days')::timestamp
       WHERE d.union_id = $1
       GROUP BY d.id, d.name, d.phone, d.whatsapp_number
       ORDER BY (COUNT(*) FILTER (WHERE cl.contact_type = 'call') +
                 COUNT(*) FILTER (WHERE cl.contact_type = 'whatsapp')) DESC`,
      [unionId]
    ),
  ]);

  function extractCounts(rows) {
    let calls = 0, whatsapp = 0;
    for (const r of rows) {
      if (r.contact_type === 'call') calls = r.count;
      if (r.contact_type === 'whatsapp') whatsapp = r.count;
    }
    return { calls, whatsapp };
  }

  ApiResponse.success({
    today: extractCounts(todayRes.rows),
    week: extractCounts(weekRes.rows),
    month: extractCounts(monthRes.rows),
    drivers: driverRes.rows,
  }, 'Contact stats').send(res);
});

module.exports = { logContact, getContactStats };
