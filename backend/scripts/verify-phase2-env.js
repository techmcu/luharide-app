/**
 * Phase 2 — production env rules (JWT_SECRET, DB_PASSWORD) same as service startup.
 * Does not start HTTP. Run from backend/: npm run verify:phase2-env
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { validateConfig, config } = require('../src/config/env');

try {
  validateConfig();
  console.log('[verify:phase2-env] OK — validateConfig passed');
  console.log('[verify:phase2-env] NODE_ENV =', config.nodeEnv || '(unset)');

  if (String(config.nodeEnv || '').toLowerCase() === 'production') {
    const len = String(config.jwt.secret || '').length;
    console.log('[verify:phase2-env] JWT_SECRET length =', len, len >= 16 ? '(>= min)' : '(below min — should not happen if validate passed)');
    console.log('[verify:phase2-env] DB_PASSWORD set =', Boolean(config.db && config.db.password));
  } else {
    console.log(
      '[verify:phase2-env] Note: strict JWT/DB checks apply only when NODE_ENV=production'
    );
  }
} catch (e) {
  console.error('[verify:phase2-env] FAIL:', e.message);
  process.exit(1);
}
