const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { authenticate } = require('../middleware/auth');
const { uploadDocLimiter } = require('../middleware/rateLimiter');
const { maxFileBytes, minFileBytes, limitsPayload } = require('../config/uploadLimits');
const { applyKycWatermark } = require('../utils/kycImageWatermark');
const logger = require('../config/logger');

const router = express.Router();

/** KYC uploads: JPEG/PNG only; server builds watermarked PDFs for admin when needed. */
const ALLOWED_DOC_MIMES = new Set(['image/jpeg', 'image/png']);

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function createStorage(subdir) {
  const dest = path.join(__dirname, '..', '..', 'uploads', subdir);
  ensureDir(dest);
  return multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, dest);
    },
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname) || '';
      const base = path.basename(file.originalname, ext).replace(/\s+/g, '_');
      const stamp = Date.now();
      cb(null, `${base}_${stamp}${ext}`);
    },
  });
}

function kycFileFilter(req, file, cb) {
  const m = String(file.mimetype || '').toLowerCase();
  if (ALLOWED_DOC_MIMES.has(m)) {
    return cb(null, true);
  }
  cb(new Error('Use JPEG or PNG only.'));
}

const driverUpload = multer({
  storage: createStorage('driver-docs'),
  limits: {
    fileSize: maxFileBytes,
  },
  fileFilter: kycFileFilter,
});

const unionUpload = multer({
  storage: createStorage('union-docs'),
  limits: {
    fileSize: maxFileBytes,
  },
  fileFilter: kycFileFilter,
});

function multerErrorResponse(err, res) {
  if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      success: false,
      message: `File too large. Maximum size is ${limitsPayload.maxFileMb} MB.`,
      limits: limitsPayload,
    });
  }
  const msg =
    err && err.message
      ? err.message
      : 'Upload failed';
  return res.status(400).json({
    success: false,
    message: msg,
    limits: limitsPayload,
  });
}

async function finalizeKycFile(file) {
  const absolutePath = path.join(file.destination, file.filename);
  let st;
  try {
    st = await fs.promises.stat(absolutePath);
  } catch (_) {
    return { ok: false, status: 500, message: 'Upload save failed' };
  }
  if (st.size < minFileBytes) {
    try {
      await fs.promises.unlink(absolutePath);
    } catch (_) {
      // ignore
    }
    return {
      ok: false,
      status: 400,
      message: `Too small — minimum ${limitsPayload.minFileKb} KB.`,
    };
  }
  const mimetype = String(file.mimetype || '').toLowerCase();
  try {
    if (mimetype.startsWith('image/')) {
      await applyKycWatermark(absolutePath, mimetype);
    }
  } catch (wmErr) {
    logger.warn('KYC file watermark failed', {
      message: wmErr && wmErr.message,
      mimetype,
    });
    try {
      await fs.promises.unlink(absolutePath);
    } catch (_) {
      // ignore
    }
    return {
      ok: false,
      status: 500,
      message: 'Could not process file. Try another JPEG or PNG.',
    };
  }
  return { ok: true };
}

// POST /api/uploads/driver-doc
router.post(
  '/driver-doc',
  authenticate,
  uploadDocLimiter,
  (req, res) => {
    driverUpload.single('file')(req, res, async (err) => {
      if (err) {
        return multerErrorResponse(err, res);
      }
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded',
          limits: limitsPayload,
        });
      }
      const done = await finalizeKycFile(req.file);
      if (!done.ok) {
        return res.status(done.status).json({
          success: false,
          message: done.message,
          limits: limitsPayload,
        });
      }
      const relativeUrl = `/uploads/driver-docs/${req.file.filename}`;
      res.json({
        success: true,
        url: relativeUrl,
        data: { url: relativeUrl },
        limits: limitsPayload,
      });
    });
  }
);

// POST /api/uploads/union-doc
router.post(
  '/union-doc',
  authenticate,
  uploadDocLimiter,
  (req, res) => {
    unionUpload.single('file')(req, res, async (err) => {
      if (err) {
        return multerErrorResponse(err, res);
      }
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded',
          limits: limitsPayload,
        });
      }
      const done = await finalizeKycFile(req.file);
      if (!done.ok) {
        return res.status(done.status).json({
          success: false,
          message: done.message,
          limits: limitsPayload,
        });
      }
      const relativeUrl = `/uploads/union-docs/${req.file.filename}`;
      res.json({
        success: true,
        url: relativeUrl,
        data: { url: relativeUrl },
        limits: limitsPayload,
      });
    });
  }
);

module.exports = router;
