#!/usr/bin/env node
/**
 * Run migration 009 - notifications table
 * Run: node run-009-migration.js
 */
require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');
const path = require('path');

const sqlPath = path.join(__dirname, 'migrations', '009_notifications.sql');
const sql = fs.readFileSync(sqlPath, 'utf8');

pool.query(sql)
  .then(() => {
    console.log('✅ Migration 009 (notifications) completed');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  })
  .finally(() => pool.end());
