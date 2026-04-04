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
 * One VERIFY at top + one footer (Verified by LuhaRide + disclaimer). No centre band / duplicate primary.
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
    const maxTextW = width - marginX * 2;

    const topMarkSize = Math.max(40, minSide * 0.18);
    const wTop = fontBold.widthOfTextAtSize(LINE_TOP_MARK, topMarkSize);
    page.drawText(LINE_TOP_MARK, {
      x: (width - wTop) / 2,
      y: height - topMarkSize * 1.15,
      size: topMarkSize,
      font: fontBold,
      color: rgb(0.15, 0.15, 0.15),
      opacity: 0.72,
    });

    let fontLarge = Math.max(12, minSide * 0.04);
    let fontSmall = Math.max(8, fontLarge * 0.48);
    fontSmall = fitFontSize(LINE_SECONDARY, fontRegular, maxTextW, fontSmall, 6.5);

    const bandH = fontLarge * 1.45 + fontSmall * 1.35 + 22;

    page.drawRectangle({
      x: 0,
      y: 0,
      width,
      height: bandH,
      color: rgb(0, 0, 0),
      opacity: 0.72,
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
