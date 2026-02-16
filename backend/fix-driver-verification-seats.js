/**
 * Fix existing drivers who don't have driver_verification_requests
 * Adds Mahindra Bolero 7-seater as default so they can create trips
 * Run: node fix-driver-verification-seats.js
 */
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function fix() {
  const client = await pool.connect();
  try {
    // Get all users with role=driver who don't have verification record
    const drivers = await client.query(
      `SELECT u.id, u.email, u.name 
       FROM users u 
       LEFT JOIN driver_verification_requests dvr ON dvr.user_id = u.id 
       WHERE u.role = 'driver' AND dvr.id IS NULL`
    );

    console.log(`Found ${drivers.rows.length} driver(s) without verification record`);

    for (const d of drivers.rows) {
      await client.query(
        `INSERT INTO driver_verification_requests (
          user_id, driving_license_number, vehicle_registration, vehicle_type, vehicle_model, vehicle_model_id, vehicle_capacity, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'approved')
        ON CONFLICT (user_id) DO UPDATE SET
          vehicle_capacity = 7,
          vehicle_registration = COALESCE(driver_verification_requests.vehicle_registration, 'FIX-001'),
          vehicle_type = COALESCE(driver_verification_requests.vehicle_type, 'SUV'),
          vehicle_model = COALESCE(driver_verification_requests.vehicle_model, 'Mahindra Bolero 7-Seater'),
          vehicle_model_id = COALESCE(driver_verification_requests.vehicle_model_id, 'mahindra_bolero_suv'),
          status = 'approved',
          updated_at = CURRENT_TIMESTAMP`,
        [d.id, 'DL-FIX-001', 'FIX-001', 'SUV', 'Mahindra Bolero 7-Seater', 'mahindra_bolero_suv', 7]
      );
      console.log(`  ✓ Fixed: ${d.email} (${d.name})`);
    }

    // Also fix any verification records with null vehicle_capacity
    const nullCap = await client.query(
      `UPDATE driver_verification_requests 
       SET vehicle_capacity = 7, 
           vehicle_model = COALESCE(vehicle_model, 'Mahindra Bolero 7-Seater'),
           vehicle_model_id = COALESCE(vehicle_model_id, 'mahindra_bolero_suv')
       WHERE vehicle_capacity IS NULL OR vehicle_capacity < 1
       RETURNING id`
    );
    if (nullCap.rowCount > 0) {
      console.log(`  ✓ Fixed ${nullCap.rowCount} record(s) with null capacity`);
    }

    console.log('\nDone! Drivers can now create trips with correct seat count.');
  } finally {
    client.release();
    await pool.end();
  }
}

fix().catch((e) => {
  console.error(e);
  process.exit(1);
});
