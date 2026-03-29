/**
 * KYC document uploads — cap per file (driver + union).
 * Override: UPLOAD_MAX_FILE_MB in .env (5–50, default 20).
 */
const raw = parseInt(process.env.UPLOAD_MAX_FILE_MB || '20', 10);
const maxFileMb = Math.min(50, Math.max(5, Number.isFinite(raw) && raw > 0 ? raw : 20));
const maxFileBytes = maxFileMb * 1024 * 1024;

module.exports = { maxFileMb, maxFileBytes };
