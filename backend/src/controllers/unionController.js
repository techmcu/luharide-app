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
 * Clean union display name for posters so garbage tokens (like "@$by>")
 * or control characters do not appear. Keeps words that contain at least
 * one English or Hindi letter and normalizes spaces.
 */
function cleanUnionName(raw) {
  if (!raw) return 'Taxi Union';
  let name = String(raw).trim();
  if (!name) return 'Taxi Union';

  // Remove control characters
  name = name.replace(/[\x00-\x1F\x7F]/g, '');

  // Drop tokens that have no letters (English or Devanagari) – e.g. "@$by>"
  const tokens = name
    .split(/\s+/)
    .filter((t) => /[A-Za-z\u0900-\u097F]/.test(t));
  if (tokens.length > 0) {
    name = tokens.join(' ');
  }

  // Collapse multiple spaces
  name = name.replace(/\s+/g, ' ').trim();

  // Fallback if everything got stripped
  if (!name) return 'Taxi Union';

  return name;
}

/**
 * Clean poster header for drawing on PDFs.
 * - removes control chars
 * - trims extra spaces
 * Keeps normal Hindi/English text intact.
 */
function cleanPosterHeader(raw) {
  if (!raw) return '';
  let text = String(raw);
  // Remove control characters that can break PDF rendering
  text = text.replace(/[\x00-\x1F\x7F]/g, '');
  // Normalize whitespace (TextField is usually single-line anyway)
  text = text.replace(/\s+/g, ' ').trim();
  return text;
}

/**
 * Optional small custom text for poster corners/sides.
 */
function cleanPosterCustomText(raw) {
  if (!raw) return '';
  return String(raw)
    .replace(/[\x00-\x1F\x7F]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 120);
}

function getPosterTheme(themeRaw) {
  const theme = (themeRaw || 'saffron').toString().trim().toLowerCase();
  const themes = {
    saffron: { headerBg: '#FFC107', topStripe: '#212121', text: '#212121', subText: '#424242' },
    sky: { headerBg: '#B3E5FC', topStripe: '#1F2937', text: '#0F172A', subText: '#334155' },
    mint: { headerBg: '#C8E6C9', topStripe: '#1F2937', text: '#1B4332', subText: '#2D6A4F' },
    rose: { headerBg: '#F8BBD0', topStripe: '#1F2937', text: '#3F1D2E', subText: '#5B2A42' },
  };
  return themes[theme] ? theme : 'saffron';
}

function getPosterThemeColors(themeRaw) {
  const theme = getPosterTheme(themeRaw);
  const palette = {
    saffron: { headerBg: '#FFC107', topStripe: '#212121', text: '#212121', subText: '#424242' },
    sky: { headerBg: '#B3E5FC', topStripe: '#1F2937', text: '#0F172A', subText: '#334155' },
    mint: { headerBg: '#C8E6C9', topStripe: '#1F2937', text: '#1B4332', subText: '#2D6A4F' },
    rose: { headerBg: '#F8BBD0', topStripe: '#1F2937', text: '#3F1D2E', subText: '#5B2A42' },
  };
  return palette[theme];
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

  // Self-heal: if union is approved but user role wasn't updated, fix it now.
  // This repairs data inconsistencies from older approval paths.
  if (status === 'approved' && req.user.role !== 'union_admin') {
    await pool.query(
      `UPDATE users SET role = 'union_admin' WHERE id = $1 AND role <> 'union_admin'`,
      [userId]
    );
    logger.info(`Auto-fixed role to union_admin for user ${userId} (union ${union.id} is approved)`);
  }

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
       usr.name   AS applicant_name,
       usr.email  AS applicant_email,
       usr.phone  AS applicant_phone
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
/** Sanitize document URL: trim, length cap, http(s) only */
function sanitizeDocumentUrl(raw) {
  if (raw == null || raw === '') return null;
  const s = String(raw).trim();
  if (s.length > 2048) return null;
  if (/^https?:\/\//i.test(s)) return s;
  // API-relative paths from our upload endpoints
  if (s.startsWith('/uploads/')) return s;
  return null;
}

const registerUnion = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const {
    name,
    location,
    contact_phone,
    contact_email,
    owner_name,
    owner_aadhaar_url,
    owner_aadhaar_front_url,
    owner_aadhaar_back_url,
    office_photo_url,
    union_photo_url,
    union_driver_list_photo_url,
    leader_driving_license_front_url,
    leader_driving_license_back_url,
    owner_vehicle_rc_url,
    owner_vehicle_rc_front_url,
    owner_vehicle_rc_back_url,
    union_share_notes,
  } = req.body;

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

  const userDv = await pool.query(
    'SELECT driver_verification_status FROM users WHERE id = $1',
    [userId]
  );
  const dvs = userDv.rows[0]?.driver_verification_status;
  if (dvs === 'pending' || dvs === 'approved') {
    throw ApiError.badRequest(
      'Independent driver verification is already pending or approved. You cannot register a taxi union on this account.'
    );
  }

  const notesRaw = union_share_notes != null ? String(union_share_notes).trim() : '';
  const notesVal = notesRaw.length > 0 ? notesRaw.slice(0, 500) : null;

  let insertRes;
  try {
    insertRes = await pool.query(
      `INSERT INTO unions (
         name,
         address,
         contact_phone,
         contact_email,
         is_active,
         status,
         owner_name,
         owner_aadhaar_url,
         owner_aadhaar_front_url,
         owner_aadhaar_back_url,
         office_photo_url,
         union_photo_url,
         union_driver_list_photo_url,
         leader_driving_license_front_url,
         leader_driving_license_back_url,
         owner_vehicle_rc_url,
         owner_vehicle_rc_front_url,
         owner_vehicle_rc_back_url,
         union_share_notes
       )
      VALUES ($1, $2, $3, $4, FALSE, 'pending', $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
       RETURNING *`,
      [
        String(name).trim(),
        location || null,
        contact_phone || null,
        contact_email || null,
        owner_name ? String(owner_name).trim() : null,
        sanitizeDocumentUrl(owner_aadhaar_url),
        sanitizeDocumentUrl(owner_aadhaar_front_url),
        sanitizeDocumentUrl(owner_aadhaar_back_url),
        sanitizeDocumentUrl(office_photo_url),
        sanitizeDocumentUrl(union_photo_url),
        sanitizeDocumentUrl(union_driver_list_photo_url),
        sanitizeDocumentUrl(leader_driving_license_front_url),
        sanitizeDocumentUrl(leader_driving_license_back_url),
        sanitizeDocumentUrl(owner_vehicle_rc_url),
        sanitizeDocumentUrl(owner_vehicle_rc_front_url),
        sanitizeDocumentUrl(owner_vehicle_rc_back_url),
        notesVal,
      ]
    );
  } catch (e) {
    if (e.code === '42703') {
      insertRes = await pool.query(
        `INSERT INTO unions (
           name,
           address,
           contact_phone,
           contact_email,
           is_active,
           status,
           owner_name,
           owner_aadhaar_url,
           office_photo_url,
          owner_vehicle_rc_url,
          union_share_notes
         )
         VALUES ($1, $2, $3, $4, FALSE, 'pending', $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          String(name).trim(),
          location || null,
          contact_phone || null,
          contact_email || null,
          owner_name ? String(owner_name).trim() : null,
          sanitizeDocumentUrl(owner_aadhaar_url),
          sanitizeDocumentUrl(office_photo_url),
          sanitizeDocumentUrl(owner_vehicle_rc_url),
          notesVal,
        ]
      );
    } else {
      throw e;
    }
  }

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

  // Queue policy:
  // - show only rides for "today + next 10 days" (10 calendar days total)
  // - if departure_time has passed, show as "completed" in the UI
  // - cancel is allowed only within 1 hour of creation and before departure_time
  //   (backend returns `can_cancel` boolean for UI)
  if (scope === 'recent') {
    // UI will no longer display a separate history section; keep endpoint safe.
    return ApiResponse.success({ schedules: [], count: 0 }, 'Union schedules retrieved').send(res);
  }

  const result = await pool.query(
    `
    SELECT
      -- UI status (computed)
      CASE
        WHEN s.status = 'scheduled' AND s.departure_time <= NOW()
          THEN 'completed'
        ELSE s.status
      END AS status,
      s.id,
      s.union_id,
      s.union_driver_id,
      s.from_location,
      s.to_location,
      s.departure_time,
      s.created_at,
      d.name AS driver_name,
      d.vehicle_number,
      d.phone AS driver_phone,
      d.whatsapp_number,
      -- UI cancel eligibility
      (
        s.status = 'scheduled'
        AND s.departure_time > NOW()
        AND s.created_at >= NOW() - INTERVAL '1 hour'
      ) AS can_cancel
    FROM union_schedules s
    JOIN union_drivers d ON d.id = s.union_driver_id
    WHERE s.union_id = $1
      AND s.departure_time >= CURRENT_DATE::timestamp
      AND s.departure_time < (CURRENT_DATE::timestamp + INTERVAL '10 days')
      AND s.status IN ('scheduled','completed')
    ORDER BY s.departure_time ASC
    `,
    [unionId]
  );

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

  // Single fetch: status + time eligibility
  const schedRes = await pool.query(
    `SELECT
       status,
       departure_time,
       created_at,
       (
         status = 'scheduled'
         AND departure_time > NOW()
         AND created_at >= NOW() - INTERVAL '1 hour'
       ) AS can_cancel
     FROM union_schedules
     WHERE id = $1 AND union_id = $2`,
    [id, unionId]
  );
  // Idempotency: if already deleted/removed, treat as success.
  if (schedRes.rows.length === 0) {
    return ApiResponse.success({ id, status: 'cancelled' }, 'Ride already removed').send(res);
  }

  const currentStatus = schedRes.rows[0].status;
  const canCancel = !!schedRes.rows[0].can_cancel;

  if (!canCancel) {
    // Don’t leak exact policy details; keep message user-friendly.
    throw ApiError.badRequest('This ride can be cancelled only within 1 hour of creation and before departure time');
  }

  // DELETE (hard remove) to satisfy "remove from database" requirement.
  const delRes = await pool.query(
    `DELETE FROM union_schedules
     WHERE id = $1
       AND union_id = $2
       AND status = 'scheduled'
       AND departure_time > NOW()
       AND created_at >= NOW() - INTERVAL '1 hour'
     RETURNING id`,
    [id, unionId]
  );

  if (delRes.rowCount === 0) {
    // Race: eligibility might have changed between SELECT and DELETE.
    throw ApiError.badRequest('This ride can no longer be cancelled');
  }

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
  const {
    poster_header,
    poster_custom_text,
    poster_custom_text_position,
    poster_layout_type,
    poster_theme,
  } = req.body;

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

  const headerVal = cleanPosterHeader(poster_header).slice(0, 200) || null;
  const customTextVal = cleanPosterCustomText(poster_custom_text) || null;
  const positionRaw = (poster_custom_text_position || '').toString().trim().toLowerCase();
  const layoutRaw = (poster_layout_type || '').toString().trim().toLowerCase();

  const allowedPositions = new Set(['left', 'right']);
  const allowedLayouts = new Set(['classic', 'compact']);
  const themeType = getPosterTheme(poster_theme);
  const customTextPosition =
    allowedPositions.has(positionRaw)
      ? positionRaw
      : customTextVal
        ? 'right'
        : null;
  const layoutType = allowedLayouts.has(layoutRaw) ? layoutRaw : 'classic';

  await pool.query(
    `UPDATE unions
     SET poster_header = $1,
         poster_custom_text = $2,
         poster_custom_text_position = $3,
         poster_layout_type = $4,
         poster_theme = $5,
         updated_at = NOW()
     WHERE id = $6`,
    [headerVal, customTextVal, customTextPosition, layoutType, themeType, unionId]
  );

  ApiResponse.success(
    {
      poster_header: headerVal,
      poster_custom_text: customTextVal,
      poster_custom_text_position: customTextPosition,
      poster_layout_type: layoutType,
      poster_theme: themeType,
    },
    'Poster branding updated'
  ).send(res);
});

/**
 * Update union KYC documents / notes (approved union admin only).
 * PATCH /api/union/me/documents
 */
const updateUnionDocuments = asyncHandler(async (req, res) => {
  const {
    owner_name,
    owner_aadhaar_url,
    office_photo_url,
    owner_vehicle_rc_url,
    union_share_notes,
  } = req.body;

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

  const fields = [];
  const values = [];
  let p = 1;

  if (owner_name !== undefined) {
    const v = owner_name != null ? String(owner_name).trim().slice(0, 200) : null;
    fields.push(`owner_name = $${p++}`);
    values.push(v || null);
  }
  if (owner_aadhaar_url !== undefined) {
    fields.push(`owner_aadhaar_url = $${p++}`);
    values.push(sanitizeDocumentUrl(owner_aadhaar_url));
  }
  if (office_photo_url !== undefined) {
    fields.push(`office_photo_url = $${p++}`);
    values.push(sanitizeDocumentUrl(office_photo_url));
  }
  if (owner_vehicle_rc_url !== undefined) {
    fields.push(`owner_vehicle_rc_url = $${p++}`);
    values.push(sanitizeDocumentUrl(owner_vehicle_rc_url));
  }
  if (union_share_notes !== undefined) {
    const n = union_share_notes != null ? String(union_share_notes).trim().slice(0, 500) : '';
    fields.push(`union_share_notes = $${p++}`);
    values.push(n.length ? n : null);
  }

  if (fields.length === 0) {
    throw ApiError.badRequest('No fields to update');
  }

  fields.push('updated_at = NOW()');
  values.push(unionId);

  const out = await pool.query(
    `UPDATE unions SET ${fields.join(', ')} WHERE id = $${p} RETURNING *`,
    values
  );
  ApiResponse.success({ union: out.rows[0] }, 'Union documents updated').send(res);
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

  // Load schedule + driver + union details (poster settings included)
  const schedRes = await pool.query(
    `SELECT
       s.*,
       d.name          AS driver_name,
       d.vehicle_number,
       d.phone         AS driver_phone,
       u.name          AS union_name,
       u.poster_header AS poster_header,
       u.poster_custom_text AS poster_custom_text,
       u.poster_custom_text_position AS poster_custom_text_position,
       u.poster_layout_type AS poster_layout_type,
       u.poster_theme AS poster_theme
     FROM union_schedules s
     JOIN union_drivers d  ON d.id = s.union_driver_id
     JOIN unions u         ON u.id = s.union_id
     WHERE s.id = $1 AND s.union_id = $2`,
    [id, unionId]
  );
  if (schedRes.rows.length === 0) {
    throw ApiError.notFound('Schedule not found');
  }

  const s           = schedRes.rows[0];
  const from        = (s.from_location   || '').toString().toUpperCase();
  const to          = (s.to_location     || '').toString().toUpperCase();
  const driverName  = (s.driver_name     || '').toString();
  const vehicleNum  = (s.vehicle_number  || '').toString();
  const driverPhone = (s.driver_phone    || '').toString();
  const posterHeader = cleanPosterHeader(s.poster_header);
  const posterCustomText = cleanPosterCustomText(s.poster_custom_text);
  const posterCustomTextPosition = (s.poster_custom_text_position || 'right').toString().toLowerCase();
  const posterLayoutType = (s.poster_layout_type || 'classic').toString().toLowerCase();
  const posterTheme = getPosterTheme(s.poster_theme);
  const themeColors = getPosterThemeColors(posterTheme);
  logger.info(`PDF posterHeader length=${posterHeader.length} value="${posterHeader.slice(0, 80)}"`);
  const posterTitle = posterHeader || 'DAILY RIDE SCHEDULE';

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
  const fname = `union-poster-${safe(from)}-${safe(to)}-${dateStr.replace(/ /g,'-')}.pdf`;

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fname}"`);

  // ─── PDF canvas setup ──────────────────────────────────────────────────────
  const doc = new PDFDocument({ size: 'A4', margin: 0, info: {
    Title: `Ride Poster — ${posterTitle}`,
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
  _rect(doc, 0, 0, W, 5, themeColors.topStripe);

  // ─── Header band (manual poster title only) — compact area so route/data starts higher
  const compact = posterLayoutType === 'compact';
  const headerH = compact ? 108 : 124;
  _rect(doc, 0, 5, W, headerH, themeColors.headerBg);

  let y = 18;
  // Manual poster title — only big element at top.
  const unLen = posterTitle.length;
  const unFontSize = unLen > 26 ? 20 : (unLen > 18 ? 24 : 28);
  doc.fillColor(themeColors.text)
     .font('Helvetica-Bold')
     .fontSize(unFontSize)
     .text(posterTitle.toUpperCase(), 0, y, { width: W, align: 'center' });
  y += unFontSize + 6;

  // Sub label
  doc.fillColor(themeColors.subText)
     .font('Helvetica')
     .fontSize(9)
     .text('रोज़ाना टैक्सी समय', 0, y, {
       width: W, align: 'center', characterSpacing: 1.0
     });
  y += 12;

  // Light wave bottom of header
  _rect(doc, 0, 5 + headerH - 8, W, 8, '#FFFDF5');
  _roundedRect(doc, 0, 5 + headerH - 18, W, 22, 14, '#FFFDF5');

  if (posterCustomText && posterCustomTextPosition === 'left') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, 14, 5 + (headerH / 2) - 5, { width: 170, align: 'left' });
  } else if (posterCustomText && posterCustomTextPosition === 'right') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, W - 184, 5 + (headerH / 2) - 5, { width: 170, align: 'right' });
  }

  y = 5 + headerH + 6;

  // ─── Today pill label (Hindi) ─────────────────────────────────────────────
  const pillW = 130;
  const pillX = (W - pillW) / 2;
  _roundedRect(doc, pillX, y, pillW, 22, 11, '#212121');
  doc.fillColor('#FFC107')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('आज की सवारी', pillX, y + 6, {
       width: pillW, align: 'center', characterSpacing: 1.5
     });
  y += 36;

  // ─── Route card ────────────────────────────────────────────────────────────
  const routeCardH = 108;
  _roundedRect(doc, ML, y, CW, routeCardH, 14, '#FFF8E1');
  // Dark left accent strip
  _roundedRect(doc, ML, y, 6, routeCardH, 3, '#212121');

  const half = (CW - 20) / 2;

  // FROM label (Hindi)
  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('से', ML + 14, y + 14, { width: half, align: 'left', characterSpacing: 1.2 });

  // TO label (right side, aligned right of center arrow) (Hindi)
  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('तक', ML + CW / 2 + 6, y + 14, { width: half - 6, align: 'left', characterSpacing: 1.2 });

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

  // Date box (soft blue) - label in Hindi
  _roundedRect(doc, ML, y, dtW, dtBoxH, 12, '#E3F2FD');
  _roundedRect(doc, ML, y, dtW, 5, 3, '#1565C0');
  doc.fillColor('#1565C0')
     .font('Helvetica').fontSize(9)
     .text('तारीख', ML, y + 14, { width: dtW, align: 'center', characterSpacing: 1.5 });
  doc.fillColor('#0D47A1')
     .font('Helvetica-Bold').fontSize(18)
     .text(dateStr, ML, y + 30, { width: dtW, align: 'center' });
  if (dayStr) {
    doc.fillColor('#1565C0')
       .font('Helvetica').fontSize(10)
       .text(dayStr, ML, y + 54, { width: dtW, align: 'center' });
  }

  // Time box (soft green) - label in Hindi
  const tx = ML + dtW + 10;
  _roundedRect(doc, tx, y, dtW, dtBoxH, 12, '#E8F5E9');
  _roundedRect(doc, tx, y, dtW, 5, 3, '#2E7D32');
  doc.fillColor('#2E7D32')
     .font('Helvetica').fontSize(9)
     .text('रवाना होने का समय', tx, y + 14, { width: dtW, align: 'center', characterSpacing: 1.2 });
  doc.fillColor('#1B5E20')
     .font('Helvetica-Bold').fontSize(22)
     .text(timeStr, tx, y + 28, { width: dtW, align: 'center' });

  y += dtBoxH + 16;

  // ─── Driver details card (name removed; vehicle only) ───────────────────────
  if (vehicleNum) {
    const drvBoxH = 50;
    _roundedRect(doc, ML, y, CW, drvBoxH, 12, '#FFFDE7');
    _roundedRect(doc, ML, y, 6, drvBoxH, 3, '#212121');
    const pillVW = Math.min(200, vehicleNum.length * 11 + 40);
    _roundedRect(doc, ML + 16, y + 14, pillVW, 20, 5, '#FFF3CD');
    doc.fillColor('#424242')
       .font('Helvetica-Bold').fontSize(11)
       .text(`  Vehicle: ${vehicleNum}`, ML + 16, y + 19, { width: pillVW });
    y += drvBoxH + 16;
  }

  // ─── How to book box (Hindi heading, domain English) ──────────────────────
  const bookH = driverPhone ? 62 : 50;
  _roundedRect(doc, ML, y, CW, bookH, 12, '#EDE7F6');
  _roundedRect(doc, ML, y, 6, bookH, 3, '#4527A0');

  doc.fillColor('#4527A0')
     .font('Helvetica-Bold').fontSize(9)
     .text('इस सवारी को बुक करें', ML + 16, y + 12, { characterSpacing: 1.5 });

  doc.fillColor('#311B92')
     .font('Helvetica-Bold').fontSize(13)
     .text('www.luharide.in', ML + 16, y + 28, { width: CW - 30 });

  if (driverPhone) {
    doc.fillColor('#5E35B1')
       .font('Helvetica').fontSize(11)
       .text(`Call driver: ${driverPhone}`, ML + 16, y + 46, { width: CW - 30 });
  }

  y += bookH + 16;

  // ─── Info note (Hindi, simple, luharide.in correct spelling) ──────────────
  _hRule(doc, ML, y, CW, '#E0E0E0');
  y += 12;
  doc.fillColor('#888888')
     .font('Helvetica').fontSize(9)
     .text(
       'सवारी बुक करने के लिए luharide.in पर जाएं। यह पोस्टर WhatsApp या लोकल ग्रुप में शेयर करें।',
       ML, y, { width: CW, align: 'center' }
     );

  // ─── Footer band (Hindi + domain) ──────────────────────────────────────────
  const footerH  = 64;
  const footerY  = H - footerH;
  _rect(doc, 0, footerY, W, footerH, '#212121');
  _rect(doc, 0, footerY, W, 3, '#FFC107');

  doc.fillColor('#FFFFFF')
     .font('Helvetica-Bold').fontSize(12)
     .text('सवारी बुक करने या खोजने के लिए luharide.in पर जाएं', 0, footerY + 20, {
       width: W, align: 'center'
     });

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

  // Load all requested schedules + union branding/settings
  const placeholders = ids.map((_, i) => `$${i + 2}`).join(',');
  const schedRes = await pool.query(
    `SELECT
       s.id, s.from_location, s.to_location, s.departure_time, s.status,
       d.name AS driver_name, d.vehicle_number, d.phone AS driver_phone,
       u.name AS union_name, u.poster_header,
       u.poster_custom_text, u.poster_custom_text_position, u.poster_layout_type, u.poster_theme
     FROM union_schedules s
     JOIN union_drivers d ON d.id = s.union_driver_id
     JOIN unions u        ON u.id = s.union_id
     WHERE s.union_id = $1 AND s.id IN (${placeholders})
     ORDER BY s.from_location, s.to_location, s.departure_time ASC`,
    [unionId, ...ids]
  );

  if (schedRes.rows.length === 0) throw ApiError.notFound('No schedules found');

  const rows      = schedRes.rows;
  const posterTitle = cleanPosterHeader(rows[0].poster_header) || 'DAILY RIDE SCHEDULE';
  const posterHeader = cleanPosterHeader(rows[0].poster_header);
  const posterCustomText = cleanPosterCustomText(rows[0].poster_custom_text);
  const posterCustomTextPosition = (rows[0].poster_custom_text_position || 'right').toString().toLowerCase();
  const posterLayoutType = (rows[0].poster_layout_type || 'classic').toString().toLowerCase();
  const posterTheme = getPosterTheme(rows[0].poster_theme);
  const themeColors = getPosterThemeColors(posterTheme);
  logger.info(`Combined PDF posterHeader length=${posterHeader.length} value="${posterHeader.slice(0, 80)}"`);

  // Determine date label from first schedule
  const pad  = n => String(n).padStart(2, '0');
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const DAYS   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  // Show year everywhere so posters don't look stale when forwarded later.
  const formatDateShort = (dt) => `${pad(dt.getDate())} ${MONTHS[dt.getMonth()]} ${dt.getFullYear()}`;
  const formatDateFull  = (dt) => `${DAYS[dt.getDay()]}, ${pad(dt.getDate())} ${MONTHS[dt.getMonth()]} ${dt.getFullYear()}`;

  const departureDates = rows
    .map((r) => (r.departure_time ? new Date(r.departure_time) : null))
    .filter(Boolean);

  departureDates.sort((a, b) => a.getTime() - b.getTime());
  const firstDt = departureDates.length ? departureDates[0] : new Date();
  const lastDt  = departureDates.length ? departureDates[departureDates.length - 1] : firstDt;

  const dateRangeShort = formatDateShort(firstDt) === formatDateShort(lastDt)
    ? formatDateShort(firstDt)
    : `${formatDateShort(firstDt)} - ${formatDateShort(lastDt)}`;

  const dateLabel = formatDateFull(firstDt);

  // Group schedules by route key "FROM → TO"
  const groups = new Map();
  for (const r of rows) {
    const key = `${(r.from_location||'').toUpperCase()} -> ${(r.to_location||'').toUpperCase()}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(r);
  }

  // ─── PDF setup ─────────────────────────────────────────────────────────────
  const safe = s => s.replace(/[^\w]+/g,'-').slice(0,40);
  const fname = `union-schedule-${dateLabel.replace(/[, ]+/g,'-')}.pdf`;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fname}"`);

  const doc = new PDFDocument({ size: 'A4', margin: 0, info: { Title: `${posterTitle} - Daily Schedule`, Author: 'LuhaRide' } });
  doc.pipe(res);

  const W   = doc.page.width;
  const H   = doc.page.height;
  const ML  = 28;
  const CW  = W - ML * 2;
  const FOOTER_H = 58;

  // ── Background ─────────────────────────────────────────────────────────────
  _fillRect(doc, 0, 0, W, H, '#FFFDF5');

  // ── Top accent ─────────────────────────────────────────────────────────────
  _fillRect(doc, 0, 0, W, 5, themeColors.topStripe);

  // ── Header band (manual poster title only) ──────────────────────────────
  const compact = posterLayoutType === 'compact';
  const headerH = compact ? 90 : 104;
  _fillRect(doc, 0, 5, W, headerH, themeColors.headerBg);

  let y = 16;
  // Manual poster title — only big element at top.
  const unLen = posterTitle.length;
  const unFontSize = unLen > 26 ? 20 : (unLen > 18 ? 22 : 26);
  doc.fillColor(themeColors.text).font('Helvetica-Bold').fontSize(unFontSize)
    .text(posterTitle.toUpperCase(), 0, y, { width: W, align: 'center' });
  y += unFontSize + 4;

  // Date + subtitle (ASCII only so no garbage glyphs)
  doc.fillColor(themeColors.subText).font('Helvetica').fontSize(9)
    .text(`Daily taxi schedule  —  ${dateRangeShort.toUpperCase()}`, 0, y, {
      width: W,
      align: 'center',
      characterSpacing: 0.8,
    });

  if (posterCustomText && posterCustomTextPosition === 'left') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, 14, 5 + (headerH / 2) - 5, { width: 170, align: 'left' });
  } else if (posterCustomText && posterCustomTextPosition === 'right') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, W - 184, 5 + (headerH / 2) - 5, { width: 170, align: 'right' });
  }

  // Start table immediately after yellow band
  y = 5 + headerH + 4;

  // ── Column definitions (simple & passenger‑friendly) ───────────────────────
  const COL_DATE  = { label: 'Date',        w: 95,  align: 'center' };
  const COL_TIME  = { label: 'Time',        w: 70,  align: 'center' };
  const COL_DRV   = { label: 'Driver name', w: 185, align: 'left'   };
  const COL_VEH   = { label: 'Cab number',  w: 95, align: 'center' };
  const COL_PHONE = {
    label: 'Phone',
    w: CW - 95 - 70 - 185 - 95,
    align: 'center',
  };
  const COLS      = [COL_DATE, COL_TIME, COL_DRV, COL_VEH, COL_PHONE];
  const TOTAL_W  = COLS.reduce((s, c) => s + c.w, 0);
  // Compact spacing so many rides fit on one page.
  const ROW_H    = rows.length > 40 ? 18 : (rows.length > 20 ? 20 : 22);
  const HDR_H    = 20;

  // Route color palette: softer accents (avoid harsh yellows on eyes).
  const ROUTE_COLORS = ['#E3B341', '#DDA15E', '#CFA36A', '#C97B63', '#4EA8DE', '#52B788'];
  let colorIdx = 0;

  // ── For each route group, draw a section ───────────────────────────────────
  for (const [routeKey, schedules] of groups) {
    const sectionH = HDR_H + 4 + schedules.length * ROW_H + 14;
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
      const dateStr = dt ? formatDateShort(dt) : '—';
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
          dateStr,
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

    y += 10;
  }

  // ── Footer band ─────────────────────────────────────────────────────────────
  const footerY = H - FOOTER_H;
  _fillRect(doc, 0, footerY, W, FOOTER_H, '#212121');
  _fillRect(doc, 0, footerY, W, 3, '#FFC107');

  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(12)
    .text('Book or find rides online at luharide.in', 0, footerY + 20,
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
  updateUnionDocuments,
};

