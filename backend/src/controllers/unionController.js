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

  // Note: expired union_schedules are cleaned up globally by rideCleanupJob (midnight cron).
  // No lazy per-request cleanup needed here.

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
 * Update poster branding for the current union admin's union.
 * PATCH /api/union/branding
 */
const updateUnionBranding = asyncHandler(async (req, res) => {
  const { poster_header } = req.body;

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

  const headerVal = (poster_header || '').toString().trim().slice(0, 200) || null;

  await pool.query(
    `UPDATE unions SET poster_header = $1, updated_at = NOW() WHERE id = $2`,
    [headerVal, unionId]
  );

  ApiResponse.success({ poster_header: headerVal }, 'Poster branding updated').send(res);
});

// ─── Helpers for PDF drawing ──────────────────────────────────────────────────

/** Draw a filled rounded rectangle (pdfkit helper). */
function _roundedRect(doc, x, y, w, h, r, fillColor) {
  doc.save().roundedRect(x, y, w, h, r).fill(fillColor).restore();
}

/** Draw a solid rectangle (no rounding). */
function _rect(doc, x, y, w, h, fillColor) {
  doc.save().rect(x, y, w, h).fill(fillColor).restore();
}

/** Draw a horizontal rule. */
function _hRule(doc, x, y, w, strokeColor = '#E0E0E0', lw = 0.8) {
  doc.save()
    .moveTo(x, y)
    .lineTo(x + w, y)
    .strokeColor(strokeColor)
    .lineWidth(lw)
    .stroke()
    .restore();
}

/**
 * Generate a beautiful PDF ride poster for a union schedule.
 * GET /api/union/schedules/:id/poster
 */
const getUnionSchedulePoster = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Ensure approved union admin
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

  // Load schedule + driver + union details (including poster_header)
  const schedRes = await pool.query(
    `SELECT
       s.*,
       d.name          AS driver_name,
       d.vehicle_number,
       d.phone         AS driver_phone,
       u.name          AS union_name,
       u.poster_header AS poster_header
     FROM union_schedules s
     JOIN union_drivers d  ON d.id = s.union_driver_id
     JOIN unions u         ON u.id = s.union_id
     WHERE s.id = $1 AND s.union_id = $2`,
    [id, unionId]
  );
  if (schedRes.rows.length === 0) {
    throw ApiError.notFound('Schedule not found');
  }

  const s             = schedRes.rows[0];
  const from          = (s.from_location   || '').toString().toUpperCase();
  const to            = (s.to_location     || '').toString().toUpperCase();
  const driverName    = (s.driver_name     || '').toString();
  const vehicleNum    = (s.vehicle_number  || '').toString();
  const driverPhone   = (s.driver_phone    || '').toString();
  const unionName     = (s.union_name      || 'Taxi Union').toString();
  const posterHeader  = (s.poster_header   || '').toString().trim();

  const pad  = (n) => String(n).padStart(2, '0');
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const dt   = s.departure_time ? new Date(s.departure_time) : null;
  const dateStr = dt ? `${pad(dt.getDate())} ${MONTHS[dt.getMonth()]} ${dt.getFullYear()}` : '—';
  const dayStr  = dt ? dt.toLocaleDateString('en-IN', { weekday: 'long' }) : '';
  const rawH    = dt ? dt.getHours() : 0;
  const ampm    = rawH >= 12 ? 'PM' : 'AM';
  const hr12    = rawH % 12 || 12;
  const timeStr = dt ? `${pad(hr12)}:${pad(dt.getMinutes())} ${ampm}` : '—';

  // ─── File name ─────────────────────────────────────────────────────────────
  const safe  = (s) => s.replace(/[^\w]+/g, '-').slice(0, 40);
  const fname = `${safe(unionName)}-${safe(from)}-${safe(to)}-${dateStr.replace(/ /g,'-')}.pdf`;

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fname}"`);

  // ─── PDF canvas setup ──────────────────────────────────────────────────────
  const doc = new PDFDocument({ size: 'A4', margin: 0, info: {
    Title: `Ride Poster — ${unionName}`,
    Author: 'LuhaRide',
  }});
  doc.pipe(res);

  const W  = doc.page.width;   // 595.28
  const H  = doc.page.height;  // 841.89
  const ML = 32;               // left/right margin for content
  const CW = W - ML * 2;      // usable content width

  // ─── Background ────────────────────────────────────────────────────────────
  // Soft warm background for eye‑comfort
  _rect(doc, 0, 0, W, H, '#FFFDF5');

  // ─── Top accent stripe ─────────────────────────────────────────────────────
  _rect(doc, 0, 0, W, 5, '#212121');

  // ─── Header band ───────────────────────────────────────────────────────────
  const headerH = posterHeader ? 148 : 120;
  // Taxi‑style warm yellow/orange header
  _rect(doc, 0, 5, W, headerH, '#FFC107');

  let y = 16;

  // Custom blessing / deity line
  if (posterHeader) {
    // Decorative dots left & right
    const dotTxt = '  * ';
    doc.fillColor('#212121')
       .font('Helvetica-Oblique')
       .fontSize(15)
       .text(`${dotTxt}${posterHeader}${dotTxt}`, 0, y, { width: W, align: 'center' });
    y += 24;
    // Thin white separator line
    _hRule(doc, ML + 30, y, CW - 60, 'rgba(255,255,255,0.35)', 0.7);
    y += 10;
  } else {
    y = 22;
  }

  // Union name
  doc.fillColor('#212121')
     .font('Helvetica-Bold')
     .fontSize(unionName.length > 22 ? 22 : 28)
     .text(unionName.toUpperCase(), 0, y, { width: W, align: 'center' });
  y += (unionName.length > 22 ? 22 : 28) + 6;

  // Sub label
  doc.fillColor('#424242')
     .font('Helvetica')
     .fontSize(10)
     .text('TAXI UNION  -  DAILY RIDE SCHEDULE', 0, y, {
       width: W, align: 'center', characterSpacing: 1.2
     });
  y += 18;

  // Light wave bottom of header
  _rect(doc, 0, 5 + headerH - 10, W, 10, '#FFFDF5');
  // Overlay to make the bottom of header appear rounded
  _roundedRect(doc, 0, 5 + headerH - 24, W, 30, 20, '#FFFDF5');

  y = 5 + headerH + 14;

  // ─── "TODAY'S RIDE" pill label ─────────────────────────────────────────────
  const pillW = 130;
  const pillX = (W - pillW) / 2;
  _roundedRect(doc, pillX, y, pillW, 22, 11, '#212121');
  doc.fillColor('#FFC107')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text("TODAY'S RIDE", pillX, y + 6, {
       width: pillW, align: 'center', characterSpacing: 1.5
     });
  y += 36;

  // ─── Route card ────────────────────────────────────────────────────────────
  const routeCardH = 108;
  _roundedRect(doc, ML, y, CW, routeCardH, 14, '#FFF8E1');
  // Dark left accent strip
  _roundedRect(doc, ML, y, 6, routeCardH, 3, '#212121');

  const half = (CW - 20) / 2;

  // FROM label
  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('FROM', ML + 14, y + 14, { width: half, align: 'left', characterSpacing: 1.2 });

  // TO label (right side, aligned right of center arrow)
  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('TO', ML + CW / 2 + 6, y + 14, { width: half - 6, align: 'left', characterSpacing: 1.2 });

  // FROM city name
  const fromFontSize = from.length > 12 ? 20 : (from.length > 8 ? 24 : 28);
  doc.fillColor('#212121')
     .font('Helvetica-Bold')
     .fontSize(fromFontSize)
     .text(from, ML + 14, y + 30, { width: half - 10, align: 'left' });

  // Arrow indicator in centre
  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(22)
     .text('-->', ML + half + 2, y + 40, { width: 30, align: 'center' });

  // TO city name
  const toFontSize = to.length > 12 ? 20 : (to.length > 8 ? 24 : 28);
  doc.fillColor('#212121')
     .font('Helvetica-Bold')
     .fontSize(toFontSize)
     .text(to, ML + CW / 2 + 6, y + 30, { width: half - 6, align: 'left' });

  // Dashed route line
  const lineY = y + 78;
  doc.save()
     .moveTo(ML + 14, lineY)
     .lineTo(ML + CW - 14, lineY)
     .strokeColor('#FBC02D')
     .lineWidth(1.5)
     .dash(6, { space: 4 })
     .stroke()
     .restore();

  y += routeCardH + 16;

  // ─── Date & Time boxes ─────────────────────────────────────────────────────
  const dtBoxH = 76;
  const dtW    = (CW - 10) / 2;

  // Date box (soft blue)
  _roundedRect(doc, ML, y, dtW, dtBoxH, 12, '#E3F2FD');
  _roundedRect(doc, ML, y, dtW, 5, 3, '#1565C0');
  doc.fillColor('#1565C0')
     .font('Helvetica').fontSize(9)
     .text('DATE', ML, y + 14, { width: dtW, align: 'center', characterSpacing: 1.5 });
  doc.fillColor('#0D47A1')
     .font('Helvetica-Bold').fontSize(18)
     .text(dateStr, ML, y + 30, { width: dtW, align: 'center' });
  if (dayStr) {
    doc.fillColor('#1565C0')
       .font('Helvetica').fontSize(10)
       .text(dayStr, ML, y + 54, { width: dtW, align: 'center' });
  }

  // Time box (soft green)
  const tx = ML + dtW + 10;
  _roundedRect(doc, tx, y, dtW, dtBoxH, 12, '#E8F5E9');
  _roundedRect(doc, tx, y, dtW, 5, 3, '#2E7D32');
  doc.fillColor('#2E7D32')
     .font('Helvetica').fontSize(9)
     .text('DEPARTURE TIME', tx, y + 14, { width: dtW, align: 'center', characterSpacing: 1.2 });
  doc.fillColor('#1B5E20')
     .font('Helvetica-Bold').fontSize(22)
     .text(timeStr, tx, y + 28, { width: dtW, align: 'center' });

  y += dtBoxH + 16;

  // ─── Driver details card ───────────────────────────────────────────────────
  const drvBoxH = vehicleNum ? 88 : 68;
  _roundedRect(doc, ML, y, CW, drvBoxH, 12, '#FFFDE7');
  _roundedRect(doc, ML, y, 6, drvBoxH, 3, '#212121');

  doc.fillColor('#757575')
     .font('Helvetica-Bold').fontSize(9)
     .text('DRIVER', ML + 16, y + 14, { characterSpacing: 1.5 });

  doc.fillColor('#212121')
     .font('Helvetica-Bold').fontSize(20)
     .text(driverName || '—', ML + 16, y + 28, { width: CW - 30 });

  if (vehicleNum) {
    // Grey vehicle pill
    const pillVW = Math.min(180, vehicleNum.length * 11 + 40);
    _roundedRect(doc, ML + 16, y + 58, pillVW, 20, 5, '#FFF3CD');
    doc.fillColor('#424242')
       .font('Helvetica-Bold').fontSize(11)
       .text(`  Vehicle: ${vehicleNum}`, ML + 16, y + 63, { width: pillVW });
  }

  y += drvBoxH + 16;

  // ─── How to book box ───────────────────────────────────────────────────────
  const bookH = driverPhone ? 62 : 50;
  _roundedRect(doc, ML, y, CW, bookH, 12, '#EDE7F6');
  _roundedRect(doc, ML, y, 6, bookH, 3, '#4527A0');

  doc.fillColor('#4527A0')
     .font('Helvetica-Bold').fontSize(9)
     .text('BOOK THIS RIDE', ML + 16, y + 12, { characterSpacing: 1.5 });

  doc.fillColor('#311B92')
     .font('Helvetica-Bold').fontSize(13)
     .text('www.luharide.in', ML + 16, y + 28, { width: CW - 30 });

  if (driverPhone) {
    doc.fillColor('#5E35B1')
       .font('Helvetica').fontSize(11)
       .text(`Call driver: ${driverPhone}`, ML + 16, y + 46, { width: CW - 30 });
  }

  y += bookH + 16;

  // ─── Info note ─────────────────────────────────────────────────────────────
  _hRule(doc, ML, y, CW, '#E0E0E0');
  y += 12;
  doc.fillColor('#888888')
     .font('Helvetica').fontSize(9)
     .text(
       'Share this poster on WhatsApp, Facebook or any local group so passengers can see today\'s taxi timing.',
       ML, y, { width: CW, align: 'center' }
     );

  // ─── Footer band ───────────────────────────────────────────────────────────
  const footerH  = 64;
  const footerY  = H - footerH;
  _rect(doc, 0, footerY, W, footerH, '#212121');
  _rect(doc, 0, footerY, W, 3, '#FFC107');

  doc.fillColor('#FFFFFF')
     .font('Helvetica-Bold').fontSize(13)
     .text('Find & book this ride on  LUHARIDE.IN', 0, footerY + 12, {
       width: W, align: 'center'
     });

  doc.fillColor('rgba(255,255,255,0.75)')
     .font('Helvetica').fontSize(10)
     .text(
       'Yeh ride luharide.in par bhi milegi  |  Abhi book karein',
       0, footerY + 34,
       { width: W, align: 'center' }
     );

  doc.end();
});

// ─── Combined poster helpers ──────────────────────────────────────────────────

/** Draw a filled rect (no rounding). */
function _fillRect(doc, x, y, w, h, color) {
  doc.save().rect(x, y, w, h).fill(color).restore();
}

/** Draw a rounded filled rect. */
function _fillRounded(doc, x, y, w, h, r, color) {
  doc.save().roundedRect(x, y, w, h, r).fill(color).restore();
}

/** Draw a horizontal rule. */
function _hLine(doc, x, y, w, color = '#E0E0E0', lw = 0.6) {
  doc.save().moveTo(x, y).lineTo(x + w, y)
    .strokeColor(color).lineWidth(lw).stroke().restore();
}

/** Draw a vertical rule. */
function _vLine(doc, x, y, h, color = '#E0E0E0', lw = 0.6) {
  doc.save().moveTo(x, y).lineTo(x, y + h)
    .strokeColor(color).lineWidth(lw).stroke().restore();
}

/** Draw table header row. Returns bottom Y. */
function _tableHeader(doc, x, y, cols, rowH) {
  const totalW = cols.reduce((s, c) => s + c.w, 0);
  _fillRect(doc, x, y, totalW, rowH, '#FF6B00');
  let cx = x;
  for (const col of cols) {
    doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(9)
      .text(col.label, cx + 5, y + (rowH - 9) / 2 + 1,
        { width: col.w - 10, align: col.align || 'center' });
    cx += col.w;
  }
  return y + rowH;
}

/** Draw one table data row. Returns bottom Y. */
function _tableRow(doc, x, y, cols, values, rowH, evenRow) {
  const totalW = cols.reduce((s, c) => s + c.w, 0);
  _fillRect(doc, x, y, totalW, rowH, evenRow ? '#FFF8F2' : '#FFFFFF');
  let cx = x;
  for (let i = 0; i < cols.length; i++) {
    doc.fillColor('#1A1A1A').font(i === 0 ? 'Helvetica-Bold' : 'Helvetica').fontSize(10)
      .text(String(values[i] ?? '—'), cx + 5, y + (rowH - 10) / 2 + 1,
        { width: cols[i].w - 10, align: cols[i].align || 'left', lineBreak: false });
    cx += cols[i].w;
  }
  _hLine(doc, x, y + rowH, totalW, '#F0E0D0');
  return y + rowH;
}

/** Draw full table border. */
function _tableBorder(doc, x, y, totalW, totalH) {
  doc.save().rect(x, y, totalW, totalH)
    .strokeColor('#FF6B00').lineWidth(1.2).stroke().restore();
  // Vertical column dividers drawn inside rows already
}

/**
 * Generate a combined PDF poster for multiple union schedules (all on one page).
 * GET /api/union/schedules/poster-combined?ids=id1,id2,...
 */
const getUnionCombinedPoster = asyncHandler(async (req, res) => {
  const rawIds = (req.query.ids || '').toString().trim();
  if (!rawIds) throw ApiError.badRequest('No schedule IDs provided');

  const ids = rawIds.split(',').map(s => s.trim()).filter(Boolean).slice(0, 50);
  if (ids.length === 0) throw ApiError.badRequest('No valid IDs');

  // Verify admin belongs to an approved union
  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved' LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) throw ApiError.forbidden('No approved union');
  const unionId = resUnion.rows[0].union_id;

  // Load all requested schedules + union branding
  const placeholders = ids.map((_, i) => `$${i + 2}`).join(',');
  const schedRes = await pool.query(
    `SELECT
       s.id, s.from_location, s.to_location, s.departure_time, s.status,
       d.name AS driver_name, d.vehicle_number, d.phone AS driver_phone,
       u.name AS union_name, u.poster_header
     FROM union_schedules s
     JOIN union_drivers d ON d.id = s.union_driver_id
     JOIN unions u        ON u.id = s.union_id
     WHERE s.union_id = $1 AND s.id IN (${placeholders})
     ORDER BY s.from_location, s.to_location, s.departure_time ASC`,
    [unionId, ...ids]
  );

  if (schedRes.rows.length === 0) throw ApiError.notFound('No schedules found');

  const rows        = schedRes.rows;
  const unionName   = (rows[0].union_name || 'Taxi Union').toString();
  const posterHdr   = (rows[0].poster_header || '').toString().trim();

  // Determine date label from first schedule
  const pad  = n => String(n).padStart(2, '0');
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const DAYS   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  const firstDt = rows[0].departure_time ? new Date(rows[0].departure_time) : new Date();
  const dateLabel = `${DAYS[firstDt.getDay()]}, ${pad(firstDt.getDate())} ${MONTHS[firstDt.getMonth()]} ${firstDt.getFullYear()}`;

  // Group schedules by route key "FROM → TO"
  const groups = new Map();
  for (const r of rows) {
    const key = `${(r.from_location||'').toUpperCase()} → ${(r.to_location||'').toUpperCase()}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(r);
  }

  // ─── PDF setup ─────────────────────────────────────────────────────────────
  const safe = s => s.replace(/[^\w]+/g,'-').slice(0,40);
  const fname = `${safe(unionName)}-schedule-${dateLabel.replace(/[, ]+/g,'-')}.pdf`;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fname}"`);

  const doc = new PDFDocument({ size: 'A4', margin: 0, info: { Title: `${unionName} - Daily Schedule`, Author: 'LuhaRide' } });
  doc.pipe(res);

  const W   = doc.page.width;
  const H   = doc.page.height;
  const ML  = 28;
  const CW  = W - ML * 2;
  const FOOTER_H = 58;

  // ── Background ─────────────────────────────────────────────────────────────
  _fillRect(doc, 0, 0, W, H, '#FFFDF5');

  // ── Top accent ─────────────────────────────────────────────────────────────
  _fillRect(doc, 0, 0, W, 5, '#212121');

  // ── Header band ────────────────────────────────────────────────────────────
  const headerH = posterHdr ? 128 : 100;
  _fillRect(doc, 0, 5, W, headerH, '#FFC107');

  let y = 16;
  if (posterHdr) {
    doc.fillColor('#212121').font('Helvetica-Oblique').fontSize(13)
      .text(`  *  ${posterHdr}  *`, 0, y, { width: W, align: 'center' });
    y += 22;
    _hLine(doc, ML + 40, y, CW - 80, 'rgba(255,255,255,0.3)');
    y += 8;
  } else {
    y = 20;
  }

  // Union name
  const unFontSize = unionName.length > 26 ? 20 : (unionName.length > 18 ? 24 : 28);
  doc.fillColor('#212121').font('Helvetica-Bold').fontSize(unFontSize)
    .text(unionName.toUpperCase(), 0, y, { width: W, align: 'center' });
  y += unFontSize + 5;

  // Date + subtitle
  doc.fillColor('#424242').font('Helvetica').fontSize(10)
    .text(`DAILY RIDE SCHEDULE  —  ${dateLabel.toUpperCase()}`, 0, y,
      { width: W, align: 'center', characterSpacing: 0.8 });

  y = 5 + headerH + 16;

  // ── Route count badge ───────────────────────────────────────────────────────
  const badgeTxt = `${rows.length} ride${rows.length > 1 ? 's' : ''}  across  ${groups.size} route${groups.size > 1 ? 's' : ''}`;
  const badgeW   = 220;
  _fillRounded(doc, (W - badgeW) / 2, y, badgeW, 22, 11, '#212121');
  doc.fillColor('#FFC107').font('Helvetica-Bold').fontSize(9)
    .text(badgeTxt, (W - badgeW) / 2, y + 6, { width: badgeW, align: 'center' });
  y += 36;

  // ── Column definitions ─────────────────────────────────────────────────────
  const COL_NO    = { label: 'No.',     w: 34,  align: 'center' };
  const COL_TIME  = { label: 'Time',    w: 76,  align: 'center' };
  const COL_DRV   = { label: 'Driver',  w: 200, align: 'left'   };
  const COL_VEH   = { label: 'Vehicle', w: 110, align: 'center' };
  const COL_PHONE = {
    label: 'Phone',
    w: CW - 34 - 76 - 200 - 110,
    align: 'center',
  };
  const COLS      = [COL_NO, COL_TIME, COL_DRV, COL_VEH, COL_PHONE];
  const TOTAL_W  = COLS.reduce((s, c) => s + c.w, 0);
  // Slightly shrink row height when there are many rides so most schedules fit on one page.
  const ROW_H    = rows.length > 20 ? 20 : 24;
  const HDR_H    = 22;

  // Route color palette (softer, taxi‑inspired)
  const ROUTE_COLORS = ['#FFC107','#FFB300','#F9A825','#F57F17','#0288D1','#43A047'];
  let colorIdx = 0;

  // ── For each route group, draw a section ───────────────────────────────────
  for (const [routeKey, schedules] of groups) {
    const sectionH = HDR_H + 8 + ROW_H + schedules.length * ROW_H + 20;
    // Page break if needed
    if (y + sectionH > H - FOOTER_H - 20) {
      doc.addPage({ size: 'A4', margin: 0 });
      _fillRect(doc, 0, 0, W, H, '#FAFAFA');
      y = 20;
    }

    const accentColor = ROUTE_COLORS[colorIdx % ROUTE_COLORS.length];
    colorIdx++;

    // Section header pill
    _fillRounded(doc, ML, y, TOTAL_W, HDR_H, 6, accentColor);
    // Route title
    doc.fillColor('#212121').font('Helvetica-Bold').fontSize(11)
      .text(`  ${routeKey}`, ML + 8, y + (HDR_H - 11) / 2 + 1,
        { width: TOTAL_W - 70, lineBreak: false });
    const cnt = schedules.length;
    const cntTxt = `${cnt} ride${cnt > 1 ? 's' : ''}`;
    doc.fillColor('#212121').font('Helvetica').fontSize(9)
      .text(cntTxt, ML, y + (HDR_H - 9) / 2 + 1,
        { width: TOTAL_W - 8, align: 'right' });
    y += HDR_H + 4;

    // Table header
    const tableStartY = y;
    y = _tableHeader(doc, ML, y, COLS, ROW_H);

    // Table rows
    for (let i = 0; i < schedules.length; i++) {
      const s   = schedules[i];
      const dt  = s.departure_time ? new Date(s.departure_time) : null;
      const rawH = dt ? dt.getHours() : 0;
      const ampm = rawH >= 12 ? 'PM' : 'AM';
      const hr12 = rawH % 12 || 12;
      const timeStr = dt ? `${pad(hr12)}:${pad(dt.getMinutes())} ${ampm}` : '—';

      y = _tableRow(
        doc,
        ML,
        y,
        COLS,
        [
          pad(i + 1),
          timeStr,
          s.driver_name || '—',
          s.vehicle_number || '—',
          s.driver_phone || '—',
        ],
        ROW_H,
        i % 2 === 0
      );
    }

    // Table outer border
    _tableBorder(doc, ML, tableStartY, TOTAL_W, ROW_H + schedules.length * ROW_H);

    // Vertical column dividers
    let divX = ML;
    for (let i = 0; i < COLS.length - 1; i++) {
      divX += COLS[i].w;
      _vLine(doc, divX, tableStartY, ROW_H + schedules.length * ROW_H, '#F0D0C0', 0.5);
    }

    y += 16;
  }

  // ── Footer band ─────────────────────────────────────────────────────────────
  const footerY = H - FOOTER_H;
  _fillRect(doc, 0, footerY, W, FOOTER_H, '#212121');
  _fillRect(doc, 0, footerY, W, 3, '#FFC107');

  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(13)
    .text('Find & book these rides on  LUHARIDE.IN', 0, footerY + 11,
      { width: W, align: 'center' });
  doc.fillColor('rgba(255,255,255,0.75)').font('Helvetica').fontSize(10)
    .text('Yeh ride luharide.in par bhi milegi  |  Abhi book karein', 0, footerY + 32,
      { width: W, align: 'center' });

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
  getUnionCombinedPoster,
  updateUnionBranding,
};

