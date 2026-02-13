require('dotenv').config();
const { Client } = require('pg');

async function setupDatabase() {
  console.log('🔧 LuhaRide Database Setup\n');
  
  // First, connect to postgres database (default) to create luharide database
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: 'postgres', // Connect to default database first
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
  });
  
  try {
    console.log('Step 1: Connecting to PostgreSQL...');
    await client.connect();
    console.log('✅ Connected successfully!\n');
    
    // Check if luharide database exists
    console.log('Step 2: Checking if "luharide" database exists...');
    const checkDb = await client.query(
      "SELECT 1 FROM pg_database WHERE datname = 'luharide'"
    );
    
    if (checkDb.rows.length === 0) {
      console.log('Creating "luharide" database...');
      await client.query('CREATE DATABASE luharide');
      console.log('✅ Database "luharide" created!\n');
    } else {
      console.log('✅ Database "luharide" already exists\n');
    }
    
    await client.end();
    
    // Now connect to luharide database to enable PostGIS
    console.log('Step 3: Connecting to "luharide" database...');
    const luharideClient = new Client({
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 5432,
      database: 'luharide',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD,
    });
    
    await luharideClient.connect();
    console.log('✅ Connected to luharide database\n');
    
    // Enable PostGIS extension
    console.log('Step 4: Enabling PostGIS extension...');
    await luharideClient.query('CREATE EXTENSION IF NOT EXISTS postgis');
    console.log('✅ PostGIS extension enabled!\n');
    
    // Verify PostGIS
    const postgisVersion = await luharideClient.query('SELECT PostGIS_Version()');
    console.log('PostGIS Version:', postgisVersion.rows[0].postgis_version);
    
    await luharideClient.end();
    
    console.log('\n🎉 Database setup complete!\n');
    console.log('Next steps:');
    console.log('1. Run migrations to create tables:');
    console.log('   npm run migrate\n');
    console.log('2. (Optional) Seed sample data:');
    console.log('   npm run seed\n');
    console.log('3. Start the server:');
    console.log('   npm run dev\n');
    
  } catch (error) {
    console.error('\n❌ Setup failed:', error.message);
    
    if (error.message.includes('password authentication failed')) {
      console.error('\n🔐 Password Authentication Issue:');
      console.error('Your password contains special characters: @, #');
      console.error('\nTry one of these solutions:\n');
      console.error('Option 1: Reset PostgreSQL password to something simpler');
      console.error('   1. Open pgAdmin or psql');
      console.error('   2. Run: ALTER USER postgres WITH PASSWORD \'simplepass123\';');
      console.error('   3. Update .env file with new password\n');
      console.error('Option 2: Escape special characters in .env');
      console.error('   Wrap password in single quotes if it has special chars\n');
    }
    
    process.exit(1);
  }
  
  process.exit(0);
}

setupDatabase();
