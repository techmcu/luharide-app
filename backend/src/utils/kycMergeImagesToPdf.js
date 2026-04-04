const fs = require('fs');
const sharp = require('sharp');
const { PDFDocument } = require('pdf-lib');
const { applyKycPdfWatermark } = require('./kycPdfWatermark');

const SHARP_READ_OPTS = { failOn: 'none' };
const MAX_EDGE = 2200;

/**
 * Build a multi-page PDF from image files (already watermarked on upload).
 * Applies the same PDF stamp as other KYC PDFs, then writes to outputPath.
 *
 * @param {string[]} absoluteImagePaths
 * @param {string} outputPath
 */
async function mergeImagePathsToWatermarkedPdf(absoluteImagePaths, outputPath) {
  if (!absoluteImagePaths || absoluteImagePaths.length < 1) {
    throw new Error('mergeImagePathsToWatermarkedPdf: no images');
  }

  const doc = await PDFDocument.create();

  for (const imgPath of absoluteImagePaths) {
    const buf = await sharp(imgPath, SHARP_READ_OPTS)
      .rotate()
      .resize(MAX_EDGE, MAX_EDGE, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 88, mozjpeg: true })
      .toBuffer();

    const embedded = await doc.embedJpg(buf);
    const w = embedded.width;
    const h = embedded.height;
    const page = doc.addPage([w, h]);
    page.drawImage(embedded, { x: 0, y: 0, width: w, height: h });
  }

  const pdfBytes = await doc.save({ useObjectStreams: false });
  const tmp = `${outputPath}.part.${process.pid}.${Date.now()}`;
  await fs.promises.writeFile(tmp, pdfBytes);
  await fs.promises.rename(tmp, outputPath);
  await applyKycPdfWatermark(outputPath);
}

module.exports = { mergeImagePathsToWatermarkedPdf };
