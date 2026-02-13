require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/config/database');

async function runSeeders() {
  try {
    console.log('🌱 Running database seeders...\n');

    // Read all seeder files
    const seedersDir = __dirname;
    const files = fs
      .readdirSync(seedersDir)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    for (const file of files) {
      console.log(`Running seeder: ${file}`);
      const filePath = path.join(seedersDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');

      await pool.query(sql);
      console.log(`✅ ${file} completed\n`);
    }

    console.log('✅ All seeders completed successfully!');
    console.log('📝 Note: User accounts should be created through app registration for proper security\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Seeder failed:', error);
    process.exit(1);
  }
}

runSeeders();
