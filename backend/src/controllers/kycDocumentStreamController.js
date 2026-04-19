const fs = require('fs');
const path = require('path');

const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const { sanitizeKycUploadUrl } = require('../utils/sanitizeKycUploadUrl');
const { resolveVerifiedUploadPath } = require('../utils/resolveVerifiedUploadPath');
const { collectFromDriverRow, collectFromUnionRow } = require('./kycDocumentsCollect');

const ALLOWED_SUBDIRS = ['driver-docs', 'union-docs', 'union-raw', 'union-merged'];

function contentTypeForAbsPath(abs) {
  const ext = path.extname(abs).toLowerCase();
  const map = {
    '.pdf': 'application/pdf',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
  };
  return map[ext] || 'application/octet-stream';
}

function resolveSubdir(relativeUrl) {
  const m = String(relativeUrl).match(/^\/uploads\/([^/]+)\//);
  return m ? m[1] : null;
}

/**
 * Same discovery as GET /api/kyc/submitted-documents — used to authorize owner access.
 */
async function allowedKycPathsForUser(userId) {
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
  collectFromUnionRow(unionResult.rows[0], documents, seen);

  return new Set(documents.map((d) => d.url));
}

function streamFileToResponse(res, abs) {
  const st = fs.statSync(abs);
  res.setHeader('Content-Type', contentTypeForAbsPath(abs));
  res.setHeader('Cache-Control', 'private, max-age=86400');
  res.setHeader('Content-Length', String(st.size));

  const stream = fs.createReadStream(abs);
  stream.on('error', () => {
    if (!res.headersSent) {
      res.status(500).end();
    }
  });
  stream.pipe(res);
}

function assertResolvedPath(rel) {
  const subdir = resolveSubdir(rel);
  if (!subdir || !ALLOWED_SUBDIRS.includes(subdir)) {
    throw ApiError.badRequest('Unsupported storage path');
  }
  const abs = resolveVerifiedUploadPath(rel, subdir);
  if (!abs) {
    throw ApiError.badRequest('Invalid path');
  }
  if (!fs.existsSync(abs)) {
    throw ApiError.notFound('File not found');
  }
  return abs;
}

/**
 * GET /api/kyc/document-file?path=%2Fuploads%2F...
 * Authenticated file stream — same CORS as other /api routes (fixes Flutter web + JWT).
 * Owner may only open paths listed for their submitted KYC.
 */
const streamMyKycDocumentFile = asyncHandler(async (req, res) => {
  const raw = req.query.path;
  const rel = sanitizeKycUploadUrl(typeof raw === 'string' ? raw : '');
  if (!rel) {
    throw ApiError.badRequest('Invalid path');
  }

  const allowed = await allowedKycPathsForUser(req.user.id);
  if (!allowed.has(rel)) {
    throw ApiError.forbidden('You do not have access to this file');
  }

  const abs = assertResolvedPath(rel);
  streamFileToResponse(res, abs);
});

/**
 * GET /api/admin/document-file?path=%2Fuploads%2F...
 * union_admin — verify KYC for any driver/union; path must exist on disk under uploads.
 */
const streamAdminKycDocumentFile = asyncHandler(async (req, res) => {
  const raw = req.query.path;
  const rel = sanitizeKycUploadUrl(typeof raw === 'string' ? raw : '');
  if (!rel) {
    throw ApiError.badRequest('Invalid path');
  }

  const abs = assertResolvedPath(rel);
  streamFileToResponse(res, abs);
});

module.exports = {
  streamMyKycDocumentFile,
  streamAdminKycDocumentFile,
};
