const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const PDFDocument = require('pdfkit');

const adminEmail = process.env.ADMIN_EMAIL
  ? process.env.ADMIN_EMAIL.toLowerCase().trim()
  : null;

function ensurePlatformAdmin(user) {
  const email = user?.email ? String(user.email).toLowerCase().trim() : null;
  if (!adminEmail || !email || email !== adminEmail) {
    throw ApiError.forbidden('Only app admin can perform this action');
  }
}

/**
 * Get current user's union + status.
 * GET /api/union/me
 */
const getMyUnion = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const result = await pool.query(
    `SELECT u.*
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1
     ORDER BY u.created_at DESC
     LIMIT 1`,
    [userId]
  );

  const union = result.rows[0] || null;
  const status = union?.status || 'none';

  ApiResponse.success(
    { union, status },
    'Union status retrieved'
  ).send(res);
});

/**
 * Get all pending union registration requests (for admin panel).
 * GET /api/admin/union-requests
 */
const getPendingUnionRequests = asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT 
       u.*,
       ua.user_id,
       usr.name   AS owner_name,
       usr.email  AS owner_email,
       usr.phone  AS owner_phone
     FROM unions u
     LEFT JOIN union_admins ua ON ua.union_id = u.id
     LEFT JOIN users usr ON usr.id = ua.user_id
     WHERE u.status = 'pending'
     ORDER BY u.created_at ASC`
  );

  ApiResponse.success(
    { requests: result.rows },
    'Pending union requests retrieved'
  ).send(res);
});

/**
 * Approve union request from admin panel.
 * POST /api/admin/union-requests/:id/approve
 */
const approveUnionRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const unionRes = await pool.query(
    'SELECT * FROM unions WHERE id = $1 AND status = $2',
    [id, 'pending']
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.notFound('Pending union not found');
  }

  await pool.query(
    `UPDATE unions
     SET status = 'approved', is_active = TRUE, updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  await pool.query(
    `UPDATE users
     SET role = 'union_admin'
     WHERE id IN (SELECT user_id FROM union_admins WHERE union_id = $1)
       AND role <> 'union_admin'`,
    [id]
  );

  logger.info(`Union approved from admin panel ${id} by user ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'approved' },
    'Union approved successfully'
  ).send(res);
});

/**
 * Reject union request from admin panel.
 * POST /api/admin/union-requests/:id/reject
 */
const rejectUnionRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const unionRes = await pool.query(
    'SELECT * FROM unions WHERE id = $1 AND status = $2',
    [id, 'pending']
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.notFound('Pending union not found');
  }

  await pool.query(
    `UPDATE unions
     SET status = 'rejected', is_active = FALSE, updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  logger.info(`Union rejected from admin panel ${id} by user ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'rejected' },
    'Union rejected'
  ).send(res);
});

/**
 * Register a new union for the current user.
 * POST /api/union/register
 */
const registerUnion = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { name, location, contact_phone, contact_email } = req.body;

  if (!name || String(name).trim().length < 3) {
    throw ApiError.badRequest('Union name must be at least 3 characters');
  }

  // Basic: ensure user does not already have a union request
  const existing = await pool.query(
    `SELECT u.*
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1`,
    [userId]
  );
  if (existing.rows.length > 0) {
    throw ApiError.badRequest('You already manage or requested a taxi union');
  }

  const insertRes = await pool.query(
    `INSERT INTO unions (name, address, contact_phone, contact_email, is_active, status)
     VALUES ($1, $2, $3, $4, FALSE, 'pending')
     RETURNING *`,
    [String(name).trim(), location || null, contact_phone || null, contact_email || null]
  );

  const union = insertRes.rows[0];

  await pool.query(
    `INSERT INTO union_admins (union_id, user_id)
     VALUES ($1, $2)
     ON CONFLICT (union_id, user_id) DO NOTHING`,
    [union.id, userId]
  );

  logger.info(`Union registration requested ${union.id} by user ${userId}`);

  ApiResponse.created(
    { union },
    'Union registration submitted. Admin will review your request.'
  ).send(res);
});

/**
 * List unions by status (platform admin only).
 * GET /api/union/admin/unions?status=pending
 */
const listUnions = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { status } = req.query;

  let query = 'SELECT * FROM unions';
  const params = [];
  if (status) {
    query += ' WHERE status = $1';
    params.push(status);
  }
  query += ' ORDER BY created_at DESC';

  const result = await pool.query(query, params);
  ApiResponse.success(
    { unions: result.rows, count: result.rows.length },
    'Unions retrieved'
  ).send(res);
});

/**
 * Approve union (platform admin only).
 * POST /api/union/admin/unions/:id/approve
 */
const approveUnion = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const unionRes = await pool.query(
    'SELECT * FROM unions WHERE id = $1',
    [id]
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.notFound('Union not found');
  }

  await pool.query(
    `UPDATE unions
     SET status = 'approved', is_active = TRUE, updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  // Promote all admins for this union to union_admin role
  await pool.query(
    `UPDATE users
     SET role = 'union_admin'
     WHERE id IN (SELECT user_id FROM union_admins WHERE union_id = $1)
       AND role <> 'union_admin'`,
    [id]
  );

  logger.info(`Union approved ${id} by platform admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'approved' },
    'Union approved successfully'
  ).send(res);
});

/**
 * Reject union (platform admin only).
 * POST /api/union/admin/unions/:id/reject
 */
const rejectUnion = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const unionRes = await pool.query(
    'SELECT * FROM unions WHERE id = $1',
    [id]
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.notFound('Union not found');
  }

  await pool.query(
    `UPDATE unions
     SET status = 'rejected', is_active = FALSE, updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  logger.info(`Union rejected ${id} by platform admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'rejected' },
    'Union rejected'
  ).send(res);
});

/**
 * For a union admin (approved), list their drivers.
 * GET /api/union/drivers
 */
const getUnionDrivers = asyncHandler(async (req, res) => {
  // Find union for this admin
  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  const driversRes = await pool.query(
    `SELECT id, name, vehicle_number, phone, whatsapp_number, profile_image_url, created_at
     FROM union_drivers
     WHERE union_id = $1
     ORDER BY created_at DESC`,
    [unionId]
  );

  ApiResponse.success(
    { drivers: driversRes.rows, count: driversRes.rows.length },
    'Union drivers retrieved'
  ).send(res);
});

/**
 * Add a driver to this union (simple list entry, driver may not have app account).
 * POST /api/union/drivers
 */
const addUnionDriver = asyncHandler(async (req, res) => {
  const { name, vehicle_number, phone, whatsapp_number } = req.body;

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  const insertRes = await pool.query(
    `INSERT INTO union_drivers (union_id, name, vehicle_number, phone, whatsapp_number)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [unionId, name.trim(), vehicle_number.trim(), phone || null, whatsapp_number || null]
  );

  const driver = insertRes.rows[0];
  logger.info(`Union driver added ${driver.id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.created(
    { driver },
    'Driver added to union'
  ).send(res);
});

/**
 * Get preset routes for this union (for from/to dropdown).
 * GET /api/union/routes
 */
const getUnionRoutes = asyncHandler(async (req, res) => {
  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  const routesRes = await pool.query(
    `SELECT id, from_location, to_location, is_active, created_at
     FROM union_routes
     WHERE union_id = $1 AND is_active = TRUE
     ORDER BY from_location, to_location`,
    [unionId]
  );

  ApiResponse.success(
    { routes: routesRes.rows, count: routesRes.rows.length },
    'Union routes retrieved'
  ).send(res);
});

/**
 * Add a preset route (from/to) for this union.
 * POST /api/union/routes
 */
const addUnionRoute = asyncHandler(async (req, res) => {
  const { from_location, to_location } = req.body;

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  const insertRes = await pool.query(
    `INSERT INTO union_routes (union_id, from_location, to_location, is_active)
     VALUES ($1, $2, $3, TRUE)
     RETURNING *`,
    [unionId, from_location.trim(), to_location.trim()]
  );

  const route = insertRes.rows[0];
  logger.info(`Union route added ${route.id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.created(
    { route },
    'Route added for union'
  ).send(res);
});

/**
 * Create schedules (rides) for multiple drivers in one go.
 * POST /api/union/schedules/bulk
 */
const createUnionSchedulesBulk = asyncHandler(async (req, res) => {
  const { from_location, to_location, departure_time, union_driver_ids } = req.body;

  if (!Array.isArray(union_driver_ids) || union_driver_ids.length === 0) {
    throw ApiError.badRequest('At least one driver must be selected');
  }

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionId = resUnion.rows[0].union_id;

  // Ensure all drivers belong to this union
  const driversCheck = await pool.query(
    `SELECT id FROM union_drivers
     WHERE union_id = $1 AND id = ANY($2::uuid[])`,
    [unionId, union_driver_ids]
  );
  if (driversCheck.rows.length !== union_driver_ids.length) {
    throw ApiError.badRequest('One or more drivers are invalid for this union');
  }

  // Single multi-row INSERT in a transaction: atomic, one DB round-trip regardless of driver count.
  const client = await pool.connect();
  let created = [];
  try {
    await client.query('BEGIN');

    const fromTrimmed = from_location.trim();
    const toTrimmed   = to_location.trim();

    // Build flat params array and placeholder groups: ($1,$2,$3,$4,$5), ($6,$7,$8,$9,$10), ...
    const flatParams = [];
    const placeholders = union_driver_ids.map((driverId, i) => {
      const base = i * 5;
      flatParams.push(unionId, driverId, fromTrimmed, toTrimmed, departure_time);
      return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5}, 'scheduled')`;
    });

    const insertRes = await client.query(
      `INSERT INTO union_schedules (union_id, union_driver_id, from_location, to_location, departure_time, status)
       VALUES ${placeholders.join(', ')}
       RETURNING *`,
      flatParams
    );
    created = insertRes.rows;

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  logger.info(
    `Union schedules created for union ${unionId} by admin ${req.user.id} count=${created.length}`
  );

  ApiResponse.created(
    { schedules: created, count: created.length },
    'Rides created for selected drivers'
  ).send(res);
});

/**
 * Get union schedules (rides) - upcoming or recent.
 * GET /api/union/schedules?scope=current|recent
 */
const getUnionSchedules = asyncHandler(async (req, res) => {
  const scope = (req.query.scope || 'current').toString();

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionId = resUnion.rows[0].union_id;

  // Auto-clean old records: keep only last 10 days
  try {
    await pool.query(
      `DELETE FROM union_schedules
       WHERE union_id = $1
         AND departure_time < NOW() - INTERVAL '10 days'`,
      [unionId]
    );
  } catch (err) {
    logger.warn('Failed to cleanup old union_schedules', {
      unionId,
      code: err.code,
      message: err.message,
    });
  }

  let query = `
    SELECT s.*,
           d.name AS driver_name,
           d.vehicle_number,
           d.phone,
           d.whatsapp_number,
           (s.departure_time - NOW() > INTERVAL '5 minutes') AS can_cancel
    FROM union_schedules s
    JOIN union_drivers d ON d.id = s.union_driver_id
    WHERE s.union_id = $1
  `;
  const params = [unionId];

  if (scope === 'recent') {
    query += `
      AND s.departure_time >= NOW() - INTERVAL '10 days'
      ORDER BY s.departure_time DESC
      LIMIT 100
    `;
  } else {
    // current / upcoming
    query += `
      AND s.status = 'scheduled'
      AND s.departure_time >= NOW() - INTERVAL '5 minutes'
      ORDER BY s.departure_time ASC
    `;
  }

  const result = await pool.query(query, params);

  ApiResponse.success(
    { schedules: result.rows, count: result.rows.length },
    'Union schedules retrieved'
  ).send(res);
});

/**
 * Cancel a union schedule (only if departure is > 5 minutes away).
 * DELETE /api/union/schedules/:id
 */
const cancelUnionSchedule = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionId = resUnion.rows[0].union_id;

  const schedRes = await pool.query(
    `SELECT *
     FROM union_schedules
     WHERE id = $1 AND union_id = $2`,
    [id, unionId]
  );
  if (schedRes.rows.length === 0) {
    throw ApiError.notFound('Schedule not found');
  }

  const canCancelRes = await pool.query(
    `SELECT (departure_time - NOW() > INTERVAL '5 minutes') AS can_cancel
     FROM union_schedules
     WHERE id = $1`,
    [id]
  );
  const canCancel = canCancelRes.rows[0]?.can_cancel;
  if (!canCancel) {
    throw ApiError.badRequest('Ride cannot be cancelled now (time too close)');
  }

  await pool.query(
    `UPDATE union_schedules
     SET status = 'cancelled'
     WHERE id = $1`,
    [id]
  );

  logger.info(`Union schedule cancelled ${id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'cancelled' },
    'Ride cancelled successfully'
  ).send(res);
});

/**
 * Generate a simple PDF poster for a union schedule.
 * GET /api/union/schedules/:id/poster
 */
const getUnionSchedulePoster = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Ensure this user is an approved union admin and fetch union id
  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionId = resUnion.rows[0].union_id;

  // Load schedule + driver + union info
  const schedRes = await pool.query(
    `SELECT 
       s.*,
       d.name AS driver_name,
       d.vehicle_number,
       u.name AS union_name
     FROM union_schedules s
     JOIN union_drivers d ON d.id = s.union_driver_id
     JOIN unions u ON u.id = s.union_id
     WHERE s.id = $1 AND s.union_id = $2`,
    [id, unionId]
  );

  if (schedRes.rows.length === 0) {
    throw ApiError.notFound('Schedule not found');
  }

  const s = schedRes.rows[0];
  const from = (s.from_location || '').toString();
  const to = (s.to_location || '').toString();
  const driverName = (s.driver_name || '').toString();
  const vehicleNumber = (s.vehicle_number || '').toString();
  const unionName = (s.union_name || '').toString() || 'Taxi Union';

  const dt = s.departure_time ? new Date(s.departure_time) : null;
  const pad = (n) => (n < 10 ? `0${n}` : `${n}`);
  const dateStr = dt
    ? `${pad(dt.getDate())}-${pad(dt.getMonth() + 1)}-${dt.getFullYear()}`
    : '—';
  const timeStr = dt
    ? `${pad(dt.getHours())}:${pad(dt.getMinutes())}`
    : '—';

  // Prepare PDF response
  const safeUnion = unionName.replace(/[^\w]+/g, '-').slice(0, 40) || 'union';
  const safeFrom = from.replace(/[^\w]+/g, '-').slice(0, 40) || 'from';
  const safeTo = to.replace(/[^\w]+/g, '-').slice(0, 40) || 'to';
  const filename = `${safeUnion}-${safeFrom}-${safeTo}-${dateStr}.pdf`;

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `inline; filename="${filename}"`
  );

  const doc = new PDFDocument({
    size: 'A4',
    margin: 36,
  });

  doc.pipe(res);

  const pageWidth = doc.page.width;
  const innerWidth = pageWidth - 72;

  // Background
  doc
    .rect(0, 0, pageWidth, doc.page.height)
    .fill('#FFFDE7');

  // Header band with union name
  doc
    .save()
    .rect(0, 0, pageWidth, 90)
    .fill('#FFB300')
    .restore();

  doc
    .fillColor('#FFFFFF')
    .fontSize(26)
    .font('Helvetica-Bold')
    .text(unionName, 36, 28, {
      width: innerWidth,
      align: 'center',
    });

  doc
    .moveDown(0.5)
    .fontSize(12)
    .font('Helvetica')
    .text('Daily taxi schedule', {
      width: innerWidth,
      align: 'center',
    });

  doc.moveDown(2);

  // Main route card
  const cardTop = 120;
  doc
    .save()
    .roundedRect(36, cardTop, innerWidth, 120, 12)
    .fill('#FFF8E1')
    .restore();

  doc
    .fillColor('#000000')
    .font('Helvetica-Bold')
    .fontSize(22)
    .text(`${from} → ${to}`, 48, cardTop + 18, {
      width: innerWidth - 24,
      align: 'center',
    });

  doc
    .font('Helvetica')
    .fontSize(14)
    .text(`Date: ${dateStr}`, 48, cardTop + 60, {
      width: innerWidth - 24,
      align: 'center',
    });

  doc.text(`Time: ${timeStr}`, {
    width: innerWidth - 24,
    align: 'center',
  });

  // Driver & vehicle box
  const infoTop = cardTop + 150;
  doc
    .save()
    .roundedRect(36, infoTop, innerWidth, 80, 10)
    .fill('#E3F2FD')
    .restore();

  doc
    .fillColor('#0D47A1')
    .font('Helvetica-Bold')
    .fontSize(14)
    .text(
      driverName ? `Driver: ${driverName}` : 'Driver: —',
      48,
      infoTop + 16,
      { width: innerWidth - 24 }
    );

  if (vehicleNumber) {
    doc
      .fillColor('#0D47A1')
      .font('Helvetica')
      .fontSize(13)
      .text(`Vehicle: ${vehicleNumber}`, 48, infoTop + 40, {
        width: innerWidth - 24,
      });
  }

  // Footer note
  doc
    .fillColor('#555555')
    .fontSize(9)
    .text(
      'This poster is generated from the LuhaRide union dashboard. Share this as an image or PDF in your local groups so that passengers can easily see today\'s taxi timings.',
      48,
      doc.page.height - 72,
      {
        width: innerWidth - 24,
        align: 'center',
      }
    );

  doc.end();
});

module.exports = {
  getMyUnion,
  registerUnion,
  listUnions,
  approveUnion,
  rejectUnion,
  getPendingUnionRequests,
  approveUnionRequest,
  rejectUnionRequest,
  getUnionDrivers,
  addUnionDriver,
  getUnionRoutes,
  addUnionRoute,
  createUnionSchedulesBulk,
  getUnionSchedules,
  cancelUnionSchedule,
   getUnionSchedulePoster,
};

