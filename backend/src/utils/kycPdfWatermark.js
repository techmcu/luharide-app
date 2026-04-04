const fs = require('fs');
const { PDFDocument, rgb, StandardFonts } = require('pdf-lib');
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
 * Strong, readable stamps on every page (no fragile diagonal rotation).
 * Overwrites file in place via temp file.
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
    const marginX = Math.max(12, minSide * 0.02);

    // --- Large header mark (top of page in PDF coords) ---
    const topMarkSize = Math.max(44, minSide * 0.22);
    const wTop = fontBold.widthOfTextAtSize(LINE_TOP_MARK, topMarkSize);
    page.drawText(LINE_TOP_MARK, {
      x: (width - wTop) / 2,
      y: height - topMarkSize * 1.2,
      size: topMarkSize,
      font: fontBold,
      color: rgb(0.12, 0.12, 0.12),
      opacity: 0.78,
    });

    // --- Horizontal centre band (high contrast; always visible) ---
    const stripH = Math.max(minSide * 0.16, 48);
    const cy = height / 2;
    const stripBottom = cy - stripH / 2;

    page.drawRectangle({
      x: 0,
      y: stripBottom,
      width,
      height: stripH,
      color: rgb(0, 0, 0),
      opacity: 0.72,
    });

    const maxTextW = width - marginX * 2;
    let primarySize = Math.max(14, minSide * 0.045);
    primarySize = fitFontSize(LINE_PRIMARY, fontBold, maxTextW, primarySize, 10);
    const wPrimary = fontBold.widthOfTextAtSize(LINE_PRIMARY, primarySize);
    const hPrimary = fontBold.heightAtSize(primarySize);
    const textBaseY = cy - hPrimary * 0.35;

    page.drawText(LINE_PRIMARY, {
      x: (width - wPrimary) / 2,
      y: textBaseY,
      size: primarySize,
      font: fontBold,
      color: rgb(1, 1, 1),
      opacity: 1,
    });

    // --- Bottom legal band ---
    let fontLarge = Math.max(12, minSide * 0.04);
    let fontSmall = Math.max(8, fontLarge * 0.48);
    fontSmall = fitFontSize(LINE_SECONDARY, fontRegular, maxTextW, fontSmall, 6.5);

    const bandH = fontLarge * 1.4 + fontSmall * 1.35 + 22;

    page.drawRectangle({
      x: 0,
      y: 0,
      width,
      height: bandH,
      color: rgb(0, 0, 0),
      opacity: 0.75,
    });

    const wFoot1 = fontBold.widthOfTextAtSize(LINE_PRIMARY, fontLarge);
    page.drawText(LINE_PRIMARY, {
      x: (width - wFoot1) / 2,
      y: bandH - fontLarge - 8,
      size: fontLarge,
      font: fontBold,
      color: rgb(1, 1, 1),
      opacity: 1,
    });

    page.drawText(LINE_SECONDARY, {
      x: marginX,
      y: 10,
      size: fontSmall,
      font: fontRegular,
      color: rgb(0.94, 0.94, 0.94),
      opacity: 1,
      maxWidth: maxTextW,
      lineHeight: fontSmall * 1.12,
    });
  }

  const outBytes = await doc.save({ useObjectStreams: false });
  const tmp = `${absolutePath}.wm.${process.pid}.${Date.now()}.tmp`;
  await fs.promises.writeFile(tmp, outBytes);
  await fs.promises.rename(tmp, absolutePath);
  return true;
}

module.exports = { applyKycPdfWatermark, MAX_PAGES };
