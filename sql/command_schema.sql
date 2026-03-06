USE parking_command_db;
-- -------------------------------------------------------------------------
-- 1. PARKING_SLOT 테이블 (슬롯 자체의 정보)
-- -------------------------------------------------------------------------
CREATE TABLE PARKING_SLOT (
    slot_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '슬롯 PK (자동 증가)',
    zone_id BIGINT NOT NULL COMMENT '존 식별자 (zone_service.ZONE 논리 참조)',
    slot_type_id BIGINT NOT NULL COMMENT '슬롯 타입 식별자 (zone_service.SLOT_TYPE 논리 참조)',
    slot_code VARCHAR(50) NOT NULL COMMENT '존 내 슬롯 코드',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT '슬롯 활성 여부',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 수정 시각',
    
    -- 유니크 제약
    CONSTRAINT uniq_slot_zone_slot_code UNIQUE (zone_id, slot_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------------------
-- 2. PARKING_HISTORY 테이블 (차량 입차/출차 이력)
-- -------------------------------------------------------------------------
CREATE TABLE PARKING_HISTORY (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '주차 이력 PK',
    slot_id BIGINT NOT NULL COMMENT '주차 슬롯 FK',
    vehicle_num VARCHAR(20) NOT NULL COMMENT '차량 번호 (vehicle_service.VEHICLE 논리 참조)',
    status VARCHAR(16) NOT NULL COMMENT '이력 상태 (PARKED 또는 EXITED)',
    entry_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '입차 시각',
    exit_at TIMESTAMP NULL COMMENT '출차 시각 (NULL이면 활성 세션)',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 수정 시각',
    
    -- MariaDB용 조건부 유니크 구현 (Virtual Column 사용)
    -- "exit_at이 NULL일 때만 vehicle_num이 유니크해야 함"을 강제
    active_vehicle_num VARCHAR(20) AS (IF(exit_at IS NULL, vehicle_num, NULL)) VIRTUAL COMMENT '활성 차량 중복 방지용 가상 컬럼',
    
    -- 외래키
    CONSTRAINT fk_history_slot FOREIGN KEY (slot_id) REFERENCES PARKING_SLOT(slot_id),
    
    -- 인덱스 및 제약
    INDEX idx_history_slot_entry (slot_id, entry_at),
    INDEX idx_history_vehicle_exit (vehicle_num, exit_at),
    CONSTRAINT uniq_active_history_per_vehicle UNIQUE (active_vehicle_num)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------------------
-- 3. SLOT_OCCUPANCY 테이블 (슬롯의 현재 점유 상태)
-- -------------------------------------------------------------------------
CREATE TABLE SLOT_OCCUPANCY (
    slot_id BIGINT PRIMARY KEY COMMENT '슬롯 PK/FK (1 슬롯 = 1 점유 행)',
    occupied BOOLEAN NOT NULL DEFAULT FALSE COMMENT '점유 여부',
    vehicle_num VARCHAR(20) NULL COMMENT '현재 점유 차량 번호',
    history_id BIGINT NULL COMMENT '현재 점유를 나타내는 이력 FK',
    occupied_at TIMESTAMP NULL COMMENT '점유 시작 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 수정 시각',
    
    -- 외래키
    CONSTRAINT fk_occupancy_slot FOREIGN KEY (slot_id) REFERENCES PARKING_SLOT(slot_id),
    CONSTRAINT fk_occupancy_history FOREIGN KEY (history_id) REFERENCES PARKING_HISTORY(history_id),
    
    -- 체크 제약 (일관성 검증)
    -- occupied가 true면 나머지 세팅 필수, false면 나머지 모두 NULL이어야 함
    CONSTRAINT slot_occupancy_consistency CHECK (
        (occupied = TRUE AND vehicle_num IS NOT NULL AND history_id IS NOT NULL AND occupied_at IS NOT NULL)
        OR
        (occupied = FALSE AND vehicle_num IS NULL AND history_id IS NULL AND occupied_at IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;