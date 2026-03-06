
USE vehicle_db;

-- -------------------------------------------------------------------------
-- 1. VEHICLE 테이블 (차량의 고유 번호와 타입을 관리)
-- -------------------------------------------------------------------------
CREATE TABLE VEHICLE (
    vehicle_num VARCHAR(20) PRIMARY KEY COMMENT '차량 번호 PK',
    vehicle_type VARCHAR(16) NOT NULL COMMENT '차량 타입 (GENERAL, EV, DISABLED)',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 수정 시각',
    
    -- DB 레벨의 데이터 무결성 보호를 위한 체크 제약조건 (Enum 방어)
    CONSTRAINT chk_vehicle_type CHECK (vehicle_type IN ('GENERAL', 'EV', 'DISABLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;