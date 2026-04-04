const fs = require('fs');
const sharp = require('sharp');
const { LINE_PRIMARY, LINE_SECONDARY } = require('./kycWatermarkStrings');

const SHARP_READ_OPTS = { failOn: 'none' };

/**
 * Centre diagonal watermark + bottom legal banner on KYC images (JPEG/PNG/WebP).
 * PDFs are skipped. Overwrites the file in place via a temp file.
 *
 * @param {string} absolutePath
 * @param {string} mimetype e.g. image/jpeg
 * @returns {Promise<boolean>} true if image was processed
 */
async function applyKycWatermark(absolutePath, mimetype) {
  const m = String(mimetype || '').toLowerCase();
  if (!m.startsWith('image/')) return false;

  const meta = await sharp(absolutePath, SHARP_READ_OPTS).metadata();
  const w = meta.width || 0;
  const h = meta.height || 0;
  if (w < 1 || h < 1) return false;

  const minSide = Math.min(w, h);
  const fontLarge = Math.max(18, Math.round(minSide * 0.048));
  const fontSmall = Math.max(12, Math.round(fontLarge * 0.52));
  const padY = Math.max(8, Math.round(fontLarge * 0.4));
  const bandH = padY * 2 + fontLarge + fontSmall + Math.round(fontLarge * 0.35);

  const cx = w / 2;
  const cy = h / 2;
  const angle = -34;
  const centerFont = Math.max(32, Math.round(minSide * 0.13));
  const centerSubFont = Math.max(14, Math.round(centerFont * 0.28));
  const centerGap = Math.round(centerFont * 0.55);

  const svg = `
<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="band" x1="0" y1="1" x2="0" y2="0">
      <stop offset="0" stop-color="rgba(0,0,0,0.62)"/>
      <stop offset="1" stop-color="rgba(0,0,0,0.28)"/>
    </linearGradient>
  </defs>
  <g transform="translate(${cx}, ${cy}) rotate(${angle})">
    <text x="0" y="${-centerGap / 2}"
          text-anchor="middle" dominant-baseline="middle"
          fill="rgba(255,255,255,0.26)"
          font-family="Arial, Helvetica, sans-serif"
          font-size="${centerFont}"
          font-weight="800"
          stroke="rgba(0,0,0,0.45)"
          stroke-width="${Math.max(2, Math.round(centerFont * 0.04))}"
          paint-order="stroke fill">${escapeXml(LINE_PRIMARY)}</text>
    <text x="0" y="${centerGap / 2}"
          text-anchor="middle" dominant-baseline="middle"
          fill="rgba(255,255,255,0.2)"
          font-family="Arial, Helvetica, sans-serif"
          font-size="${centerSubFont}"
          font-weight="600"
          stroke="rgba(0,0,0,0.4)"
          stroke-width="1.5"
          paint-order="stroke fill">${escapeXml(LINE_SECONDARY)}</text>
  </g>
  <rect x="0" y="${h - bandH}" width="${w}" height="${bandH}" fill="url(#band)"/>
  <text x="${w / 2}" y="${h - padY - fontSmall - Math.round(fontLarge * 0.15)}"
        text-anchor="middle"
        fill="rgba(255,255,255,0.98)"
        font-family="Arial, Helvetica, sans-serif"
        font-size="${fontLarge}"
        font-weight="700"
        stroke="rgba(0,0,0,0.4)"
        stroke-width="2"
        paint-order="stroke fill">${escapeXml(LINE_PRIMARY)}</text>
  <text x="${w / 2}" y="${h - padY}"
        text-anchor="middle"
        fill="rgba(255,255,255,0.94)"
        font-family="Arial, Helvetica, sans-serif"
        font-size="${fontSmall}"
        font-weight="600"
        stroke="rgba(0,0,0,0.35)"
        stroke-width="1"
        paint-order="stroke fill">${escapeXml(LINE_SECONDARY)}</text>
</svg>`.trim();

  const overlay = Buffer.from(svg);

  const tmp = `${absolutePath}.wm.${process.pid}.${Date.now()}.tmp`;
  let pipeline = sharp(absolutePath, SHARP_READ_OPTS).composite([
    { input: overlay, blend: 'over' },
  ]);

  if (m === 'image/png') {
    pipeline = pipeline.png({ compressionLevel: 6 });
  } else if (m === 'image/webp') {
    pipeline = pipeline.webp({ quality: 85 });
  } else {
    pipeline = pipeline.jpeg({ quality: 88, mozjpeg: true });
  }

  await pipeline.toFile(tmp);
  await fs.promises.rename(tmp, absolutePath);
  return true;
}

function escapeXml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

module.exports = {
  applyKycWatermark,
  LINE_PRIMARY,
  LINE_SECONDARY,
};
