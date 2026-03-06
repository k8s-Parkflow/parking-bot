
USE parking_query_db;

-- -------------------------------------------------------------------------
-- 1. CURRENT_PARKING_VIEW 테이블 (현재 주차 중 차량 상태 뷰)
-- -------------------------------------------------------------------------
CREATE TABLE CURRENT_PARKING_VIEW (
    vehicle_num VARCHAR(20) PRIMARY KEY COMMENT '차량 번호 PK',
    slot_id BIGINT NOT NULL COMMENT '현재 점유 슬롯 ID (parking_command_service 논리 참조)',
    zone_id BIGINT NOT NULL COMMENT '현재 점유 존 ID',
    slot_type VARCHAR(50) NOT NULL COMMENT '슬롯 타입명',
    entry_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '입차 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 갱신 시각'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------------------
-- 2. ZONE_AVAILABILITY 테이블 (존/슬롯타입별 가용성 지표)
-- -------------------------------------------------------------------------
CREATE TABLE ZONE_AVAILABILITY (
    zone_id BIGINT NOT NULL COMMENT '존 ID (zone_service 논리 참조)',
    slot_type VARCHAR(50) NOT NULL COMMENT '슬롯 타입명',
    total_count INT NOT NULL DEFAULT 0 COMMENT '전체 슬롯 수',
    occupied_count INT NOT NULL DEFAULT 0 COMMENT '점유 슬롯 수',
    available_count INT NOT NULL DEFAULT 0 COMMENT '가용 슬롯 수 (total_count - occupied_count)',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 갱신 시각',
    
    -- 유니크 제약
    CONSTRAINT uniq_zone_availability_zone_slot_type UNIQUE (zone_id, slot_type),
    
    -- 인덱스
    INDEX idx_zone_type (zone_id, slot_type),
    
    -- 체크 제약 (정합성 검증용)
    CONSTRAINT chk_zone_availability_available_count CHECK (
        available_count = total_count - occupied_count AND available_count >= 0
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;