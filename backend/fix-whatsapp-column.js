#!/usr/bin/env node
require('dotenv').config();
const { pool } = require('./src/config/database');

(async () => {
  try {
    console.log('🔧 Ensuring whatsapp_number column exists on users...\n');
    await pool.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS whatsapp_number VARCHAR(20);");
    console.log('✅ whatsapp_number column is present.\n');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error adding whatsapp_number column:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
})();

