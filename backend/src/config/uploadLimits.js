/**
 * KYC document uploads — min/max per file (driver + union).
 * UPLOAD_MAX_FILE_MB: 5–20, default 20.
 * UPLOAD_MIN_FILE_KB: 1–512, default 50 (reject tiny / corrupt-looking files).
 */
const rawMax = parseInt(process.env.UPLOAD_MAX_FILE_MB || '20', 10);
const maxFileMb = Math.min(20, Math.max(5, Number.isFinite(rawMax) && rawMax > 0 ? rawMax : 20));
const maxFileBytes = maxFileMb * 1024 * 1024;

const rawMinKb = parseInt(process.env.UPLOAD_MIN_FILE_KB || '50', 10);
const minFileKb = Math.min(512, Math.max(1, Number.isFinite(rawMinKb) && rawMinKb > 0 ? rawMinKb : 50));
const minFileBytes = minFileKb * 1024;

/** Included in upload API responses for clients */
const limitsPayload = {
  minFileKb,
  maxFileMb,
  minFileBytes,
  maxFileBytes,
};

module.exports = {
  maxFileMb,
  maxFileBytes,
  minFileKb,
  minFileBytes,
  limitsPayload,
};
