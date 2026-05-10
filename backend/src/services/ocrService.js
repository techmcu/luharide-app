const path = require('path');
const fs = require('fs');
const fsPromises = require('fs').promises;
const sharp = require('sharp');
const logger = require('../config/logger');

const PROCESSED_DIR = path.join(__dirname, '../../uploads/poster-tmp');
if (!fs.existsSync(PROCESSED_DIR)) fs.mkdirSync(PROCESSED_DIR, { recursive: true });

const OCR_TIMEOUT_MS = 15_000;
const MAX_CONCURRENT_OCR = 2;
let _activeOcr = 0;

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('OCR timeout')), ms)),
  ]);
}

async function preprocessImage(inputPath) {
  const outName = `proc_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.jpg`;
  const outPath = path.join(PROCESSED_DIR, outName);
  await sharp(inputPath)
    .resize(1600, 1600, { fit: 'inside', withoutEnlargement: true })
    .grayscale()
    .sharpen()
    .normalize()
    .jpeg({ quality: 80 })
    .toFile(outPath);
  return outPath;
}

async function extractTextFromImage(filePath) {
  if (_activeOcr >= MAX_CONCURRENT_OCR) {
    throw new Error('OCR busy — try again in a few seconds');
  }
  _activeOcr++;
  let processedPath = null;
  let worker = null;
  try {
    processedPath = await preprocessImage(filePath);
    const { createWorker } = require('tesseract.js');
    worker = await createWorker('eng+hin', 1, { cacheMethod: 'readOnly' });
    const { data } = await withTimeout(worker.recognize(processedPath), OCR_TIMEOUT_MS);
    return data.text || '';
  } finally {
    _activeOcr--;
    if (worker) {
      try { await worker.terminate(); } catch (_) {}
    }
    if (processedPath) {
      fs.unlink(processedPath, () => {});
    }
  }
}

async function extractTextFromPdf(filePath) {
  try {
    const stat = await fsPromises.stat(filePath);
    if (stat.size > 5 * 1024 * 1024) {
      logger.warn('PDF too large for text extraction, trying image OCR');
      return extractTextFromImage(filePath);
    }
    const pdfParse = require('pdf-parse');
    const buf = await fsPromises.readFile(filePath);
    const data = await pdfParse(buf, { max: 3 });
    if (data.text && data.text.trim().length > 20) {
      return data.text;
    }
  } catch (err) {
    logger.warn('pdf-parse text extraction failed, trying image OCR', err.message);
  }
  return extractTextFromImage(filePath);
}

async function extractText(filePath, mimeType) {
  if (mimeType === 'application/pdf') {
    return extractTextFromPdf(filePath);
  }
  return extractTextFromImage(filePath);
}

function cleanupTempFiles() {
  try {
    const files = fs.readdirSync(PROCESSED_DIR);
    const cutoff = Date.now() - 5 * 60 * 1000;
    for (const f of files) {
      try {
        const fp = path.join(PROCESSED_DIR, f);
        const stat = fs.statSync(fp);
        if (stat.mtimeMs < cutoff) fs.unlinkSync(fp);
      } catch (err) {
        logger.warn(`Cleanup failed for ${f}: ${err.message}`);
      }
    }
  } catch (err) {
    logger.error('Temp cleanup scan failed:', err.message);
  }
}

setInterval(cleanupTempFiles, 5 * 60 * 1000);

module.exports = { extractText };
