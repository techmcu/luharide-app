require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname, 'migrations', '012_notifications_body_and_data.sql'), 'utf8');

async function run() {
  try {
    await pool.query(sql);
    console.log('Migration 012 (notifications body + data) completed.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

run();
