const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const logger = require('../config/logger');

const PROCESSED_DIR = path.join(__dirname, '../../uploads/poster-tmp');
if (!fs.existsSync(PROCESSED_DIR)) fs.mkdirSync(PROCESSED_DIR, { recursive: true });

async function preprocessImage(inputPath) {
  const outName = `proc_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.png`;
  const outPath = path.join(PROCESSED_DIR, outName);
  await sharp(inputPath)
    .resize(2400, 2400, { fit: 'inside', withoutEnlargement: true })
    .grayscale()
    .sharpen()
    .normalize()
    .png()
    .toFile(outPath);
  return outPath;
}

async function extractTextFromImage(filePath) {
  let processedPath = null;
  let worker = null;
  try {
    processedPath = await preprocessImage(filePath);
    const { createWorker } = require('tesseract.js');
    worker = await createWorker('eng+hin', 1, {
      cacheMethod: 'readOnly',
    });
    const { data } = await worker.recognize(processedPath);
    return data.text || '';
  } finally {
    if (worker) {
      try { await worker.terminate(); } catch (_) { /* ignore */ }
    }
    if (processedPath && fs.existsSync(processedPath)) {
      fs.unlink(processedPath, () => {});
    }
  }
}

async function extractTextFromPdf(filePath) {
  try {
    const pdfParse = require('pdf-parse');
    const buf = fs.readFileSync(filePath);
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
    const cutoff = Date.now() - 30 * 60 * 1000;
    for (const f of files) {
      const fp = path.join(PROCESSED_DIR, f);
      const stat = fs.statSync(fp);
      if (stat.mtimeMs < cutoff) fs.unlinkSync(fp);
    }
  } catch (_) { /* ignore */ }
}

setInterval(cleanupTempFiles, 15 * 60 * 1000);

module.exports = { extractText };
