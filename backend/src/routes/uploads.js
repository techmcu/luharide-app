const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

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

const driverUpload = multer({
  storage: createStorage('driver-docs'),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5 MB
  },
});

const unionUpload = multer({
  storage: createStorage('union-docs'),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5 MB
  },
});

// POST /api/uploads/driver-doc
router.post(
  '/driver-doc',
  authenticate,
  driverUpload.single('file'),
  (req, res) => {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }
    const relativeUrl = `/uploads/driver-docs/${req.file.filename}`;
    res.json({
      success: true,
      url: relativeUrl,
    });
  }
);

// POST /api/uploads/union-doc
router.post(
  '/union-doc',
  authenticate,
  unionUpload.single('file'),
  (req, res) => {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }
    const relativeUrl = `/uploads/union-docs/${req.file.filename}`;
    res.json({
      success: true,
      url: relativeUrl,
    });
  }
);

module.exports = router;

