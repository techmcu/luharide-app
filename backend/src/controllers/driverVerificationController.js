const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');
const { buildWatermarkedPdfFromUploadUrls } = require('../utils/kycBuildPdfFromUploadUrls');

function sanitizeDocUrl(raw) {
  if (raw == null || raw === '') return null;
  const s = String(raw).trim();
  if (s.length > 2048) return null;
  if (/^https?:\/\//i.test(s)) return s;
  if (s.startsWith('/uploads/')) return s;
  return null;
}

/** Preserve order; drop empty. */
function orderedSanitizedDocUrls(urlList) {
  const out = [];
  for (const u of urlList) {
    const s = sanitizeDocUrl(u);
    if (s) out.push(s);
  }
  return out;
}

/**
 * Submit driver verification request
 * POST /api/driver-verification
 */
const submitVerification = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const {
    driving_license_number,
    driving_license_url,
    vehicle_registration,
    vehicle_type,
    vehicle_model,
    vehicle_model_id,
    vehicle_capacity,
    rc_document_url,
    permit_document_url,
    insurance_document_url,
    aadhaar_document_url,
    aadhaar_front_url,
    aadhaar_back_url,
    rc_front_url,
    rc_back_url,
    driving_license_front_url,
    driving_license_back_url,
    contact_phone,
    contact_email,
  } = req.body;

  const contactPhoneVal =
    contact_phone != null
      ? String(contact_phone).replace(/\s+/g, '').trim().slice(0, 20)
      : '';
  const contactEmailVal =
    contact_email != null ? String(contact_email).trim().slice(0, 150) : '';
  if (contactPhoneVal.length < 10) {
    throw ApiError.badRequest('Contact phone is required (at least 10 digits).');
  }
  if (!contactEmailVal || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contactEmailVal)) {
    throw ApiError.badRequest('Valid contact email is required.');
  }

  // Check if already approved
  const userCheck = await pool.query(
    'SELECT driver_verification_status FROM users WHERE id = $1',
    [userId]
  );
  if (userCheck.rows[0]?.driver_verification_status === 'approved') {
    throw ApiError.badRequest('You are already a verified driver');
  }

  if (req.user.role === 'union_admin') {
    throw ApiError.badRequest(
      'Union admin accounts cannot submit independent driver verification.'
    );
  }

  // Block if user has any union that is still pending or approved (not only rows[0] — multiple unions possible).
  const unionActive = await pool.query(
    `SELECT 1 FROM unions u
     INNER JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1 AND u.status IN ('pending', 'approved')
     LIMIT 1`,
    [userId]
  );
  if (unionActive.rows.length > 0) {
    throw ApiError.badRequest(
      'Taxi union registration is active on this account. Independent driver verification is not available.'
    );
  }

  // Independent driver: max 32 seats (cap for seat layout and booking)
  const MAX_SEATS = 32;
  let capNum = vehicle_capacity != null ? parseInt(vehicle_capacity, 10) : null;
  if (capNum != null && (Number.isNaN(capNum) || capNum < 1)) capNum = null;
  if (capNum != null && capNum > MAX_SEATS) capNum = MAX_SEATS;

  let aadhaarDoc = sanitizeDocUrl(aadhaar_document_url);
  let aadhaarFront = sanitizeDocUrl(aadhaar_front_url);
  let aadhaarBack = sanitizeDocUrl(aadhaar_back_url);
  let dlLegacy = sanitizeDocUrl(driving_license_url);
  let dlFront = sanitizeDocUrl(driving_license_front_url);
  let dlBack = sanitizeDocUrl(driving_license_back_url);

  const aadhaarPieces = orderedSanitizedDocUrls([aadhaar_front_url, aadhaar_back_url]);
  if (aadhaarPieces.length > 0) {
    aadhaarDoc = await buildWatermarkedPdfFromUploadUrls(
      aadhaarPieces,
      'driver-docs',
      'aadhaar_merged'
    );
    aadhaarFront = null;
    aadhaarBack = null;
  }

  const dlPieces = orderedSanitizedDocUrls([driving_license_front_url, driving_license_back_url]);
  if (dlPieces.length > 0) {
    dlLegacy = await buildWatermarkedPdfFromUploadUrls(dlPieces, 'driver-docs', 'dl_merged');
    dlFront = null;
    dlBack = null;
  }

  // Upsert verification request (vehicle_model_id = catalog ID for exact seat layout)
  const params = [
    userId,
    driving_license_number || null,
    dlLegacy,
    vehicle_registration || null,
    vehicle_type || null,
    vehicle_model || null,
    vehicle_model_id || null,
    capNum,
    rc_document_url || null,
    permit_document_url || null,
    insurance_document_url || null,
    aadhaarDoc,
    aadhaarFront,
    aadhaarBack,
    rc_front_url || null,
    rc_back_url || null,
    dlFront,
    dlBack,
    contactPhoneVal,
    contactEmailVal,
  ];

  let result;
  try {
    result = await pool.query(
      `INSERT INTO driver_verification_requests (
        user_id, driving_license_number, driving_license_url,
        vehicle_registration, vehicle_type, vehicle_model, vehicle_model_id, vehicle_capacity,
        rc_document_url, permit_document_url, insurance_document_url, aadhaar_document_url,
        aadhaar_front_url, aadhaar_back_url, rc_front_url, rc_back_url, driving_license_front_url, driving_license_back_url,
        contact_phone, contact_email,
        status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, 'pending')
      ON CONFLICT (user_id) DO UPDATE SET
        driving_license_number = EXCLUDED.driving_license_number,
        driving_license_url = EXCLUDED.driving_license_url,
        vehicle_registration = EXCLUDED.vehicle_registration,
        vehicle_type = EXCLUDED.vehicle_type,
        vehicle_model = EXCLUDED.vehicle_model,
        vehicle_model_id = EXCLUDED.vehicle_model_id,
        vehicle_capacity = EXCLUDED.vehicle_capacity,
        rc_document_url = EXCLUDED.rc_document_url,
        permit_document_url = EXCLUDED.permit_document_url,
        insurance_document_url = EXCLUDED.insurance_document_url,
        aadhaar_document_url = EXCLUDED.aadhaar_document_url,
        aadhaar_front_url = EXCLUDED.aadhaar_front_url,
        aadhaar_back_url = EXCLUDED.aadhaar_back_url,
        rc_front_url = EXCLUDED.rc_front_url,
        rc_back_url = EXCLUDED.rc_back_url,
        driving_license_front_url = EXCLUDED.driving_license_front_url,
        driving_license_back_url = EXCLUDED.driving_license_back_url,
        contact_phone = EXCLUDED.contact_phone,
        contact_email = EXCLUDED.contact_email,
        status = 'pending',
        rejection_reason = NULL,
        reviewed_by = NULL,
        reviewed_at = NULL,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      params
    );
  } catch (err) {
    if (
      err.code === '42703' &&
      /contact_phone|contact_email/i.test(err.message || '')
    ) {
      logger.error('driver_verification_requests missing contact columns (run migration 034).', {
        message: err.message,
      });
      throw ApiError.serviceUnavailable(
        'Database migration required: run `npm run migrate` on the server (adds driver verification contact fields).'
      );
    }
    // If vehicle_model_id column does not exist (migration 008 not run), retry without it
    if (
      err.code === '42703' &&
      (err.message || '').includes('vehicle_model_id')
    ) {
      logger.warn('driver_verification_requests schema outdated, inserting with legacy columns.');
      result = await pool.query(
        `INSERT INTO driver_verification_requests (
          user_id, driving_license_number, driving_license_url,
          vehicle_registration, vehicle_type, vehicle_model, vehicle_capacity,
          rc_document_url, permit_document_url, insurance_document_url, aadhaar_document_url,
          status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'pending')
        ON CONFLICT (user_id) DO UPDATE SET
          driving_license_number = EXCLUDED.driving_license_number,
          driving_license_url = EXCLUDED.driving_license_url,
          vehicle_registration = EXCLUDED.vehicle_registration,
          vehicle_type = EXCLUDED.vehicle_type,
          vehicle_model = EXCLUDED.vehicle_model,
          vehicle_capacity = EXCLUDED.vehicle_capacity,
          rc_document_url = EXCLUDED.rc_document_url,
          permit_document_url = EXCLUDED.permit_document_url,
          insurance_document_url = EXCLUDED.insurance_document_url,
          aadhaar_document_url = EXCLUDED.aadhaar_document_url,
          status = 'pending',
          rejection_reason = NULL,
          reviewed_by = NULL,
          reviewed_at = NULL,
          updated_at = CURRENT_TIMESTAMP
        RETURNING *`,
        [
          params[0], params[1], params[2], params[3], params[4], params[5],
          params[7], params[8], params[9], params[10], params[11]
        ]
      );
    } else {
      logger.error('Driver verification submit failed:', err.message, err.code);
      throw err;
    }
  }

  // Update user status
  await pool.query(
    "UPDATE users SET driver_verification_status = 'pending' WHERE id = $1",
    [userId]
  );

  const request = result.rows[0];
  logger.info(`Driver verification submitted: ${userId}`);

  ApiResponse.created(
    { request },
    'Verification request submitted. Admin will review shortly.'
  ).send(res);
});

/**
 * Get current user's verification status
 * GET /api/driver-verification
 */
const getMyStatus = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const userResult = await pool.query(
    'SELECT driver_verification_status FROM users WHERE id = $1',
    [userId]
  );
  const status = userResult.rows[0]?.driver_verification_status || 'none';

  const requestResult = await pool.query(
    'SELECT * FROM driver_verification_requests WHERE user_id = $1',
    [userId]
  );
  const request = requestResult.rows[0] || null;

  ApiResponse.success(
    { status, request },
    'Verification status retrieved'
  ).send(res);
});

/**
 * Get all pending driver requests (Admin only)
 * GET /api/admin/driver-requests
 */
const getPendingRequests = asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT dvr.*, u.name, u.email, u.phone
     FROM driver_verification_requests dvr
     JOIN users u ON u.id = dvr.user_id
     WHERE dvr.status = 'pending'
     ORDER BY dvr.created_at ASC`
  );

  ApiResponse.success(
    { requests: result.rows },
    'Pending requests retrieved'
  ).send(res);
});

/**
 * Approve driver request (Admin only)
 * POST /api/admin/driver-requests/:id/approve
 */
const approveRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const adminId = req.user.id;

  const requestResult = await pool.query(
    'SELECT * FROM driver_verification_requests WHERE id = $1 AND status = $2',
    [id, 'pending']
  );

  if (requestResult.rows.length === 0) {
    throw ApiError.notFound('Pending request not found');
  }

  const request = requestResult.rows[0];

  await pool.query(
    `UPDATE driver_verification_requests 
     SET status = 'approved', reviewed_by = $1, reviewed_at = CURRENT_TIMESTAMP 
     WHERE id = $2`,
    [adminId, id]
  );

  await pool.query(
    `UPDATE users 
     SET driver_verification_status = 'approved',
         role = 'driver',
         driver_code = COALESCE(driver_code, SUBSTRING(id::text, 1, 8))
     WHERE id = $1`,
    [request.user_id]
  );

  // Notify driver: verification approved
  try {
    const n = await pool.query(
      `INSERT INTO notifications (user_id, type, title, body) 
       VALUES ($1, 'verification_approved', 'Verification Approved', 'Your driver verification has been approved! You can now create rides.')
       RETURNING id, user_id, type, title, body, created_at, is_read`,
      [request.user_id]
    );
    if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
  } catch (err) {
    logger.warn(
      `Notifications insert failed. Driver still approved. Error: ${err.message}`
    );
  }

  logger.info(`Driver approved: ${request.user_id} by admin ${adminId}`);

  ApiResponse.success(
    { message: 'Driver approved successfully' },
    'Driver approved'
  ).send(res);
});

/**
 * Reject driver request (Admin only)
 * POST /api/admin/driver-requests/:id/reject
 */
const rejectRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  const adminId = req.user.id;

  const requestResult = await pool.query(
    'SELECT * FROM driver_verification_requests WHERE id = $1 AND status = $2',
    [id, 'pending']
  );

  if (requestResult.rows.length === 0) {
    throw ApiError.notFound('Pending request not found');
  }

  const request = requestResult.rows[0];

  await pool.query(
    `UPDATE driver_verification_requests 
     SET status = 'rejected', rejection_reason = $1, reviewed_by = $2, reviewed_at = CURRENT_TIMESTAMP 
     WHERE id = $3`,
    [reason || 'Documents rejected', adminId, id]
  );

  await pool.query(
    "UPDATE users SET driver_verification_status = 'rejected' WHERE id = $1",
    [request.user_id]
  );

  logger.info(`Driver rejected: ${request.user_id} by admin ${adminId}`);

  ApiResponse.success(
    { message: 'Request rejected' },
    'Request rejected'
  ).send(res);
});

module.exports = {
  submitVerification,
  getMyStatus,
  getPendingRequests,
  approveRequest,
  rejectRequest
};
