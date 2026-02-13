require('dotenv').config();
console.log('Starting...');

try {
  console.log('Loading database...');
  const { pool } = require('./src/config/database');
  console.log('✅ Database loaded');
  
  setTimeout(() => {
    console.log('Exiting...');
    process.exit(0);
  }, 3000);
  
} catch (e) {
  console.error('❌ Error:', e.message);
  console.error(e.stack);
  process.exit(1);
}
