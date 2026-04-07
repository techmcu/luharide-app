const { pool } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const { sanitizeKycUploadUrl } = require('../utils/sanitizeKycUploadUrl');

const DISCLAIMER =
  'These are the copies you submitted. LuhaRide applies an on-file watermark and supporting text for verification purposes. They are meant for LuhaRide verification only and must not be reused outside the platform.';

function pushDoc(bucket, seen, url, label, category) {
  const s = sanitizeKycUploadUrl(url);
  if (!s || seen.has(s)) return;
  seen.add(s);
  bucket.push({
    id: `${category}:${label}`.replace(/\s+/g, '_').toLowerCase(),
    label,
    url: s,
    category,
  });
}

function collectFromDriverRow(row, bucket, seen) {
  if (!row) return;
  pushDoc(bucket, seen, row.driving_license_url, 'Driving licence', 'driver');
  pushDoc(bucket, seen, row.driving_license_front_url, 'Driving licence (front)', 'driver');
  pushDoc(bucket, seen, row.driving_license_back_url, 'Driving licence (back)', 'driver');
  pushDoc(bucket, seen, row.rc_document_url, 'Vehicle RC', 'driver');
  pushDoc(bucket, seen, row.rc_front_url, 'Vehicle RC (front)', 'driver');
  pushDoc(bucket, seen, row.rc_back_url, 'Vehicle RC (back)', 'driver');
  pushDoc(bucket, seen, row.permit_document_url, 'Permit', 'driver');
  pushDoc(bucket, seen, row.insurance_document_url, 'Insurance', 'driver');
  pushDoc(bucket, seen, row.aadhaar_document_url, 'Aadhaar', 'driver');
  pushDoc(bucket, seen, row.aadhaar_front_url, 'Aadhaar (front)', 'driver');
  pushDoc(bucket, seen, row.aadhaar_back_url, 'Aadhaar (back)', 'driver');
}

function collectFromUnionRow(row, bucket, seen) {
  if (!row) return;
  pushDoc(bucket, seen, row.owner_aadhaar_url, 'Union — Aadhaar (head)', 'union');
  pushDoc(bucket, seen, row.owner_aadhaar_front_url, 'Union — Aadhaar (front)', 'union');
  pushDoc(bucket, seen, row.owner_aadhaar_back_url, 'Union — Aadhaar (back)', 'union');
  pushDoc(bucket, seen, row.office_photo_url, 'Union — Office / centre photo', 'union');
  pushDoc(bucket, seen, row.owner_vehicle_rc_url, 'Union — Vehicle RC', 'union');
  pushDoc(bucket, seen, row.owner_vehicle_rc_front_url, 'Union — Vehicle RC (front)', 'union');
  pushDoc(bucket, seen, row.owner_vehicle_rc_back_url, 'Union — Vehicle RC (back)', 'union');
  pushDoc(bucket, seen, row.leader_driving_license_front_url, 'Union — Licence (front)', 'union');
  pushDoc(bucket, seen, row.leader_driving_license_back_url, 'Union — Licence (back)', 'union');
  pushDoc(bucket, seen, row.union_photo_url, 'Union — Photo', 'union');
  pushDoc(bucket, seen, row.union_driver_list_photo_url, 'Union — Driver list photo', 'union');
}

/**
 * GET /api/kyc/submitted-documents
 * Lightweight JSON list of stored (watermarked/processed) upload URLs for the current user.
 */
const getMySubmittedDocuments = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const documents = [];
  const seen = new Set();

  const dvrResult = await pool.query(
    `SELECT * FROM driver_verification_requests
     WHERE user_id = $1
     ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
     LIMIT 1`,
    [userId]
  );
  collectFromDriverRow(dvrResult.rows[0], documents, seen);

  const unionResult = await pool.query(
    `SELECT u.*
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1
     ORDER BY u.created_at DESC
     LIMIT 1`,
    [userId]
  );
  const unionRow = unionResult.rows[0];
  // Show union uploads for any status (pending / approved / rejected) so users always see on-file KYC.
  collectFromUnionRow(unionRow, documents, seen);

  const dvrTime = dvrResult.rows[0]?.updated_at || dvrResult.rows[0]?.created_at || '';
  const unionTime = unionRow?.updated_at || unionRow?.created_at || '';
  const revision = `${userId}|${String(dvrTime)}|${String(unionTime)}|${documents.length}`;

  ApiResponse.success(
    {
      disclaimer: DISCLAIMER,
      documents,
      revision,
    },
    'Submitted documents retrieved'
  ).send(res);
});

module.exports = {
  getMySubmittedDocuments,
};
