const path = require('path');
const fs = require('fs').promises;
const { minFileBytes } = require('../config/uploadLimits');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');
const { resolveVerifiedUploadPath } = require('./resolveVerifiedUploadPath');
const { mergeImagePathsToWatermarkedPdf } = require('./kycMergeImagesToPdf');

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

  const paths = [];
  for (const u of sanitizedRelativeUrls) {
    const abs = resolveVerifiedUploadPath(u, subdir);
    if (!abs) {
      throw ApiError.badRequest('Invalid document path. Upload again from the app.');
    }
    try {
      await fs.access(abs);
    } catch {
      throw ApiError.badRequest('Uploaded file not found. Try uploading again.');
    }
    paths.push(abs);
  }

  const uploadsDir = path.join(__dirname, '..', '..', 'uploads', subdir);
  const outName = `${filePrefix}_${Date.now()}.pdf`;
  const outAbs = path.join(uploadsDir, outName);

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
}

module.exports = { buildWatermarkedPdfFromUploadUrls };
