const fs = require('fs');
const sharp = require('sharp');
const logger = require('../config/logger');
const { LINE_PRIMARY, LINE_SECONDARY, LINE_TOP_MARK } = require('./kycWatermarkStrings');

const SHARP_READ_OPTS = { failOn: 'none' };

function renderOverlayWithResvg(svg, width) {
  try {
    const { Resvg } = require('@resvg/resvg-js');
    const resvg = new Resvg(svg, {
      fitTo: { mode: 'width', value: width },
      background: 'rgba(0,0,0,0)',
      logLevel: 'off',
    });
    const png = resvg.render().asPng();
    return Buffer.from(png);
  } catch (e) {
    logger.warn('KYC: Resvg overlay failed, falling back to sharp SVG', {
      message: e && e.message,
    });
    return null;
  }
}

/**
 * Centre diagonal watermark + bottom legal banner on KYC images (JPEG/PNG/WebP).
 * PDFs are skipped. Overwrites the file in place via a temp file.
 */
async function applyKycWatermark(absolutePath, mimetype) {
  const m = String(mimetype || '').toLowerCase();
  if (!m.startsWith('image/')) return false;

  const meta = await sharp(absolutePath, SHARP_READ_OPTS).metadata();
  const w = meta.width || 0;
  const h = meta.height || 0;
  if (w < 1 || h < 1) return false;

  const minSide = Math.min(w, h);
  const fontLarge = Math.max(20, Math.round(minSide * 0.052));
  const fontSmall = Math.max(13, Math.round(fontLarge * 0.52));
  const padY = Math.max(10, Math.round(fontLarge * 0.42));
  const bandH = padY * 2 + fontLarge + fontSmall + Math.round(fontLarge * 0.35);

  const cx = w / 2;
  const cy = h / 2;
  const angle = -34;
  const centerFont = Math.max(36, Math.round(minSide * 0.14));
  const centerSubFont = Math.max(15, Math.round(centerFont * 0.28));
  const centerGap = Math.round(centerFont * 0.55);

  const topMarkFont = Math.max(48, Math.round(minSide * 0.2));
  const topMarkY = Math.round(topMarkFont * 0.9);

  const svg = `
<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="band" x1="0" y1="1" x2="0" y2="0">
      <stop offset="0" stop-color="rgba(0,0,0,0.78)"/>
      <stop offset="1" stop-color="rgba(0,0,0,0.45)"/>
    </linearGradient>
  </defs>
  <text x="${cx}" y="${topMarkY}"
        text-anchor="middle" dominant-baseline="middle"
        fill="rgba(30,30,30,0.72)"
        font-family="Arial, Helvetica, Liberation Sans, sans-serif"
        font-size="${topMarkFont}"
        font-weight="900"
        stroke="rgba(255,255,255,0.35)"
        stroke-width="${Math.max(2, Math.round(topMarkFont * 0.028))}"
        paint-order="stroke fill">${escapeXml(LINE_TOP_MARK)}</text>
  <g transform="translate(${cx}, ${cy}) rotate(${angle})">
    <text x="0" y="${-centerGap / 2}"
          text-anchor="middle" dominant-baseline="middle"
          fill="rgba(255,255,255,0.72)"
          font-family="Arial, Helvetica, Liberation Sans, sans-serif"
          font-size="${centerFont}"
          font-weight="800"
          stroke="rgba(0,0,0,0.65)"
          stroke-width="${Math.max(2, Math.round(centerFont * 0.045))}"
          paint-order="stroke fill">${escapeXml(LINE_PRIMARY)}</text>
    <text x="0" y="${centerGap / 2}"
          text-anchor="middle" dominant-baseline="middle"
          fill="rgba(255,255,255,0.62)"
          font-family="Arial, Helvetica, Liberation Sans, sans-serif"
          font-size="${centerSubFont}"
          font-weight="600"
          stroke="rgba(0,0,0,0.55)"
          stroke-width="2"
          paint-order="stroke fill">${escapeXml(LINE_SECONDARY)}</text>
  </g>
  <rect x="0" y="${h - bandH}" width="${w}" height="${bandH}" fill="url(#band)"/>
  <text x="${w / 2}" y="${h - padY - fontSmall - Math.round(fontLarge * 0.15)}"
        text-anchor="middle"
        fill="rgba(255,255,255,1)"
        font-family="Arial, Helvetica, Liberation Sans, sans-serif"
        font-size="${fontLarge}"
        font-weight="700"
        stroke="rgba(0,0,0,0.45)"
        stroke-width="2"
        paint-order="stroke fill">${escapeXml(LINE_PRIMARY)}</text>
  <text x="${w / 2}" y="${h - padY}"
        text-anchor="middle"
        fill="rgba(255,255,255,0.98)"
        font-family="Arial, Helvetica, Liberation Sans, sans-serif"
        font-size="${fontSmall}"
        font-weight="600"
        stroke="rgba(0,0,0,0.4)"
        stroke-width="1.5"
        paint-order="stroke fill">${escapeXml(LINE_SECONDARY)}</text>
</svg>`.trim();

  const overlay = renderOverlayWithResvg(svg, w) || Buffer.from(svg);

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
