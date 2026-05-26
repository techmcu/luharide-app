const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const PDFDocument = require('pdfkit');
const {
  cleanPosterHeader,
  cleanPosterCustomText,
  getPosterTheme,
  getPosterThemeColors,
} = require('./unionHelpers');

// ─── PDF drawing helpers ─────────────────────────────────────────────────────

function _roundedRect(doc, x, y, w, h, r, fillColor) {
  doc.save().roundedRect(x, y, w, h, r).fill(fillColor).restore();
}

function _rect(doc, x, y, w, h, fillColor) {
  doc.save().rect(x, y, w, h).fill(fillColor).restore();
}

function _hRule(doc, x, y, w, strokeColor = '#E0E0E0', lw = 0.8) {
  doc.save()
    .moveTo(x, y)
    .lineTo(x + w, y)
    .strokeColor(strokeColor)
    .lineWidth(lw)
    .stroke()
    .restore();
}

function _fillRect(doc, x, y, w, h, color) {
  doc.save().rect(x, y, w, h).fill(color).restore();
}

function _fillRounded(doc, x, y, w, h, r, color) {
  doc.save().roundedRect(x, y, w, h, r).fill(color).restore();
}

function _hLine(doc, x, y, w, color = '#E0E0E0', lw = 0.6) {
  doc.save().moveTo(x, y).lineTo(x + w, y)
    .strokeColor(color).lineWidth(lw).stroke().restore();
}

function _vLine(doc, x, y, h, color = '#E0E0E0', lw = 0.6) {
  doc.save().moveTo(x, y).lineTo(x, y + h)
    .strokeColor(color).lineWidth(lw).stroke().restore();
}

function _tableHeader(doc, x, y, cols, rowH) {
  const totalW = cols.reduce((s, c) => s + c.w, 0);
  _fillRect(doc, x, y, totalW, rowH, '#FF6B00');
  let cx = x;
  for (const col of cols) {
    doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(9)
      .text(col.label, cx + 5, y + (rowH - 9) / 2 + 1,
        { width: col.w - 10, align: col.align || 'center' });
    cx += col.w;
  }
  return y + rowH;
}

function _tableRow(doc, x, y, cols, values, rowH, evenRow) {
  const totalW = cols.reduce((s, c) => s + c.w, 0);
  _fillRect(doc, x, y, totalW, rowH, evenRow ? '#FFF8F2' : '#FFFFFF');
  let cx = x;
  for (let i = 0; i < cols.length; i++) {
    doc.fillColor('#1A1A1A').font(i === 0 ? 'Helvetica-Bold' : 'Helvetica').fontSize(10)
      .text(String(values[i] ?? '—'), cx + 5, y + (rowH - 10) / 2 + 1,
        { width: cols[i].w - 10, align: cols[i].align || 'left', lineBreak: false });
    cx += cols[i].w;
  }
  _hLine(doc, x, y + rowH, totalW, '#F0E0D0');
  return y + rowH;
}

function _tableBorder(doc, x, y, totalW, totalH) {
  doc.save().rect(x, y, totalW, totalH)
    .strokeColor('#FF6B00').lineWidth(1.2).stroke().restore();
}

// ─── Single schedule poster ─────────────────────────────────────────────────

const getUnionSchedulePoster = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionId = resUnion.rows[0].union_id;

  const schedRes = await pool.query(
    `SELECT
       s.*,
       d.name          AS driver_name,
       d.vehicle_number,
       d.phone         AS driver_phone,
       u.name          AS union_name,
       u.poster_header AS poster_header,
       u.poster_custom_text AS poster_custom_text,
       u.poster_custom_text_position AS poster_custom_text_position,
       u.poster_layout_type AS poster_layout_type,
       u.poster_theme AS poster_theme
     FROM union_schedules s
     JOIN union_drivers d  ON d.id = s.union_driver_id
     JOIN unions u         ON u.id = s.union_id
     WHERE s.id = $1 AND s.union_id = $2`,
    [id, unionId]
  );
  if (schedRes.rows.length === 0) {
    throw ApiError.notFound('Schedule not found');
  }

  const s           = schedRes.rows[0];
  const from        = (s.from_location   || '').toString().toUpperCase();
  const to          = (s.to_location     || '').toString().toUpperCase();
  const vehicleNum  = (s.vehicle_number  || '').toString();
  const driverPhone = (s.driver_phone    || '').toString();
  const posterHeader = cleanPosterHeader(s.poster_header);
  const posterCustomText = cleanPosterCustomText(s.poster_custom_text);
  const posterCustomTextPosition = (s.poster_custom_text_position || 'right').toString().toLowerCase();
  const posterLayoutType = (s.poster_layout_type || 'classic').toString().toLowerCase();
  const posterTheme = getPosterTheme(s.poster_theme);
  const themeColors = getPosterThemeColors(posterTheme);
  logger.info(`PDF posterHeader length=${posterHeader.length} value="${posterHeader.slice(0, 80)}"`);
  const posterTitle = posterHeader || 'DAILY RIDE SCHEDULE';

  const pad  = (n) => String(n).padStart(2, '0');
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const dt   = s.departure_time ? new Date(s.departure_time) : null;
  const dateStr = dt ? `${pad(dt.getDate())} ${MONTHS[dt.getMonth()]} ${dt.getFullYear()}` : '—';
  const dayStr  = dt ? dt.toLocaleDateString('en-IN', { weekday: 'long' }) : '';
  const rawH    = dt ? dt.getHours() : 0;
  const ampm    = rawH >= 12 ? 'PM' : 'AM';
  const hr12    = rawH % 12 || 12;
  const timeStr = dt ? `${pad(hr12)}:${pad(dt.getMinutes())} ${ampm}` : '—';

  const safe  = (s) => s.replace(/[^\w]+/g, '-').slice(0, 40);
  const fname = `union-poster-${safe(from)}-${safe(to)}-${dateStr.replace(/ /g,'-')}.pdf`;

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fname}"`);

  const doc = new PDFDocument({ size: 'A4', margin: 0, info: {
    Title: `Ride Poster — ${posterTitle}`,
    Author: 'LuhaRide',
  }});
  doc.pipe(res);

  const W  = doc.page.width;
  const H  = doc.page.height;
  const ML = 32;
  const CW = W - ML * 2;

  _rect(doc, 0, 0, W, H, '#FFFDF5');
  _rect(doc, 0, 0, W, 5, themeColors.topStripe);

  const compact = posterLayoutType === 'compact';
  const headerH = compact ? 108 : 124;
  _rect(doc, 0, 5, W, headerH, themeColors.headerBg);

  let y = 18;
  const unLen = posterTitle.length;
  const unFontSize = unLen > 26 ? 20 : (unLen > 18 ? 24 : 28);
  doc.fillColor(themeColors.text)
     .font('Helvetica-Bold')
     .fontSize(unFontSize)
     .text(posterTitle.toUpperCase(), 0, y, { width: W, align: 'center' });
  y += unFontSize + 6;

  doc.fillColor(themeColors.subText)
     .font('Helvetica')
     .fontSize(9)
     .text('रोज़ाना टैक्सी समय', 0, y, {
       width: W, align: 'center', characterSpacing: 1.0
     });
  y += 12;

  _rect(doc, 0, 5 + headerH - 8, W, 8, '#FFFDF5');
  _roundedRect(doc, 0, 5 + headerH - 18, W, 22, 14, '#FFFDF5');

  if (posterCustomText && posterCustomTextPosition === 'left') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, 14, 5 + (headerH / 2) - 5, { width: 170, align: 'left' });
  } else if (posterCustomText && posterCustomTextPosition === 'right') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, W - 184, 5 + (headerH / 2) - 5, { width: 170, align: 'right' });
  }

  y = 5 + headerH + 6;

  const pillW = 130;
  const pillX = (W - pillW) / 2;
  _roundedRect(doc, pillX, y, pillW, 22, 11, '#212121');
  doc.fillColor('#FFC107')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('आज की सवारी', pillX, y + 6, {
       width: pillW, align: 'center', characterSpacing: 1.5
     });
  y += 36;

  const routeCardH = 108;
  _roundedRect(doc, ML, y, CW, routeCardH, 14, '#FFF8E1');
  _roundedRect(doc, ML, y, 6, routeCardH, 3, '#212121');

  const half = (CW - 20) / 2;

  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('से', ML + 14, y + 14, { width: half, align: 'left', characterSpacing: 1.2 });

  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(9)
     .text('तक', ML + CW / 2 + 6, y + 14, { width: half - 6, align: 'left', characterSpacing: 1.2 });

  const fromFontSize = from.length > 12 ? 20 : (from.length > 8 ? 24 : 28);
  doc.fillColor('#212121')
     .font('Helvetica-Bold')
     .fontSize(fromFontSize)
     .text(from, ML + 14, y + 30, { width: half - 10, align: 'left' });

  doc.fillColor('#F57F17')
     .font('Helvetica-Bold')
     .fontSize(22)
     .text('-->', ML + half + 2, y + 40, { width: 30, align: 'center' });

  const toFontSize = to.length > 12 ? 20 : (to.length > 8 ? 24 : 28);
  doc.fillColor('#212121')
     .font('Helvetica-Bold')
     .fontSize(toFontSize)
     .text(to, ML + CW / 2 + 6, y + 30, { width: half - 6, align: 'left' });

  const lineY = y + 78;
  doc.save()
     .moveTo(ML + 14, lineY)
     .lineTo(ML + CW - 14, lineY)
     .strokeColor('#FBC02D')
     .lineWidth(1.5)
     .dash(6, { space: 4 })
     .stroke()
     .restore();

  y += routeCardH + 16;

  const dtBoxH = 76;
  const dtW    = (CW - 10) / 2;

  _roundedRect(doc, ML, y, dtW, dtBoxH, 12, '#E3F2FD');
  _roundedRect(doc, ML, y, dtW, 5, 3, '#1565C0');
  doc.fillColor('#1565C0')
     .font('Helvetica').fontSize(9)
     .text('तारीख', ML, y + 14, { width: dtW, align: 'center', characterSpacing: 1.5 });
  doc.fillColor('#0D47A1')
     .font('Helvetica-Bold').fontSize(18)
     .text(dateStr, ML, y + 30, { width: dtW, align: 'center' });
  if (dayStr) {
    doc.fillColor('#1565C0')
       .font('Helvetica').fontSize(10)
       .text(dayStr, ML, y + 54, { width: dtW, align: 'center' });
  }

  const tx = ML + dtW + 10;
  _roundedRect(doc, tx, y, dtW, dtBoxH, 12, '#E8F5E9');
  _roundedRect(doc, tx, y, dtW, 5, 3, '#2E7D32');
  doc.fillColor('#2E7D32')
     .font('Helvetica').fontSize(9)
     .text('रवाना होने का समय', tx, y + 14, { width: dtW, align: 'center', characterSpacing: 1.2 });
  doc.fillColor('#1B5E20')
     .font('Helvetica-Bold').fontSize(22)
     .text(timeStr, tx, y + 28, { width: dtW, align: 'center' });

  y += dtBoxH + 16;

  if (vehicleNum) {
    const drvBoxH = 50;
    _roundedRect(doc, ML, y, CW, drvBoxH, 12, '#FFFDE7');
    _roundedRect(doc, ML, y, 6, drvBoxH, 3, '#212121');
    const pillVW = Math.min(200, vehicleNum.length * 11 + 40);
    _roundedRect(doc, ML + 16, y + 14, pillVW, 20, 5, '#FFF3CD');
    doc.fillColor('#424242')
       .font('Helvetica-Bold').fontSize(11)
       .text(`  Vehicle: ${vehicleNum}`, ML + 16, y + 19, { width: pillVW });
    y += drvBoxH + 16;
  }

  const bookH = driverPhone ? 62 : 50;
  _roundedRect(doc, ML, y, CW, bookH, 12, '#EDE7F6');
  _roundedRect(doc, ML, y, 6, bookH, 3, '#4527A0');

  doc.fillColor('#4527A0')
     .font('Helvetica-Bold').fontSize(9)
     .text('इस सवारी को बुक करें', ML + 16, y + 12, { characterSpacing: 1.5 });

  doc.fillColor('#311B92')
     .font('Helvetica-Bold').fontSize(13)
     .text('www.luharide.cloud', ML + 16, y + 28, { width: CW - 30 });

  if (driverPhone) {
    doc.fillColor('#5E35B1')
       .font('Helvetica').fontSize(11)
       .text(`Call driver: ${driverPhone}`, ML + 16, y + 46, { width: CW - 30 });
  }

  y += bookH + 16;

  _hRule(doc, ML, y, CW, '#E0E0E0');
  y += 12;
  doc.fillColor('#888888')
     .font('Helvetica').fontSize(9)
     .text(
       'सवारी बुक करने के लिए luharide.cloud पर जाएं। यह पोस्टर WhatsApp या लोकल ग्रुप में शेयर करें।',
       ML, y, { width: CW, align: 'center' }
     );

  const footerH  = 64;
  const footerY  = H - footerH;
  _rect(doc, 0, footerY, W, footerH, '#212121');
  _rect(doc, 0, footerY, W, 3, '#FFC107');

  doc.fillColor('#FFFFFF')
     .font('Helvetica-Bold').fontSize(12)
     .text('सवारी बुक करने या खोजने के लिए luharide.cloud पर जाएं', 0, footerY + 20, {
       width: W, align: 'center'
     });

  doc.end();
});

// ─── Combined poster ────────────────────────────────────────────────────────

const getUnionCombinedPoster = asyncHandler(async (req, res) => {
  const rawIds = (req.query.ids || '').toString().trim();
  if (!rawIds) throw ApiError.badRequest('No schedule IDs provided');

  const ids = rawIds.split(',').map(s => s.trim()).filter(Boolean).slice(0, 50);
  if (ids.length === 0) throw ApiError.badRequest('No valid IDs');

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved' LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) throw ApiError.forbidden('No approved union');
  const unionId = resUnion.rows[0].union_id;

  const placeholders = ids.map((_, i) => `$${i + 2}`).join(',');
  const schedRes = await pool.query(
    `SELECT
       s.id, s.from_location, s.to_location, s.departure_time, s.status,
       d.name AS driver_name, d.vehicle_number, d.phone AS driver_phone,
       u.name AS union_name, u.poster_header,
       u.poster_custom_text, u.poster_custom_text_position, u.poster_layout_type, u.poster_theme
     FROM union_schedules s
     JOIN union_drivers d ON d.id = s.union_driver_id
     JOIN unions u        ON u.id = s.union_id
     WHERE s.union_id = $1 AND s.id IN (${placeholders})
     ORDER BY s.from_location, s.to_location, s.departure_time ASC`,
    [unionId, ...ids]
  );

  if (schedRes.rows.length === 0) throw ApiError.notFound('No schedules found');

  const rows      = schedRes.rows;
  const posterTitle = cleanPosterHeader(rows[0].poster_header) || 'DAILY RIDE SCHEDULE';
  const posterHeader = cleanPosterHeader(rows[0].poster_header);
  const posterCustomText = cleanPosterCustomText(rows[0].poster_custom_text);
  const posterCustomTextPosition = (rows[0].poster_custom_text_position || 'right').toString().toLowerCase();
  const posterLayoutType = (rows[0].poster_layout_type || 'classic').toString().toLowerCase();
  const posterTheme = getPosterTheme(rows[0].poster_theme);
  const themeColors = getPosterThemeColors(posterTheme);
  logger.info(`Combined PDF posterHeader length=${posterHeader.length} value="${posterHeader.slice(0, 80)}"`);

  const pad  = n => String(n).padStart(2, '0');
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const DAYS   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  const formatDateShort = (dt) => `${pad(dt.getDate())} ${MONTHS[dt.getMonth()]} ${dt.getFullYear()}`;
  const formatDateFull  = (dt) => `${DAYS[dt.getDay()]}, ${pad(dt.getDate())} ${MONTHS[dt.getMonth()]} ${dt.getFullYear()}`;

  const departureDates = rows
    .map((r) => (r.departure_time ? new Date(r.departure_time) : null))
    .filter(Boolean);

  departureDates.sort((a, b) => a.getTime() - b.getTime());
  const firstDt = departureDates.length ? departureDates[0] : new Date();
  const lastDt  = departureDates.length ? departureDates[departureDates.length - 1] : firstDt;

  const dateRangeShort = formatDateShort(firstDt) === formatDateShort(lastDt)
    ? formatDateShort(firstDt)
    : `${formatDateShort(firstDt)} - ${formatDateShort(lastDt)}`;

  const dateLabel = formatDateFull(firstDt);

  const groups = new Map();
  for (const r of rows) {
    const key = `${(r.from_location||'').toUpperCase()} -> ${(r.to_location||'').toUpperCase()}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(r);
  }

  const safe = s => s.replace(/[^\w]+/g,'-').slice(0,40);
  const fname = `union-schedule-${dateLabel.replace(/[, ]+/g,'-')}.pdf`;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fname}"`);

  const doc = new PDFDocument({ size: 'A4', margin: 0, info: { Title: `${posterTitle} - Daily Schedule`, Author: 'LuhaRide' } });
  doc.pipe(res);

  const W   = doc.page.width;
  const H   = doc.page.height;
  const ML  = 28;
  const CW  = W - ML * 2;
  const FOOTER_H = 58;

  _fillRect(doc, 0, 0, W, H, '#FFFDF5');
  _fillRect(doc, 0, 0, W, 5, themeColors.topStripe);

  const compact = posterLayoutType === 'compact';
  const headerH = compact ? 90 : 104;
  _fillRect(doc, 0, 5, W, headerH, themeColors.headerBg);

  let y = 16;
  const unLen = posterTitle.length;
  const unFontSize = unLen > 26 ? 20 : (unLen > 18 ? 22 : 26);
  doc.fillColor(themeColors.text).font('Helvetica-Bold').fontSize(unFontSize)
    .text(posterTitle.toUpperCase(), 0, y, { width: W, align: 'center' });
  y += unFontSize + 4;

  doc.fillColor(themeColors.subText).font('Helvetica').fontSize(9)
    .text(`Daily taxi schedule  —  ${dateRangeShort.toUpperCase()}`, 0, y, {
      width: W,
      align: 'center',
      characterSpacing: 0.8,
    });

  if (posterCustomText && posterCustomTextPosition === 'left') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, 14, 5 + (headerH / 2) - 5, { width: 170, align: 'left' });
  } else if (posterCustomText && posterCustomTextPosition === 'right') {
    doc.fillColor('#424242').font('Helvetica').fontSize(9)
      .text(posterCustomText, W - 184, 5 + (headerH / 2) - 5, { width: 170, align: 'right' });
  }

  y = 5 + headerH + 4;

  const COL_DATE  = { label: 'Date',        w: 95,  align: 'center' };
  const COL_TIME  = { label: 'Time',        w: 70,  align: 'center' };
  const COL_DRV   = { label: 'Driver name', w: 185, align: 'left'   };
  const COL_VEH   = { label: 'Cab number',  w: 95, align: 'center' };
  const COL_PHONE = {
    label: 'Phone',
    w: CW - 95 - 70 - 185 - 95,
    align: 'center',
  };
  const COLS      = [COL_DATE, COL_TIME, COL_DRV, COL_VEH, COL_PHONE];
  const TOTAL_W  = COLS.reduce((s, c) => s + c.w, 0);
  const ROW_H    = rows.length > 40 ? 18 : (rows.length > 20 ? 20 : 22);
  const HDR_H    = 20;

  const ROUTE_COLORS = ['#E3B341', '#DDA15E', '#CFA36A', '#C97B63', '#4EA8DE', '#52B788'];
  let colorIdx = 0;

  for (const [routeKey, schedules] of groups) {
    const sectionH = HDR_H + 4 + schedules.length * ROW_H + 14;
    if (y + sectionH > H - FOOTER_H - 20) {
      doc.addPage({ size: 'A4', margin: 0 });
      _fillRect(doc, 0, 0, W, H, '#FAFAFA');
      y = 20;
    }

    const accentColor = ROUTE_COLORS[colorIdx % ROUTE_COLORS.length];
    colorIdx++;

    _fillRounded(doc, ML, y, TOTAL_W, HDR_H, 6, accentColor);
    doc.fillColor('#212121').font('Helvetica-Bold').fontSize(11)
      .text(`  ${routeKey}`, ML + 8, y + (HDR_H - 11) / 2 + 1,
        { width: TOTAL_W - 70, lineBreak: false });
    const cnt = schedules.length;
    const cntTxt = `${cnt} ride${cnt > 1 ? 's' : ''}`;
    doc.fillColor('#212121').font('Helvetica').fontSize(9)
      .text(cntTxt, ML, y + (HDR_H - 9) / 2 + 1,
        { width: TOTAL_W - 8, align: 'right' });
    y += HDR_H + 4;

    const tableStartY = y;
    y = _tableHeader(doc, ML, y, COLS, ROW_H);

    for (let i = 0; i < schedules.length; i++) {
      const s   = schedules[i];
      const dt  = s.departure_time ? new Date(s.departure_time) : null;
      const dateStr = dt ? formatDateShort(dt) : '—';
      const rawH = dt ? dt.getHours() : 0;
      const ampm = rawH >= 12 ? 'PM' : 'AM';
      const hr12 = rawH % 12 || 12;
      const timeStr = dt ? `${pad(hr12)}:${pad(dt.getMinutes())} ${ampm}` : '—';

      y = _tableRow(
        doc,
        ML,
        y,
        COLS,
        [
          dateStr,
          timeStr,
          s.driver_name || '—',
          s.vehicle_number || '—',
          s.driver_phone || '—',
        ],
        ROW_H,
        i % 2 === 0
      );
    }

    _tableBorder(doc, ML, tableStartY, TOTAL_W, ROW_H + schedules.length * ROW_H);

    let divX = ML;
    for (let i = 0; i < COLS.length - 1; i++) {
      divX += COLS[i].w;
      _vLine(doc, divX, tableStartY, ROW_H + schedules.length * ROW_H, '#F0D0C0', 0.5);
    }

    y += 10;
  }

  const footerY = H - FOOTER_H;
  _fillRect(doc, 0, footerY, W, FOOTER_H, '#212121');
  _fillRect(doc, 0, footerY, W, 3, '#FFC107');

  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(12)
    .text('Book or find rides online at luharide.cloud', 0, footerY + 20,
      { width: W, align: 'center' });

  doc.end();
});

module.exports = {
  getUnionSchedulePoster,
  getUnionCombinedPoster,
};
