-- =============================================
-- 1. DATABASE CREATION
-- =============================================
CREATE DATABASE IF NOT EXISTS parking_system;
USE parking_system;

-- =============================================
-- 2. VEHICLE RATES TABLE
-- =============================================
-- Stores the hourly cost for different vehicle categories
CREATE TABLE vehicle_rates (
    vehicle_type VARCHAR(20) PRIMARY KEY,
    rate_per_hour DECIMAL(10,2) NOT NULL
);

INSERT INTO vehicle_rates (vehicle_type, rate_per_hour) VALUES
('Bike', 10.00),
('Car', 20.00),
('Other', 30.00);

-- =============================================
-- 3. PARKING SLOTS TABLE
-- =============================================
-- Manages the state (available/occupied) of the physical spots
CREATE TABLE parking_slots (
    slot_id VARCHAR(10) PRIMARY KEY,
    slot_type VARCHAR(20),
    status ENUM('available', 'occupied') DEFAULT 'available'
);

-- Inserting 50 Slots (20 Cars, 10 Bikes, 10 Other, 10 Cars)
INSERT INTO parking_slots (slot_id, slot_type) VALUES
('A1','Car'),('A2','Car'),('A3','Car'),('A4','Car'),('A5','Car'),
('A6','Car'),('A7','Car'),('A8','Car'),('A9','Car'),('A10','Car'),
('A11','Car'),('A12','Car'),('A13','Car'),('A14','Car'),('A15','Car'),
('A16','Car'),('A17','Car'),('A18','Car'),('A19','Car'),('A20','Car'),
('A21','Bike'),('A22','Bike'),('A23','Bike'),('A24','Bike'),('A25','Bike'),
('A26','Bike'),('A27','Bike'),('A28','Bike'),('A29','Bike'),('A30','Bike'),
('A31','Other'),('A32','Other'),('A33','Other'),('A34','Other'),('A35','Other'),
('A36','Other'),('A37','Other'),('A38','Other'),('A39','Other'),('A40','Other'),
('A41','Car'),('A42','Car'),('A43','Car'),('A44','Car'),('A45','Car'),
('A46','Car'),('A47','Car'),('A48','Car'),('A49','Car'),('A50','Car');

-- =============================================
-- 4. PARKING RECORDS TABLE
-- =============================================
-- The core ledger storing every entry and exit
CREATE TABLE parking_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20),
    name VARCHAR(50),
    mobile VARCHAR(15),
    address TEXT,
    vehicle_number VARCHAR(20),
    vehicle_type VARCHAR(20),
    slot_id VARCHAR(10),
    entry_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    exit_time DATETIME NULL,
    duration_hours INT DEFAULT 0,
    amount DECIMAL(10,2) DEFAULT 0.00,
    transaction_id VARCHAR(50),
    FOREIGN KEY (slot_id) REFERENCES parking_slots(slot_id)
);

-- Index to optimize the search by vehicle plate during exit
CREATE INDEX idx_veh_active ON parking_records(vehicle_number, exit_time);

-- =============================================
-- 5. TRIGGER: AUTOMATIC BILLING
-- =============================================
-- This calculates the total amount automatically when Python sets 'exit_time'
DELIMITER $$

CREATE TRIGGER calculate_amount
BEFORE UPDATE ON parking_records
FOR EACH ROW
BEGIN
    DECLARE v_rate DECIMAL(10,2);

    -- Fire only when exit_time is being added (vehicle is leaving)
    IF NEW.exit_time IS NOT NULL AND OLD.exit_time IS NULL THEN

        -- Calculate hours (Difference in seconds divided by 3600, rounded up)
        SET NEW.duration_hours = CEIL(TIMESTAMPDIFF(SECOND, OLD.entry_time, NEW.exit_time) / 3600);

        -- Ensure minimum 1 hour charge
        IF NEW.duration_hours < 1 THEN
            SET NEW.duration_hours = 1;
        END IF;

        -- Fetch the rate from the vehicle_rates table
        SELECT rate_per_hour INTO v_rate 
        FROM vehicle_rates 
        WHERE vehicle_type = NEW.vehicle_type;

        -- Final Total = Hours * Rate
        SET NEW.amount = NEW.duration_hours * IFNULL(v_rate, 0);

    END IF;
END$$

DELIMITER ;

-- =============================================
-- 6. USERS TABLE
-- =============================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    role ENUM('admin', 'attendant') NOT NULL
);

INSERT INTO users (username, password, role) VALUES
('admin', '1234', 'admin'),
('attendant', '1234', 'attendant');

-- =============================================
-- 7. REVENUE VIEW (Bonus)
-- =============================================
-- A simple view to see total earnings at any time
CREATE VIEW total_revenue_view AS
SELECT SUM(amount) AS total_revenue FROM parking_records;

SELECT * FROM parking_slots WHERE status ='occupied' ORDER BY slot_id;
SELECT * FROM parking_records;


