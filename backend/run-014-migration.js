require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname, 'migrations', '014_trip_started_at.sql'), 'utf8');

async function run() {
  try {
    await pool.query(sql);
    console.log('Migration 014 (trips.started_at for rating rule) completed.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

run();
