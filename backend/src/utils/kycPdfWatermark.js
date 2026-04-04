const fs = require('fs');
const { PDFDocument, rgb, degrees, StandardFonts } = require('pdf-lib');
const { LINE_PRIMARY, LINE_SECONDARY, LINE_TOP_MARK } = require('./kycWatermarkStrings');

const MAX_PAGES = 40;

function fitFontSize(text, font, maxWidth, startSize, minSize) {
  let s = startSize;
  while (s > minSize && font.widthOfTextAtSize(text, s) > maxWidth) {
    s -= 0.5;
  }
  return s;
}

/**
 * Stamp each page: diagonal centre text + bottom banner (same messaging as image watermark).
 * Overwrites file in place via temp file.
 *
 * @param {string} absolutePath
 * @returns {Promise<boolean>}
 */
async function applyKycPdfWatermark(absolutePath) {
  const bytes = await fs.promises.readFile(absolutePath);
  const doc = await PDFDocument.load(bytes, { updateMetadata: false });
  const pages = doc.getPages();
  if (pages.length > MAX_PAGES) {
    throw new Error(`PDF has too many pages (max ${MAX_PAGES} for KYC upload)`);
  }

  const fontBold = await doc.embedFont(StandardFonts.HelveticaBold);
  const fontRegular = await doc.embedFont(StandardFonts.Helvetica);

  for (const page of pages) {
    const width = page.getWidth();
    const height = page.getHeight();
    const minSide = Math.min(width, height);

    // Very large semi-transparent mark at upper area (readable at a glance).
    const topMarkSize = Math.max(36, minSide * 0.2);
    const wTop = fontBold.widthOfTextAtSize(LINE_TOP_MARK, topMarkSize);
    page.drawText(LINE_TOP_MARK, {
      x: (width - wTop) / 2,
      y: height - topMarkSize * 1.15,
      size: topMarkSize,
      font: fontBold,
      color: rgb(0.35, 0.35, 0.35),
      opacity: 0.22,
    });

    const bigSize = Math.max(26, minSide * 0.11);
    const subSize = Math.max(8, bigSize * 0.26);
    const wPrimary = fontBold.widthOfTextAtSize(LINE_PRIMARY, bigSize);
    const wSecondary = fontRegular.widthOfTextAtSize(LINE_SECONDARY, subSize);

    page.drawText(LINE_PRIMARY, {
      x: (width - wPrimary) / 2,
      y: height / 2 + bigSize * 0.15,
      size: bigSize,
      font: fontBold,
      color: rgb(0.45, 0.45, 0.45),
      opacity: 0.42,
      rotate: degrees(-34),
    });

    page.drawText(LINE_SECONDARY, {
      x: (width - wSecondary) / 2,
      y: height / 2 - bigSize * 0.45,
      size: subSize,
      font: fontRegular,
      color: rgb(0.42, 0.42, 0.42),
      opacity: 0.36,
      rotate: degrees(-34),
    });

    const fontLarge = Math.max(11, minSide * 0.038);
    let fontSmall = Math.max(7.5, fontLarge * 0.48);
    const marginX = 14;
    const maxTextW = width - marginX * 2;
    fontSmall = fitFontSize(LINE_SECONDARY, fontRegular, maxTextW, fontSmall, 6);

    const bandH = fontLarge * 1.35 + fontSmall * 1.25 + 20;

    page.drawRectangle({
      x: 0,
      y: 0,
      width,
      height: bandH,
      color: rgb(0, 0, 0),
      opacity: 0.58,
    });

    const wFoot1 = fontBold.widthOfTextAtSize(LINE_PRIMARY, fontLarge);
    page.drawText(LINE_PRIMARY, {
      x: (width - wFoot1) / 2,
      y: bandH - fontLarge - 6,
      size: fontLarge,
      font: fontBold,
      color: rgb(1, 1, 1),
      opacity: 0.96,
    });

    const wFoot2 = fontRegular.widthOfTextAtSize(LINE_SECONDARY, fontSmall);
    page.drawText(LINE_SECONDARY, {
      x: (width - wFoot2) / 2,
      y: 8,
      size: fontSmall,
      font: fontRegular,
      color: rgb(0.94, 0.94, 0.94),
      opacity: 0.92,
    });
  }

  const outBytes = await doc.save({ useObjectStreams: false });
  const tmp = `${absolutePath}.wm.${process.pid}.${Date.now()}.tmp`;
  await fs.promises.writeFile(tmp, outBytes);
  await fs.promises.rename(tmp, absolutePath);
  return true;
}

module.exports = { applyKycPdfWatermark, MAX_PAGES };
