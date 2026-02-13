require('dotenv').config();
const { Pool } = require('pg');

console.log('🔍 Testing PostgreSQL Connection...\n');
console.log('Configuration:');
console.log(`  Host: ${process.env.DB_HOST}`);
console.log(`  Port: ${process.env.DB_PORT}`);
console.log(`  Database: ${process.env.DB_NAME}`);
console.log(`  User: ${process.env.DB_USER}`);
console.log(`  Password: ${'*'.repeat(process.env.DB_PASSWORD?.length || 0)}\n`);

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'luharide',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
});

async function testConnection() {
  try {
    console.log('Attempting to connect...');
    const client = await pool.connect();
    console.log('✅ Connection successful!\n');
    
    const result = await client.query('SELECT version()');
    console.log('PostgreSQL Version:');
    console.log(result.rows[0].version);
    
    client.release();
    await pool.end();
    
    console.log('\n✅ All tests passed! Your database connection is working.');
    console.log('\nNext steps:');
    console.log('1. Create the database if it doesn\'t exist:');
    console.log('   CREATE DATABASE luharide;');
    console.log('2. Run migrations:');
    console.log('   npm run migrate');
    
  } catch (error) {
    console.error('❌ Connection failed!\n');
    console.error('Error:', error.message);
    console.error('\nCommon solutions:');
    
    if (error.message.includes('password authentication failed')) {
      console.error('1. Check your password in the .env file');
      console.error('2. If password has special characters, try wrapping it in quotes');
      console.error('3. Try resetting the password in PostgreSQL:');
      console.error('   ALTER USER postgres WITH PASSWORD \'newpassword\';');
    } else if (error.message.includes('does not exist')) {
      console.error('1. Create the database first:');
      console.error('   CREATE DATABASE luharide;');
    } else if (error.message.includes('Connection refused')) {
      console.error('1. Make sure PostgreSQL service is running');
      console.error('2. Check if port 5432 is correct');
    }
  }
  
  process.exit();
}

testConnection();
