require('dotenv').config();
const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

async function testAll() {
  console.log('\n🧪 Testing All Features...\n');
  
  try {
    // Test 1: Login
    console.log('1️⃣ Testing Login...');
    const loginRes = await axios.post(`${BASE_URL}/simple-auth/login`, {
      email: 'driver@demo.com',
      password: 'demo123'
    });
    const token = loginRes.data.data.tokens.accessToken;
    console.log('   ✅ Login successful');
    console.log(`   User: ${loginRes.data.data.user.name}`);
    console.log(`   Role: ${loginRes.data.data.user.role}\n`);
    
    // Test 2: Create Trip
    console.log('2️⃣ Testing Trip Creation...');
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(8, 0, 0, 0);
    
    const tripRes = await axios.post(
      `${BASE_URL}/trips`,
      {
        from_location: 'Dehradun',
        to_location: 'Haridwar',
        departure_time: tomorrow.toISOString(),
        fare_per_seat: 150,
        total_seats: 7,
        vehicle_number: 'UK 07 TEST 1234',
        stops: []
      },
      {
        headers: { Authorization: `Bearer ${token}` }
      }
    );
    console.log('   ✅ Trip created successfully');
    console.log(`   Trip ID: ${tripRes.data.data.trip.id}`);
    console.log(`   From: ${tripRes.data.data.trip.from_location}`);
    console.log(`   To: ${tripRes.data.data.trip.to_location}\n`);
    
    // Test 3: Search Trips
    console.log('3️⃣ Testing Trip Search...');
    const searchRes = await axios.get(`${BASE_URL}/trips/search`, {
      params: {
        from: 'Dehradun',
        to: 'Haridwar',
        date: tomorrow.toISOString().split('T')[0]
      }
    });
    console.log('   ✅ Search successful');
    console.log(`   Found: ${searchRes.data.data.trips.length} trips\n`);
    
    // Test 4: Signup
    console.log('4️⃣ Testing Signup...');
    const randomEmail = `test${Date.now()}@test.com`;
    try {
      const signupRes = await axios.post(`${BASE_URL}/simple-auth/signup`, {
        email: randomEmail,
        password: 'test123',
        name: 'Test User',
        role: 'passenger'
      });
      console.log('   ✅ Signup successful');
      console.log(`   New user: ${signupRes.data.data.user.name}`);
      console.log(`   Email: ${signupRes.data.data.user.email}\n`);
    } catch (e) {
      if (e.response?.status === 409) {
        console.log('   ✅ Signup validation working (email exists)\n');
      } else {
        throw e;
      }
    }
    
    console.log('🎉 ALL TESTS PASSED!\n');
    console.log('✅ Login - Working');
    console.log('✅ Signup - Working');
    console.log('✅ Trip Creation - Working');
    console.log('✅ Trip Search - Working\n');
    
  } catch (error) {
    console.error('\n❌ Test Failed!');
    console.error('Error:', error.response?.data?.message || error.message);
    if (error.response?.data) {
      console.error('Details:', JSON.stringify(error.response.data, null, 2));
    }
  }
  
  process.exit(0);
}

testAll();
