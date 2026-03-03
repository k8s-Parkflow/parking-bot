-- 1. ZONE 테이블 생성
CREATE TABLE ZONE (
    zone_id INT AUTO_INCREMENT PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL
);

-- 2. VEHICLE 테이블 생성
CREATE TABLE VEHICLE (
    vehicle_num VARCHAR(50) PRIMARY KEY,
    vehicle_type_code VARCHAR(20)
);

-- 3. SLOT_TYPE 테이블 생성
CREATE TABLE SLOT_TYPE (
    slot_type_id INT AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(50) NOT NULL
);

-- 4. ZONE_AVAILABILITY 테이블 생성
CREATE TABLE ZONE_AVAILABILITY (
    zone_id INT PRIMARY KEY,
    total_slots INT NOT NULL,
    occupied_slots INT NOT NULL,
    available_slots INT NOT NULL,
    general_total INT NOT NULL,
    general_occupied INT NOT NULL,
    general_available INT NOT NULL,
    ev_total INT NOT NULL,
    ev_occupied INT NOT NULL,
    ev_available INT NOT NULL,
    disabled_total INT NOT NULL,
    disabled_occupied INT NOT NULL,
    disabled_available INT NOT NULL,
    updated_at DATETIME,
    CONSTRAINT fk_zone_avail_zone FOREIGN KEY (zone_id) REFERENCES ZONE(zone_id) ON DELETE CASCADE
);

-- 5. PARKING_SLOT 테이블 생성
CREATE TABLE PARKING_SLOT (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    zone_id INT NOT NULL,
    slot_type_id INT NOT NULL,
    slot_code VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_slot_zone FOREIGN KEY (zone_id) REFERENCES ZONE(zone_id),
    CONSTRAINT fk_slot_type FOREIGN KEY (slot_type_id) REFERENCES SLOT_TYPE(slot_type_id)
);

-- 6. PARKING_history 테이블 생성
CREATE TABLE PARKING_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    zone_id INT NOT NULL,
    slot_id INT NOT NULL,
    vehicle_plate VARCHAR(50) NOT NULL,
    entry_at DATETIME NOT NULL,
    exit_at DATETIME,
    status VARCHAR(20) NOT NULL,
    CONSTRAINT fk_hist_zone FOREIGN KEY (zone_id) REFERENCES ZONE(zone_id),
    CONSTRAINT fk_hist_slot FOREIGN KEY (slot_id) REFERENCES PARKING_SLOT(slot_id),
    CONSTRAINT fk_hist_vehicle FOREIGN KEY (vehicle_plate) REFERENCES VEHICLE(vehicle_num)
);

-- 7. SLOT_OCCUPANCY 테이블 생성
CREATE TABLE SLOT_OCCUPANCY (
    slot_id INT PRIMARY KEY,
    occupied BOOLEAN NOT NULL DEFAULT FALSE,
    current_session_id BIGINT,
    vehicle_plate VARCHAR(50),
    occupied_since DATETIME,
    updated_at DATETIME,
    CONSTRAINT fk_occ_slot FOREIGN KEY (slot_id) REFERENCES PARKING_SLOT(slot_id),
    CONSTRAINT fk_occ_session FOREIGN KEY (current_session_id) REFERENCES PARKING_history(history_id),
    CONSTRAINT fk_occ_vehicle FOREIGN KEY (vehicle_plate) REFERENCES VEHICLE(vehicle_num)
);