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

/**
 * Microservices: uploads are stored on the platform service; union/core merge on their own disk.
 * If the file is missing locally, fetch from platform (same .env PLATFORM_URL / LUHA_PLATFORM_FETCH_URL).
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

  const baseRaw =
    process.env.LUHA_PLATFORM_FETCH_URL ||
    process.env.PLATFORM_URL ||
    process.env.PLATFORM_SERVICE_URL ||
    '';
  const base = String(baseRaw).trim().replace(/\/$/, '');
  if (!base || !relativeUrl.startsWith('/uploads/')) {
    throw ApiError.badRequest('Uploaded file not found. Try uploading again.');
  }

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
    if (e && e.isAxiosError) {
      logger.warn('KYC: fetch upload from platform failed', {
        url: fullUrl,
        status: e.response && e.response.status,
        message: e.message,
      });
    } else if (e && e.message === 'too_small') {
      throw ApiError.badRequest('Downloaded document too small.');
    } else if (e && e.message === 'too_large') {
      throw ApiError.badRequest('Downloaded document too large.');
    }
    throw ApiError.badRequest(
      'Uploaded file not found for verification. In microservices mode, set PLATFORM_URL (or LUHA_PLATFORM_FETCH_URL) on union and core services to the platform service base URL.'
    );
  }
}

/**
 * @param {string[]} sanitizedRelativeUrls e.g. ["/uploads/driver-docs/a.jpg"]
 * @param {'driver-docs'|'union-docs'} subdir
 * @param {string} filePrefix
 * @returns {Promise<string|null>} new relative URL like /uploads/.../file.pdf
 */
async function buildWatermarkedPdfFromUploadUrls(
  sanitizedRelativeUrls,
  subdir,
  filePrefix
) {
  if (!sanitizedRelativeUrls || sanitizedRelativeUrls.length === 0) return null;

  const tempCleanup = [];
  const paths = [];
  try {
    for (const u of sanitizedRelativeUrls) {
      paths.push(await resolveReadablePath(u, subdir, tempCleanup));
    }

    const uploadsDir = path.join(__dirname, '..', '..', 'uploads', subdir);
    const outName = `${filePrefix}_${Date.now()}.pdf`;
    const outAbs = path.join(uploadsDir, outName);
    await fs.mkdir(uploadsDir, { recursive: true });

    try {
      await mergeImagePathsToWatermarkedPdf(paths, outAbs);
    } catch (err) {
      logger.warn('KYC PDF build failed', {
        message: err && err.message,
        subdir,
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

    return `/uploads/${subdir}/${outName}`;
  } finally {
    for (const t of tempCleanup) {
      await fs.unlink(t).catch(() => {});
    }
  }
}

/**
 * Copy an existing stored PDF and apply KYC stamps (legacy PDF URLs otherwise skipped watermark).
 */
async function copyAndWatermarkExistingPdf(sanitizedRelativeUrl, subdir, filePrefix) {
  const tempCleanup = [];
  try {
    const abs = await resolveReadablePath(sanitizedRelativeUrl, subdir, tempCleanup);
    const lower = abs.toLowerCase();
    if (!lower.endsWith('.pdf')) {
      return sanitizedRelativeUrl;
    }
    const uploadsDir = path.join(__dirname, '..', '..', 'uploads', subdir);
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
    return `/uploads/${subdir}/${outName}`;
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
