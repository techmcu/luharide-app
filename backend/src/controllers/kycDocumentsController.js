const { pool } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const { collectFromDriverRow, collectFromUnionRow } = require('./kycDocumentsCollect');

const DISCLAIMER =
  'These are the copies you submitted. LuhaRide applies an on-file watermark and supporting text for verification purposes. They are meant for LuhaRide verification only and must not be reused outside the platform.';

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
