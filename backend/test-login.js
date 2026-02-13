require('dotenv').config();
const axios = require('axios');

async function testLogin() {
  try {
    console.log('Testing login API...\n');
    
    const response = await axios.post('http://localhost:3000/api/simple-auth/login', {
      email: 'driver@demo.com',
      password: 'demo123'
    });

    console.log('✅ Login successful!');
    console.log('User:', response.data.data.user.name);
    console.log('Role:', response.data.data.user.role);
    console.log('Token:', response.data.data.tokens.accessToken.substring(0, 50) + '...');
    
  } catch (error) {
    console.error('❌ Login failed!');
    console.error('Status:', error.response?.status);
    console.error('Message:', error.response?.data?.message || error.message);
  }
  
  process.exit(0);
}

testLogin();
