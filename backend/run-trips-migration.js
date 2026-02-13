require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  try {
    console.log('🔄 Running trips enhancement migration...');
    
    const sql = fs.readFileSync(
      path.join(__dirname, 'migrations', '003_enhance_trips.sql'),
      'utf8'
    );

    await pool.query(sql);
    
    console.log('✅ Trips table enhanced successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error(error);
    process.exit(1);
  }
}

runMigration();
