-- LuhaRide Initial Database Schema
-- Run this after creating the database and enabling PostGIS

-- Enable PostGIS extension for geospatial queries (optional - skip if not installed)
-- CREATE EXTENSION IF NOT EXISTS postgis;
-- Note: PostGIS is optional for initial development. 
-- Can be added later when needed for maps/location features.

-- Users table (Passengers, Drivers, Union Admins)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(15) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    password_hash VARCHAR(255),
    role VARCHAR(20) NOT NULL CHECK (role IN ('passenger', 'driver', 'union_admin')),
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    aadhaar_hash VARCHAR(64),
    profile_image_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Unions table
CREATE TABLE unions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    registration_number VARCHAR(100) UNIQUE,
    gst_number VARCHAR(15),
    contact_phone VARCHAR(15),
    contact_email VARCHAR(100),
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    commission_rate DECIMAL(5,2) DEFAULT 10.00,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Vehicles table
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type VARCHAR(50) NOT NULL,
    vehicle_model VARCHAR(100),
    capacity INTEGER NOT NULL,
    union_id UUID REFERENCES unions(id),
    current_driver_id UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT true,
    plate_type VARCHAR(10) DEFAULT 'yellow',
    permit_number VARCHAR(50),
    permit_expiry DATE,
    insurance_number VARCHAR(50),
    insurance_expiry DATE,
    fitness_expiry DATE,
    puc_expiry DATE,
    vehicle_images TEXT[], -- Array of image URLs
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Routes table with geospatial data
CREATE TABLE routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    from_location VARCHAR(200) NOT NULL,
    to_location VARCHAR(200) NOT NULL,
    from_lat DECIMAL(10, 8),
    from_lng DECIMAL(11, 8),
    to_lat DECIMAL(10, 8),
    to_lng DECIMAL(11, 8),
    distance_km INTEGER,
    estimated_duration_minutes INTEGER,
    base_fare DECIMAL(10,2) NOT NULL,
    is_popular BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trips table (Scheduled trips)
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID REFERENCES vehicles(id) NOT NULL,
    driver_id UUID REFERENCES users(id) NOT NULL,
    route_id UUID REFERENCES routes(id) NOT NULL,
    departure_time TIMESTAMP NOT NULL,
    actual_departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'boarding', 'in_progress', 'completed', 'cancelled')),
    seats_booked INTEGER DEFAULT 0,
    total_capacity INTEGER NOT NULL,
    fare_per_seat DECIMAL(10,2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Bookings table (Individual seat bookings)
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_code VARCHAR(10) UNIQUE NOT NULL,
    trip_id UUID REFERENCES trips(id) NOT NULL,
    passenger_id UUID REFERENCES users(id) NOT NULL,
    seat_number INTEGER NOT NULL,
    fare DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'boarded', 'completed', 'cancelled', 'refunded')),
    qr_code TEXT,
    pickup_location VARCHAR(200),
    dropoff_location VARCHAR(200),
    booked_at TIMESTAMP DEFAULT NOW(),
    boarded_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,
    UNIQUE(trip_id, seat_number)
);

-- Payments table
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) CHECK (payment_method IN ('razorpay', 'cash', 'upi', 'card', 'wallet')),
    razorpay_order_id VARCHAR(100),
    razorpay_payment_id VARCHAR(100),
    razorpay_signature VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    paid_at TIMESTAMP,
    refunded_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Reviews table
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) NOT NULL UNIQUE,
    driver_id UUID REFERENCES users(id) NOT NULL,
    passenger_id UUID REFERENCES users(id) NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Driver documents table
CREATE TABLE driver_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES users(id) NOT NULL,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('driving_license', 'rc', 'permit', 'insurance', 'fitness', 'puc', 'police_verification', 'aadhaar', 'pan')),
    document_number VARCHAR(100),
    document_url TEXT NOT NULL,
    expiry_date DATE,
    is_verified BOOLEAN DEFAULT false,
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP,
    uploaded_at TIMESTAMP DEFAULT NOW()
);

-- Location history table (for tracking)
CREATE TABLE location_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES trips(id) NOT NULL,
    driver_id UUID REFERENCES users(id) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    speed DECIMAL(5,2),
    heading INTEGER,
    accuracy DECIMAL(8,2),
    recorded_at TIMESTAMP DEFAULT NOW()
);

-- Emergency SOS logs
CREATE TABLE sos_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id),
    trip_id UUID REFERENCES trips(id),
    user_id UUID REFERENCES users(id) NOT NULL,
    user_type VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    status VARCHAR(20) DEFAULT 'triggered' CHECK (status IN ('triggered', 'in_progress', 'resolved', 'false_alarm')),
    response_notes TEXT,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50),
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- System settings table
CREATE TABLE settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_vehicles_union ON vehicles(union_id);
CREATE INDEX idx_vehicles_driver ON vehicles(current_driver_id);
CREATE INDEX idx_trips_vehicle ON trips(vehicle_id);
CREATE INDEX idx_trips_driver ON trips(driver_id);
CREATE INDEX idx_trips_route ON trips(route_id);
CREATE INDEX idx_trips_departure ON trips(departure_time);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_bookings_trip ON bookings(trip_id);
CREATE INDEX idx_bookings_passenger ON bookings(passenger_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_code ON bookings(booking_code);
CREATE INDEX idx_payments_booking ON payments(booking_id);
CREATE INDEX idx_reviews_driver ON reviews(driver_id);
CREATE INDEX idx_documents_driver ON driver_documents(driver_id);
CREATE INDEX idx_location_trip ON location_history(trip_id);
CREATE INDEX idx_location_recorded ON location_history(recorded_at);
CREATE INDEX idx_notifications_user ON notifications(user_id);

-- Spatial indexes commented out (requires PostGIS)
-- CREATE INDEX idx_routes_from_point ON routes USING GIST(from_point);
-- CREATE INDEX idx_routes_to_point ON routes USING GIST(to_point);
-- CREATE INDEX idx_location_point ON location_history USING GIST(location);

-- Insert default system settings
INSERT INTO settings (key, value, description) VALUES
('max_booking_advance_days', '30', 'Maximum days in advance a booking can be made'),
('min_booking_advance_hours', '2', 'Minimum hours in advance a booking must be made'),
('cancellation_window_hours', '6', 'Hours before departure when cancellation is allowed'),
('booking_confirmation_timeout_minutes', '15', 'Minutes to complete payment after booking'),
('platform_commission_passenger', '0', 'Commission percentage from passengers'),
('platform_commission_driver', '10', 'Commission percentage from drivers'),
('sos_response_time_minutes', '5', 'Target response time for SOS alerts');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_unions_updated_at BEFORE UPDATE ON unions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_routes_updated_at BEFORE UPDATE ON routes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions (adjust as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO luharide_app;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO luharide_app;

COMMENT ON TABLE users IS 'Stores all users: passengers, drivers, and union admins';
COMMENT ON TABLE vehicles IS 'Stores vehicle information with yellow plate verification';
COMMENT ON TABLE bookings IS 'Individual seat bookings with QR codes';
COMMENT ON TABLE trips IS 'Scheduled trips with real-time status tracking';
COMMENT ON TABLE location_history IS 'GPS tracking data for active trips';
