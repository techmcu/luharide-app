const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const logger = require('../../config/logger');
const userCache = require('../../utils/userCache');

const adminEmail = process.env.ADMIN_EMAIL
  ? process.env.ADMIN_EMAIL.toLowerCase().trim()
  : null;

function ensurePlatformAdmin(user) {
  const email = user?.email ? String(user.email).toLowerCase().trim() : null;
  if (!adminEmail || !email || email !== adminEmail) {
    throw ApiError.forbidden('Only app admin can perform this action');
  }
}

async function demoteUnionAdminsOrphanedByReject(unionId, queryFn = pool) {
  const r = await queryFn.query(
    `UPDATE users u
     SET role = CASE
       WHEN u.driver_verification_status = 'approved' THEN 'driver'
       ELSE 'passenger'
     END
     WHERE u.role = 'union_admin'
       AND u.id IN (SELECT user_id FROM union_admins WHERE union_id = $1)
       AND NOT EXISTS (
         SELECT 1
         FROM union_admins ua2
         INNER JOIN unions u2 ON u2.id = ua2.union_id
         WHERE ua2.user_id = u.id
           AND u2.status IN ('pending', 'approved')
       )
     RETURNING u.id`,
    [unionId]
  );
  // Role just changed → drop cached entries so the new (demoted) role is seen
  // immediately, not up to 60s later.
  for (const u of r.rows) userCache.invalidate(u.id);
  if (r.rowCount > 0) {
    logger.info(
      `Demoted ${r.rowCount} user(s) from union_admin after union ${unionId} rejection`
    );
  }
}

async function unlinkUnionAdminsForRejectedUnion(unionId, queryFn = pool) {
  await queryFn.query('DELETE FROM union_admins WHERE union_id = $1', [unionId]);
}

function cleanUnionName(raw) {
  if (!raw) return 'Taxi Union';
  let name = String(raw).trim();
  if (!name) return 'Taxi Union';

  name = name.replace(/[\x00-\x1F\x7F]/g, '');

  const tokens = name
    .split(/\s+/)
    .filter((t) => /[A-Za-zऀ-ॿ]/.test(t));
  if (tokens.length > 0) {
    name = tokens.join(' ');
  }

  name = name.replace(/\s+/g, ' ').trim();

  if (!name) return 'Taxi Union';

  return name;
}

function cleanPosterHeader(raw) {
  if (!raw) return '';
  let text = String(raw);
  text = text.replace(/[\x00-\x1F\x7F]/g, '');
  text = text.replace(/\s+/g, ' ').trim();
  return text;
}

function cleanPosterCustomText(raw) {
  if (!raw) return '';
  return String(raw)
    .replace(/[\x00-\x1F\x7F]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 120);
}

function getPosterTheme(themeRaw) {
  const theme = (themeRaw || 'saffron').toString().trim().toLowerCase();
  const themes = {
    saffron: { headerBg: '#FFC107', topStripe: '#212121', text: '#212121', subText: '#424242' },
    sky: { headerBg: '#B3E5FC', topStripe: '#1F2937', text: '#0F172A', subText: '#334155' },
    mint: { headerBg: '#C8E6C9', topStripe: '#1F2937', text: '#1B4332', subText: '#2D6A4F' },
    rose: { headerBg: '#F8BBD0', topStripe: '#1F2937', text: '#3F1D2E', subText: '#5B2A42' },
  };
  return themes[theme] ? theme : 'saffron';
}

function getPosterThemeColors(themeRaw) {
  const theme = getPosterTheme(themeRaw);
  const palette = {
    saffron: { headerBg: '#FFC107', topStripe: '#212121', text: '#212121', subText: '#424242' },
    sky: { headerBg: '#B3E5FC', topStripe: '#1F2937', text: '#0F172A', subText: '#334155' },
    mint: { headerBg: '#C8E6C9', topStripe: '#1F2937', text: '#1B4332', subText: '#2D6A4F' },
    rose: { headerBg: '#F8BBD0', topStripe: '#1F2937', text: '#3F1D2E', subText: '#5B2A42' },
  };
  return palette[theme];
}

module.exports = {
  ensurePlatformAdmin,
  demoteUnionAdminsOrphanedByReject,
  unlinkUnionAdminsForRejectedUnion,
  cleanUnionName,
  cleanPosterHeader,
  cleanPosterCustomText,
  getPosterTheme,
  getPosterThemeColors,
};
