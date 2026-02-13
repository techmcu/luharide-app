require('dotenv').config();
const axios = require('axios');

async function testCreateTrip() {
  try {
    console.log('Step 1: Login as driver...\n');
    
    // Login first
    const loginResponse = await axios.post('http://localhost:3000/api/simple-auth/login', {
      email: 'driver@demo.com',
      password: 'demo123'
    });

    const token = loginResponse.data.data.tokens.accessToken;
    const user = loginResponse.data.data.user;
    
    console.log('✅ Login successful!');
    console.log('User:', user.name);
    console.log('Role:', user.role);
    console.log('Token:', token.substring(0, 30) + '...\n');

    console.log('Step 2: Creating trip...\n');

    // Create trip
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(8, 0, 0, 0);
    
    const tripData = {
      from_location: 'Dehradun',
      to_location: 'Haridwar',
      departure_time: tomorrow.toISOString(),
      fare_per_seat: 150,
      total_seats: 7,
      vehicle_number: 'UK 07 AB 1234',
      stops: []
    };
    
    console.log('Trip data:', JSON.stringify(tripData, null, 2));
    
    const tripResponse = await axios.post(
      'http://localhost:3000/api/trips',
      tripData,
      {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      }
    );

    console.log('✅ Trip created successfully!');
    console.log('Trip ID:', tripResponse.data.data.trip.id);
    console.log('From:', tripResponse.data.data.trip.from_location);
    console.log('To:', tripResponse.data.data.trip.to_location);
    console.log('Status:', tripResponse.data.data.trip.status);
    
  } catch (error) {
    console.error('❌ Error!');
    console.error('Status:', error.response?.status);
    console.error('Message:', error.response?.data?.message || error.message);
    if (error.response?.status === 403) {
      console.error('\n⚠️  403 Forbidden - Role permission issue!');
      console.error('Required roles:', error.response?.data?.message);
    }
  }
  
  process.exit(0);
}

testCreateTrip();
