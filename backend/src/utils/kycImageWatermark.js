const fs = require('fs');
const sharp = require('sharp');

const LINE_PRIMARY = 'Verified by LuhaRide';
const LINE_SECONDARY =
  'Uploaded for KYC verification only. Not for any other use.';

/**
 * Apply a bottom-centre watermark banner to a saved KYC image (JPEG/PNG/WebP).
 * PDFs are skipped. Overwrites the file in place via a temp file.
 *
 * @param {string} absolutePath
 * @param {string} mimetype e.g. image/jpeg
 * @returns {Promise<boolean>} true if image was processed
 */
async function applyKycWatermark(absolutePath, mimetype) {
  const m = String(mimetype || '').toLowerCase();
  if (!m.startsWith('image/')) return false;

  const meta = await sharp(absolutePath).metadata();
  const w = meta.width || 0;
  const h = meta.height || 0;
  if (w < 1 || h < 1) return false;

  const fontLarge = Math.max(16, Math.round(Math.min(w, h) * 0.045));
  const fontSmall = Math.max(11, Math.round(fontLarge * 0.52));
  const padY = Math.max(8, Math.round(fontLarge * 0.4));
  const bandH = padY * 2 + fontLarge + fontSmall + Math.round(fontLarge * 0.35);

  const svg = `
<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="band" x1="0" y1="1" x2="0" y2="0">
      <stop offset="0" stop-color="rgba(0,0,0,0.55)"/>
      <stop offset="1" stop-color="rgba(0,0,0,0.22)"/>
    </linearGradient>
  </defs>
  <rect x="0" y="${h - bandH}" width="${w}" height="${bandH}" fill="url(#band)"/>
  <text x="${w / 2}" y="${h - padY - fontSmall - Math.round(fontLarge * 0.15)}"
        text-anchor="middle"
        fill="rgba(255,255,255,0.95)"
        font-family="Arial, Helvetica, sans-serif"
        font-size="${fontLarge}"
        font-weight="700"
        stroke="rgba(0,0,0,0.35)"
        stroke-width="2"
        paint-order="stroke fill">${escapeXml(LINE_PRIMARY)}</text>
  <text x="${w / 2}" y="${h - padY}"
        text-anchor="middle"
        fill="rgba(255,255,255,0.9)"
        font-family="Arial, Helvetica, sans-serif"
        font-size="${fontSmall}"
        font-weight="500"
        stroke="rgba(0,0,0,0.3)"
        stroke-width="1"
        paint-order="stroke fill">${escapeXml(LINE_SECONDARY)}</text>
</svg>`.trim();

  const overlay = Buffer.from(svg);

  const tmp = `${absolutePath}.wm.${process.pid}.${Date.now()}.tmp`;
  let pipeline = sharp(absolutePath).composite([{ input: overlay, blend: 'over' }]);

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

module.exports = { applyKycWatermark, LINE_PRIMARY, LINE_SECONDARY };
