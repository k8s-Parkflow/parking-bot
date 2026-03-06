
USE zone_db;

-- -------------------------------------------------------------------------
-- 1. ZONE 테이블 (주차 존의 식별/명칭/활성 상태를 관리)
-- -------------------------------------------------------------------------
CREATE TABLE ZONE (
    zone_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '존 PK (자동 증가)',
    zone_name VARCHAR(100) NOT NULL COMMENT '존 이름 (유니크)',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT '존 활성 여부 (기본값 true)',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 수정 시각',
    
    -- 유니크 제약 (동일한 이름의 구역 중복 생성 방지)
    CONSTRAINT uniq_zone_name UNIQUE (zone_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------------------
-- 2. SLOT_TYPE 테이블 (슬롯 분류 기준이 되는 타입 엔터티)
-- -------------------------------------------------------------------------
CREATE TABLE SLOT_TYPE (
    slot_type_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '슬롯 타입 PK (자동 증가)',
    type_name VARCHAR(50) NOT NULL COMMENT '슬롯 타입명 (유니크)',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '최종 수정 시각',
    
    -- 유니크 제약 (동일한 타입명 중복 생성 방지)
    CONSTRAINT uniq_type_name UNIQUE (type_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;