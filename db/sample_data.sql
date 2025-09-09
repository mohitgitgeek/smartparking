SET search_path TO parking;

-- Seed master data
INSERT INTO roles(role_name, role_description) VALUES
 ('ADMIN','System administrator with full privileges'),
 ('ATTENDANT','Parking attendant handling on-site operations'),
 ('USER','Regular parking user');

INSERT INTO vehicle_types(type_name, type_description) VALUES
 ('Car','Standard four wheel car'),
 ('Bike','Two wheel motor bike'),
 ('EV','Electric vehicle requires charging'),
 ('Truck','Larger capacity truck');

INSERT INTO zones(zone_name, capacity, zone_location, zone_type) VALUES
 ('A', 50, 'Ground level near entrance', 'GENERAL'),
 ('B', 40, 'Basement level B1', 'GENERAL'),
 ('EV1', 10, 'Ground level east wing', 'EV'),
 ('VIP', 8, 'Secured gated area west', 'PREMIUM');

-- Users (passwords are plaintext placeholders -> to be hashed in real app)
INSERT INTO users(username, password_hash, role_id, full_name, email, phone_number, address)
SELECT 'admin', 'admin-pass', r.id, 'Alice Admin', 'admin@example.com', '+1234567890', '123 Admin St'
FROM roles r WHERE r.role_name='ADMIN';

INSERT INTO users(username, password_hash, role_id, full_name, email, phone_number, address)
SELECT 'attendant1', 'attendant-pass', r.id, 'Bob Attendant', 'att1@example.com', '+1098765432', '45 Service Ln'
FROM roles r WHERE r.role_name='ATTENDANT';

INSERT INTO users(username, password_hash, role_id, full_name, email, phone_number, address)
SELECT 'jdoe', 'user-pass', r.id, 'John Doe', 'jdoe@example.com', '+1987654321', '77 User Ave'
FROM roles r WHERE r.role_name='USER';

-- Vehicles
INSERT INTO vehicles(vehicle_number, owner_user_id, owner_name, contact_number, vehicle_make, vehicle_model, vehicle_color, fuel_type, vehicle_type_id)
SELECT 'CAR-111', u.id, 'John Doe', '+1987654321', 'Toyota', 'Corolla', 'Blue', 'Petrol', vt.id
  FROM users u CROSS JOIN vehicle_types vt
 WHERE u.username='jdoe' AND vt.type_name='Car';

INSERT INTO vehicles(vehicle_number, owner_user_id, owner_name, contact_number, vehicle_make, vehicle_model, vehicle_color, fuel_type, vehicle_type_id)
SELECT 'EV-22', u.id, 'John Doe', '+1987654321', 'Tesla', 'Model 3', 'White', 'Electric', vt.id
  FROM users u CROSS JOIN vehicle_types vt
 WHERE u.username='jdoe' AND vt.type_name='EV';

-- Parking slots (few samples per zone)
INSERT INTO parking_slots(slot_number, zone_id, status, slot_location, slot_size, is_reserved, accessibility_features)
SELECT 'A-01', z.id, 'AVAILABLE', 'Row 1', 'STANDARD', FALSE, '' FROM zones z WHERE z.zone_name='A';
INSERT INTO parking_slots(slot_number, zone_id, status, slot_location, slot_size, is_reserved, accessibility_features)
SELECT 'A-02', z.id, 'AVAILABLE', 'Row 1', 'STANDARD', FALSE, '' FROM zones z WHERE z.zone_name='A';
INSERT INTO parking_slots(slot_number, zone_id, status, slot_location, slot_size, is_reserved, accessibility_features)
SELECT 'EV1-01', z.id, 'AVAILABLE', 'East Wing', 'STANDARD', TRUE, 'Charging Station' FROM zones z WHERE z.zone_name='EV1';
INSERT INTO parking_slots(slot_number, zone_id, status, slot_location, slot_size, is_reserved, accessibility_features)
SELECT 'VIP-01', z.id, 'RESERVED', 'Gated Section', 'WIDE', TRUE, 'Close to exit' FROM zones z WHERE z.zone_name='VIP';

-- Reservation sample
INSERT INTO reservations(user_id, vehicle_id, slot_id, start_time, end_time, status, reservation_mode)
SELECT u.id, v.id, ps.id, NOW() + INTERVAL '30 minutes', NOW() + INTERVAL '2 hours', 'CONFIRMED', 'WEB'
FROM users u
JOIN vehicles v ON v.owner_user_id = u.id AND v.vehicle_number='CAR-111'
JOIN parking_slots ps ON ps.slot_number='A-01';

-- Open transaction sample (simulate check-in)
INSERT INTO transactions(reservation_id, slot_id, vehicle_id, user_id, check_in_time, amount_paid, payment_method, transaction_status)
SELECT r.id, r.slot_id, r.vehicle_id, r.user_id, NOW(), NULL, NULL, 'OPEN'
FROM reservations r LIMIT 1;

-- Violation sample
INSERT INTO violations(transaction_id, vehicle_id, user_id, violation_type, fine_amount, violation_description, status)
SELECT t.id, t.vehicle_id, t.user_id, 'Overstay', 25.00, 'Exceeded reserved time by 30 minutes', 'ISSUED'
FROM transactions t LIMIT 1;

-- Update slot status to reflect occupancy for the open transaction
UPDATE parking_slots SET status='OCCUPIED' WHERE slot_number='A-01';
