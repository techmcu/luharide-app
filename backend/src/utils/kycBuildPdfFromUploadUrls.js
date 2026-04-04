const path = require('path');
const crypto = require('crypto');
const os = require('os');
const fs = require('fs').promises;
const axios = require('axios');
const { minFileBytes, maxFileBytes } = require('../config/uploadLimits');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');
const { resolveVerifiedUploadPath } = require('./resolveVerifiedUploadPath');
const { mergeImagePathsToWatermarkedPdf } = require('./kycMergeImagesToPdf');
const { applyKycPdfWatermark } = require('./kycPdfWatermark');

function collectFetchBases() {
  const raw = [
    process.env.LUHA_PLATFORM_FETCH_URL,
    process.env.PLATFORM_URL,
    process.env.PLATFORM_SERVICE_URL,
    process.env.LUHA_GATEWAY_INTERNAL_URL,
    process.env.GATEWAY_INTERNAL_URL,
  ];
  const out = [];
  const seen = new Set();
  for (const r of raw) {
    const b = String(r || '')
      .trim()
      .replace(/\/$/, '');
    if (b && !seen.has(b)) {
      seen.add(b);
      out.push(b);
    }
  }
  return out;
}

/**
 * Microservices: raw KYC files live on the platform service; union merge runs on union disk.
 * If the file is missing locally, fetch from configured base URL(s).
 */
async function resolveReadablePath(relativeUrl, subdir, tempCleanup) {
  const abs = resolveVerifiedUploadPath(relativeUrl, subdir);
  if (!abs) {
    throw ApiError.badRequest('Invalid document path. Upload again from the app.');
  }
  try {
    await fs.access(abs);
    return abs;
  } catch {
    /* try HTTP fetch */
  }

  const bases = collectFetchBases();
  if (!relativeUrl.startsWith('/uploads/') || bases.length === 0) {
    throw ApiError.badRequest('Uploaded file not found. Try uploading again.');
  }

  let lastErr;
  for (const base of bases) {
    const fullUrl = `${base}${relativeUrl}`;
    try {
      const resp = await axios.get(fullUrl, {
        responseType: 'arraybuffer',
        timeout: 30000,
        maxContentLength: maxFileBytes,
        maxBodyLength: maxFileBytes,
        validateStatus: (s) => s === 200,
      });
      const buf = Buffer.from(resp.data);
      if (buf.length < minFileBytes) {
        throw new Error('too_small');
      }
      if (buf.length > maxFileBytes) {
        throw new Error('too_large');
      }
      const ext = path.extname(relativeUrl) || '.jpg';
      const tmp = path.join(
        os.tmpdir(),
        `luha-kyc-${process.pid}-${crypto.randomBytes(8).toString('hex')}${ext}`
      );
      await fs.writeFile(tmp, buf);
      tempCleanup.push(tmp);
      return tmp;
    } catch (e) {
      lastErr = e;
      if (e && e.isAxiosError) {
        logger.warn('KYC: fetch upload failed', {
          url: fullUrl,
          status: e.response && e.response.status,
          message: e.message,
        });
      } else if (e && (e.message === 'too_small' || e.message === 'too_large')) {
        throw e.message === 'too_small'
          ? ApiError.badRequest('Downloaded document too small.')
          : ApiError.badRequest('Downloaded document too large.');
      }
    }
  }

  if (lastErr && lastErr.message === 'too_small') {
    throw ApiError.badRequest('Downloaded document too small.');
  }
  if (lastErr && lastErr.message === 'too_large') {
    throw ApiError.badRequest('Downloaded document too large.');
  }
  throw ApiError.badRequest(
    'Uploaded file not found for verification. In microservices mode, set PLATFORM_URL (or LUHA_PLATFORM_FETCH_URL) on the union service to the platform base URL.'
  );
}

/** First path segment after /uploads/ — must match resolveVerifiedUploadPath subdir. */
function uploadSubdirFromUrl(relativeUrl) {
  const m = String(relativeUrl || '').match(/^\/uploads\/([^/]+)\//);
  return m ? m[1] : null;
}

/**
 * @param {string[]} sanitizedRelativeUrls e.g. ["/uploads/union-raw/a.jpg"]
 * @param {'driver-docs'|'union-raw'} inputSubdir fallback if URL has no segment
 * @param {string} filePrefix
 * @returns {Promise<string|null>} new relative URL like /uploads/union-merged/... or /uploads/driver-docs/...
 */
async function buildWatermarkedPdfFromUploadUrls(
  sanitizedRelativeUrls,
  inputSubdir,
  filePrefix
) {
  if (!sanitizedRelativeUrls || sanitizedRelativeUrls.length === 0) return null;

  const outputSubdir =
    String(inputSubdir) === 'union-raw' ? 'union-merged' : inputSubdir;

  const tempCleanup = [];
  const paths = [];
  try {
    for (const u of sanitizedRelativeUrls) {
      const seg = uploadSubdirFromUrl(u) || inputSubdir;
      paths.push(await resolveReadablePath(u, seg, tempCleanup));
    }

    const uploadsDir = path.join(__dirname, '..', '..', 'uploads', outputSubdir);
    const outName = `${filePrefix}_${Date.now()}.pdf`;
    const outAbs = path.join(uploadsDir, outName);
    await fs.mkdir(uploadsDir, { recursive: true });

    try {
      await mergeImagePathsToWatermarkedPdf(paths, outAbs);
    } catch (err) {
      logger.warn('KYC PDF build failed', {
        message: err && err.message,
        inputSubdir,
        outputSubdir,
        filePrefix,
      });
      await fs.unlink(outAbs).catch(() => {});
      throw ApiError.badRequest(
        'Could not build verification PDF from photos. Use clear JPEG or PNG images.'
      );
    }

    const st = await fs.stat(outAbs);
    if (st.size < minFileBytes) {
      await fs.unlink(outAbs).catch(() => {});
      throw ApiError.badRequest('Document PDF too small. Upload a clearer photo.');
    }

    return `/uploads/${outputSubdir}/${outName}`;
  } finally {
    for (const t of tempCleanup) {
      await fs.unlink(t).catch(() => {});
    }
  }
}

/**
 * Copy an existing stored PDF and apply KYC stamps; output always under union-merged.
 */
async function copyAndWatermarkExistingPdf(sanitizedRelativeUrl, filePrefix) {
  const tempCleanup = [];
  try {
    const seg = uploadSubdirFromUrl(sanitizedRelativeUrl);
    const allowed = new Set(['union-raw', 'union-docs', 'union-merged']);
    if (!seg || !allowed.has(seg)) {
      throw ApiError.badRequest('Invalid document path. Upload again from the app.');
    }
    const abs = await resolveReadablePath(sanitizedRelativeUrl, seg, tempCleanup);
    const lower = abs.toLowerCase();
    if (!lower.endsWith('.pdf')) {
      return sanitizedRelativeUrl;
    }
    const uploadsDir = path.join(__dirname, '..', '..', 'uploads', 'union-merged');
    const outName = `${filePrefix}_${Date.now()}.pdf`;
    const outAbs = path.join(uploadsDir, outName);
    await fs.mkdir(uploadsDir, { recursive: true });
    await fs.copyFile(abs, outAbs);
    await applyKycPdfWatermark(outAbs);
    const st = await fs.stat(outAbs);
    if (st.size < minFileBytes) {
      await fs.unlink(outAbs).catch(() => {});
      throw ApiError.badRequest('Watermarked PDF too small.');
    }
    return `/uploads/union-merged/${outName}`;
  } finally {
    for (const t of tempCleanup) {
      await fs.unlink(t).catch(() => {});
    }
  }
}

module.exports = {
  buildWatermarkedPdfFromUploadUrls,
  copyAndWatermarkExistingPdf,
};
