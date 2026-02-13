#!/usr/bin/env node
require('dotenv').config();
const { pool } = require('./src/config/database');

(async () => {
  try {
    console.log('🔍 Checking notifications table...\n');

    const tableResult = await pool.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_name = 'notifications'
    `);

    if (tableResult.rows.length === 0) {
      console.log('❌ notifications table does NOT exist');
      process.exit(0);
    }

    console.log('✅ notifications table exists\n');

    const columnsResult = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'notifications'
      ORDER BY ordinal_position
    `);

    console.log('Columns:');
    for (const row of columnsResult.rows) {
      console.log(` - ${row.column_name}: ${row.data_type}`);
    }

    const sampleResult = await pool.query(`
      SELECT id, user_id, type, title, is_read, created_at
      FROM notifications
      ORDER BY created_at DESC
      LIMIT 5
    `);

    console.log('\nLast 5 notifications:');
    if (sampleResult.rows.length === 0) {
      console.log(' (none)');
    } else {
      console.log(sampleResult.rows);
    }

    process.exit(0);
  } catch (err) {
    console.error('❌ Error checking notifications table:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
})();

