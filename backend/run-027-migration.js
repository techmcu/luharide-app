require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');
const path = require('path');

const sql = fs.readFileSync(path.join(__dirname, 'migrations', '027_trips_created_source.sql'), 'utf8');

async function run() {
  try {
    await pool.query(sql);
    console.log('Migration 027 (trips.created_source) completed.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

run();
