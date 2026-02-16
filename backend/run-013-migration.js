require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname, 'migrations', '013_cancel_bio_luggage_recent.sql'), 'utf8');

async function run() {
  try {
    await pool.query(sql);
    console.log('Migration 013 (cancel, bio, luggage, recent_routes) completed.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

run();
