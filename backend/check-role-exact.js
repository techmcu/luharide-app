require('dotenv').config();
const { pool } = require('./src/config/database');

async function checkRole() {
  try {
    const result = await pool.query(
      `SELECT 
        id, 
        name, 
        email, 
        role,
        length(role) as role_length,
        role = 'driver' as is_driver_exact
      FROM users 
      WHERE email = 'driver@demo.com'`
    );

    const user = result.rows[0];
    console.log('\n📊 Driver Role Analysis:\n');
    console.log('Name:', user.name);
    console.log('Email:', user.email);
    console.log('Role:', `"${user.role}"`);
    console.log('Role Length:', user.role_length);
    console.log('Is Exact "driver"?:', user.is_driver_exact);
    console.log('\nRole bytes:', Buffer.from(user.role).toString('hex'));
    
    // Test array includes
    const roles = ['driver'];
    console.log('\nTest: roles.includes(user.role)');
    console.log('Result:', roles.includes(user.role));
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkRole();
