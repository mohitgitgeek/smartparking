-- Smart Parking & Vehicle Tracking System Schema (Master + Child design)
-- Using PostgreSQL
-- Drop existing (dev only)
DROP SCHEMA IF EXISTS parking CASCADE;
CREATE SCHEMA parking;
SET search_path TO parking;

-- Master tables (reference / dimension)
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL,
    role_description TEXT
);

CREATE TABLE vehicle_types (
    id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) UNIQUE NOT NULL,
    type_description TEXT
);

CREATE TABLE zones (
    id SERIAL PRIMARY KEY,
    zone_name VARCHAR(50) UNIQUE NOT NULL,
    capacity INT NOT NULL CHECK (capacity >= 0),
    zone_location TEXT,
    zone_type VARCHAR(50)
);

-- Users (FK to roles)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT NOT NULL REFERENCES roles(id),
    full_name VARCHAR(120),
    email VARCHAR(120) UNIQUE,
    phone_number VARCHAR(30),
    address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vehicles (FK optionally to users; to vehicle_types)
CREATE TABLE vehicles (
    id SERIAL PRIMARY KEY,
    vehicle_number VARCHAR(30) UNIQUE NOT NULL,
    owner_user_id INT REFERENCES users(id) ON DELETE SET NULL,
    owner_name VARCHAR(120),
    contact_number VARCHAR(30),
    vehicle_make VARCHAR(80),
    vehicle_model VARCHAR(80),
    vehicle_color VARCHAR(40),
    fuel_type VARCHAR(40),
    vehicle_type_id INT REFERENCES vehicle_types(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Parking slots (child of zones)
CREATE TABLE parking_slots (
    id SERIAL PRIMARY KEY,
    slot_number VARCHAR(30) NOT NULL,
    zone_id INT NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE', -- AVAILABLE, OCCUPIED, MAINTENANCE, RESERVED
    slot_location TEXT,
    slot_size VARCHAR(40),
    is_reserved BOOLEAN DEFAULT FALSE,
    accessibility_features TEXT,
    UNIQUE(zone_id, slot_number)
);

-- Reservations (tie user, slot, vehicle)
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    vehicle_id INT REFERENCES vehicles(id) ON DELETE SET NULL,
    slot_id INT REFERENCES parking_slots(id) ON DELETE SET NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING', -- PENDING, CONFIRMED, CANCELLED, EXPIRED
    reservation_mode VARCHAR(40),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_reservation_time CHECK (end_time > start_time)
);

-- Transactions (parking usage events)
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    reservation_id INT REFERENCES reservations(id) ON DELETE SET NULL,
    slot_id INT REFERENCES parking_slots(id) ON DELETE SET NULL,
    vehicle_id INT REFERENCES vehicles(id) ON DELETE SET NULL,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    check_in_time TIMESTAMPTZ NOT NULL,
    check_out_time TIMESTAMPTZ,
    duration_minutes INT GENERATED ALWAYS AS (
        CASE WHEN check_out_time IS NOT NULL THEN EXTRACT(EPOCH FROM (check_out_time - check_in_time))/60 END
    ) STORED,
    amount_paid NUMERIC(10,2),
    payment_method VARCHAR(40),
    transaction_status VARCHAR(30) DEFAULT 'OPEN' -- OPEN, PAID, CANCELLED
);

-- Violations
CREATE TABLE violations (
    id SERIAL PRIMARY KEY,
    transaction_id INT REFERENCES transactions(id) ON DELETE SET NULL,
    vehicle_id INT REFERENCES vehicles(id) ON DELETE SET NULL,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    violation_type VARCHAR(80) NOT NULL,
    date_issued TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fine_amount NUMERIC(10,2),
    violation_description TEXT,
    status VARCHAR(40) DEFAULT 'ISSUED' -- ISSUED, PAID, WAIVED
);

-- Audit tables (child / history) as example of master-child expansion
CREATE TABLE parking_slot_history (
    id BIGSERIAL PRIMARY KEY,
    slot_id INT REFERENCES parking_slots(id) ON DELETE CASCADE,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    note TEXT
);

CREATE OR REPLACE FUNCTION trg_parking_slot_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO parking_slot_history(slot_id, old_status, new_status, note)
        VALUES (OLD.id, OLD.status, NEW.status, 'Auto status change');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER parking_slot_status_history_trg
AFTER UPDATE ON parking_slots
FOR EACH ROW EXECUTE FUNCTION trg_parking_slot_status_history();

-- Convenience view for current slot occupancy & latest transaction
CREATE OR REPLACE VIEW vw_slot_overview AS
SELECT ps.id AS slot_id,
       z.zone_name,
       ps.slot_number,
       ps.status,
       r.id AS active_reservation_id,
       t.id AS open_transaction_id,
       t.check_in_time
FROM parking_slots ps
JOIN zones z ON z.id = ps.zone_id
LEFT JOIN reservations r ON r.slot_id = ps.id AND r.status IN ('PENDING','CONFIRMED')
LEFT JOIN transactions t ON t.slot_id = ps.id AND t.transaction_status = 'OPEN';

-- Basic index suggestions
CREATE INDEX idx_transactions_vehicle ON transactions(vehicle_id);
CREATE INDEX idx_transactions_slot ON transactions(slot_id);
CREATE INDEX idx_reservations_slot_time ON reservations(slot_id, start_time, end_time);
CREATE INDEX idx_parking_slots_zone_status ON parking_slots(zone_id, status);
