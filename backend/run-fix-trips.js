require('dotenv').config();
const { pool } = require('./src/config/database');
const fs = require('fs');

async function runFix() {
  try {
    console.log('🔧 Fixing trips table...\n');
    
    const sql = fs.readFileSync('./fix-trips-table.sql', 'utf8');
    
    await pool.query(sql);
    
    console.log('✅ Trips table fixed!\n');
    
    // Verify
    const result = await pool.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'trips' 
      AND column_name IN ('total_seats', 'available_seats', 'from_location', 'to_location')
      ORDER BY column_name
    `);
    
    console.log('📊 Key columns:');
    result.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

runFix();
