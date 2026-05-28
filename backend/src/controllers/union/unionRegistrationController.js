const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const { enqueueBuildPdf, enqueueCopyPdf } = require('../../jobs/kycQueue');
const { sanitizeKycUploadUrl: sanitizeDocumentUrl } = require('../../utils/sanitizeKycUploadUrl');
const {
  demoteUnionAdminsOrphanedByReject,
  unlinkUnionAdminsForRejectedUnion,
  cleanPosterHeader,
  cleanPosterCustomText,
  getPosterTheme,
} = require('./unionHelpers');

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

  let union = result.rows[0] || null;

  if (union && union.status === 'rejected') {
    await demoteUnionAdminsOrphanedByReject(union.id);
    await unlinkUnionAdminsForRejectedUnion(union.id);
    union = null;
  }

  const status = union?.status || 'none';

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

function orderedUnionDocUrls(urlList) {
  const out = [];
  for (const u of urlList) {
    const s = sanitizeDocumentUrl(u);
    if (s) out.push(s);
  }
  return out;
}

async function unionImageFieldToPdfIfNeeded(url, prefix) {
  const s = sanitizeDocumentUrl(url);
  if (!s) return null;
  if (s.toLowerCase().endsWith('.pdf')) {
    return enqueueCopyPdf(s, prefix);
  }
  return enqueueBuildPdf([s], 'union-raw', prefix);
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

  const phoneVal = (contact_phone || '').replace(/\s+/g, '').trim();
  if (phoneVal.length < 10) {
    throw ApiError.badRequest('Contact phone is required (at least 10 digits).');
  }

  const existingActive = await pool.query(
    `SELECT u.id, u.status
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1 AND u.status IN ('pending', 'approved')`,
    [userId]
  );
  if (existingActive.rows.length > 0) {
    throw ApiError.badRequest(
      'You already have a union registration pending or approved.'
    );
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

  let ownerAadhaarUrl = sanitizeDocumentUrl(owner_aadhaar_url);
  let ownerAadhaarFront = sanitizeDocumentUrl(owner_aadhaar_front_url);
  let ownerAadhaarBack = sanitizeDocumentUrl(owner_aadhaar_back_url);
  const ownerPieces = orderedUnionDocUrls([owner_aadhaar_front_url, owner_aadhaar_back_url]);
  if (ownerPieces.length > 0) {
    ownerAadhaarUrl = await enqueueBuildPdf(
      ownerPieces,
      'union-raw',
      'union_owner_aadhaar_merged'
    );
    ownerAadhaarFront = null;
    ownerAadhaarBack = null;
  } else if (ownerAadhaarUrl && !ownerAadhaarUrl.toLowerCase().endsWith('.pdf')) {
    ownerAadhaarUrl = await enqueueBuildPdf(
      [ownerAadhaarUrl],
      'union-raw',
      'union_owner_aadhaar_single'
    );
  } else if (ownerAadhaarUrl && ownerAadhaarUrl.toLowerCase().endsWith('.pdf')) {
    ownerAadhaarUrl = await enqueueCopyPdf(
      ownerAadhaarUrl,
      'union_owner_aadhaar_pdf'
    );
  }

  let leaderDlFront = sanitizeDocumentUrl(leader_driving_license_front_url);
  let leaderDlBack = sanitizeDocumentUrl(leader_driving_license_back_url);
  const leaderPieces = orderedUnionDocUrls([
    leader_driving_license_front_url,
    leader_driving_license_back_url,
  ]);
  if (leaderPieces.length > 0) {
    leaderDlFront = await enqueueBuildPdf(
      leaderPieces,
      'union-raw',
      'union_leader_dl_merged'
    );
    leaderDlBack = null;
  }

  const origOfficeSan = sanitizeDocumentUrl(office_photo_url);
  let officePhoto = await unionImageFieldToPdfIfNeeded(office_photo_url, 'union_office');
  const origUnionPhotoSan = sanitizeDocumentUrl(union_photo_url);
  let unionPhoto = origUnionPhotoSan;
  if (origUnionPhotoSan && !origUnionPhotoSan.toLowerCase().endsWith('.pdf')) {
    unionPhoto =
      origOfficeSan && origUnionPhotoSan === origOfficeSan && officePhoto
        ? officePhoto
        : await enqueueBuildPdf(
            [origUnionPhotoSan],
            'union-raw',
            'union_photo'
          );
  }

  let unionDriverListPhoto = await unionImageFieldToPdfIfNeeded(
    union_driver_list_photo_url,
    'union_driver_list'
  );

  let rcUrl = sanitizeDocumentUrl(owner_vehicle_rc_url);
  let rcFront = sanitizeDocumentUrl(owner_vehicle_rc_front_url);
  let rcBack = sanitizeDocumentUrl(owner_vehicle_rc_back_url);
  const rcPieces = orderedUnionDocUrls([owner_vehicle_rc_front_url, owner_vehicle_rc_back_url]);
  if (rcPieces.length > 0) {
    rcUrl = await enqueueBuildPdf(
      rcPieces,
      'union-raw',
      'union_vehicle_rc_merged'
    );
    rcFront = null;
    rcBack = null;
  } else if (rcUrl && !rcUrl.toLowerCase().endsWith('.pdf')) {
    rcUrl = await enqueueBuildPdf(
      [rcUrl],
      'union-raw',
      'union_vehicle_rc'
    );
  } else if (rcUrl && rcUrl.toLowerCase().endsWith('.pdf')) {
    rcUrl = await enqueueCopyPdf(rcUrl, 'union_vehicle_rc_pdf');
  }

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
        ownerAadhaarUrl,
        ownerAadhaarFront,
        ownerAadhaarBack,
        officePhoto,
        unionPhoto,
        unionDriverListPhoto,
        leaderDlFront,
        leaderDlBack,
        rcUrl,
        rcFront,
        rcBack,
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

  // Sync phone to user profile if empty
  await pool.query(
    `UPDATE users SET phone = $2
     WHERE id = $1 AND COALESCE(TRIM(phone), '') = ''`,
    [userId, phoneVal]
  );

  logger.info(`Union registration requested ${union.id} by user ${userId}`);

  ApiResponse.created(
    { union },
    'Union registration submitted. Admin will review your request.'
  ).send(res);
});

const updateUnionDocuments = asyncHandler(async (req, res) => {
  const {
    owner_name,
    owner_aadhaar_url,
    office_photo_url,
    owner_vehicle_rc_url,
    union_share_notes,
  } = req.body;

  const resUnion = await pool.query(
    `SELECT ua.union_id, u.documents_status, u.documents_reupload_allowed, u.documents_reupload_deadline
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionRow = resUnion.rows[0];
  const unionId = unionRow.union_id;

  const docsStatus = (unionRow.documents_status || 'approved').toString();
  const reuploadAllowed = unionRow.documents_reupload_allowed === true;
  const deadline = unionRow.documents_reupload_deadline
    ? new Date(unionRow.documents_reupload_deadline).getTime()
    : null;
  const deadlineExpired = deadline != null && Number.isFinite(deadline) && Date.now() > deadline;
  if (docsStatus === 'approved' && (!reuploadAllowed || deadlineExpired)) {
    throw ApiError.forbidden(
      'Union documents are verified. Re-upload requires admin permission.'
    );
  }

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

  fields.push("documents_status = 'pending'");
  fields.push('documents_reupload_allowed = FALSE');
  fields.push('documents_reupload_deadline = NULL');
  fields.push('updated_at = NOW()');
  values.push(unionId);

  const out = await pool.query(
    `UPDATE unions SET ${fields.join(', ')} WHERE id = $${p} RETURNING *`,
    values
  );
  ApiResponse.success({ union: out.rows[0] }, 'Union documents updated').send(res);
});

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

module.exports = {
  getMyUnion,
  registerUnion,
  updateUnionDocuments,
  updateUnionBranding,
};
