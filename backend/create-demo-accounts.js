require('dotenv').config();
const { pool } = require('./src/config/database');
const bcrypt = require('bcryptjs');

async function createDemoAccounts() {
  try {
    console.log('🔄 Creating demo accounts...\n');

    const demoAccounts = [
      {
        email: 'passenger@demo.com',
        password: 'demo123',
        name: 'Demo Passenger',
        role: 'passenger'
      },
      {
        email: 'driver@demo.com',
        password: 'demo123',
        name: 'Demo Driver',
        role: 'driver'
      },
      {
        email: 'admin@demo.com',
        password: 'demo123',
        name: 'Demo Admin',
        role: 'union_admin'
      }
    ];

    for (const account of demoAccounts) {
      // Check if exists
      const existing = await pool.query(
        'SELECT id FROM users WHERE email = $1',
        [account.email]
      );

      if (existing.rows.length > 0) {
        console.log(`⚠️  ${account.email} already exists`);
        continue;
      }

      // Hash password
      const passwordHash = await bcrypt.hash(account.password, 10);

      // Create account (using dummy phone number)
      const dummyPhone = `98765432${10 + demoAccounts.indexOf(account)}`;
      
      const result = await pool.query(
        `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone)
         VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)
         RETURNING id, name, email, role`,
        [account.name, account.email, passwordHash, account.role, dummyPhone]
      );

      console.log(`✅ Created: ${account.email} (${account.role})`);
    }

    console.log('\n🎉 Demo accounts created successfully!');
    console.log('\n📝 Login Credentials:');
    console.log('   Passenger: passenger@demo.com / demo123');
    console.log('   Driver: driver@demo.com / demo123');
    console.log('   Admin: admin@demo.com / demo123\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating demo accounts:', error.message);
    process.exit(1);
  }
}

createDemoAccounts();
