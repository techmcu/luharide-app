-- LuhaRide Seed Data for Development/Testing

-- Insert sample unions
INSERT INTO unions (name, registration_number, gst_number, contact_phone, contact_email, address) VALUES
('Dehradun Taxi Union', 'DTU2024001', '05ABCDE1234F1Z5', '+91-9876543210', 'contact@dehraduntaxi.com', 'Parade Ground, Dehradun, Uttarakhand - 248001'),
('Mussoorie Taxi Operators', 'MTO2024002', '05FGHIJ5678K2Z5', '+91-9876543211', 'info@mussooritaxi.com', 'Library Chowk, Mussoorie, Uttarakhand - 248179'),
('Rishikesh Transport Union', 'RTU2024003', '05KLMNO9012L3Z5', '+91-9876543212', 'support@rishikeshtaxi.com', 'Rishikesh Bus Stand, Rishikesh, Uttarakhand - 249201');

-- Insert sample routes (without PostGIS geometry functions)
INSERT INTO routes (name, from_location, to_location, from_lat, from_lng, to_lat, to_lng, distance_km, estimated_duration_minutes, base_fare, is_popular) VALUES
('Dehradun to Mussoorie', 'Dehradun Railway Station', 'Library Chowk, Mussoorie', 
 30.3165, 78.0322, 30.4598, 78.0644, 35, 60, 180.00, true),

('Dehradun to Rishikesh', 'Dehradun ISBT', 'Rishikesh Bus Stand',
 30.3165, 78.0322, 30.0869, 78.3158, 45, 75, 200.00, true),

('Rishikesh to Haridwar', 'Rishikesh Bus Stand', 'Haridwar Railway Station',
 30.0869, 78.3158, 29.9457, 78.1642, 25, 45, 150.00, true),

('Dehradun to Haridwar', 'Dehradun ISBT', 'Haridwar Railway Station',
 30.3165, 78.0322, 29.9457, 78.1642, 55, 90, 220.00, true);

-- Insert sample vehicles (Note: In production, these would be real verified vehicles)
INSERT INTO vehicles (registration_number, vehicle_type, vehicle_model, capacity, union_id, plate_type, permit_number, permit_expiry, insurance_number, insurance_expiry, fitness_expiry, puc_expiry) 
SELECT 
    'UK07AB' || LPAD((ROW_NUMBER() OVER())::TEXT, 4, '0'),
    CASE WHEN ROW_NUMBER() OVER() % 2 = 0 THEN 'Tempo Traveller' ELSE 'Innova' END,
    CASE WHEN ROW_NUMBER() OVER() % 2 = 0 THEN 'Force Traveller 3350' ELSE 'Toyota Innova Crysta' END,
    CASE WHEN ROW_NUMBER() OVER() % 2 = 0 THEN 10 ELSE 7 END,
    (SELECT id FROM unions ORDER BY RANDOM() LIMIT 1),
    'yellow',
    'PER' || LPAD((ROW_NUMBER() OVER())::TEXT, 6, '0'),
    CURRENT_DATE + INTERVAL '1 year',
    'INS' || LPAD((ROW_NUMBER() OVER())::TEXT, 8, '0'),
    CURRENT_DATE + INTERVAL '1 year',
    CURRENT_DATE + INTERVAL '6 months',
    CURRENT_DATE + INTERVAL '3 months'
FROM generate_series(1, 20);

-- Note: User accounts should be created through the app registration flow
-- This ensures proper password hashing and OTP verification
-- Below are sample SQL templates (commented out)

/*
-- Sample passenger (password should be hashed using bcrypt in actual code)
INSERT INTO users (phone, name, email, role, is_verified) VALUES
('+91-9999999001', 'Rahul Kumar', 'rahul@example.com', 'passenger', true),
('+91-9999999002', 'Priya Sharma', 'priya@example.com', 'passenger', true);

-- Sample drivers (should be created with proper verification)
INSERT INTO users (phone, name, email, role, is_verified) VALUES
('+91-9999999101', 'Vijay Singh', 'vijay.driver@example.com', 'driver', true),
('+91-9999999102', 'Ramesh Negi', 'ramesh.driver@example.com', 'driver', true);

-- Sample union admin
INSERT INTO users (phone, name, email, role, is_verified) VALUES
('+91-9999999201', 'Suresh Gupta', 'suresh.admin@example.com', 'union_admin', true);
*/

-- Insert sample system configuration (additional settings)
INSERT INTO settings (key, value, description) VALUES
('maintenance_mode', 'false', 'Enable/disable maintenance mode'),
('min_app_version_android', '1.0.0', 'Minimum required Android app version'),
('min_app_version_ios', '1.0.0', 'Minimum required iOS app version'),
('max_seats_per_booking', '4', 'Maximum seats a passenger can book in single transaction'),
('driver_rating_threshold', '4.0', 'Minimum driver rating to remain active'),
('auto_cancel_unpaid_booking_minutes', '15', 'Auto-cancel booking if payment not completed'),
('peak_hour_multiplier', '1.2', 'Fare multiplier during peak hours');

-- Note: Trips should be created by drivers/union admins through the app
-- Bookings should be created by passengers through the booking flow
-- These ensure proper validation and real-time availability checking
