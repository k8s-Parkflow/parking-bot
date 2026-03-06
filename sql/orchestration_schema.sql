
USE orchestration_db;

-- -------------------------------------------------------------------------
-- 1. IDEMPOTENCY_RECORD 테이블 (API 중복 요청 방지를 위한 기록)
-- -------------------------------------------------------------------------
CREATE TABLE IDEMPOTENCY_RECORD (
    idempotency_key VARCHAR(100) PRIMARY KEY COMMENT '클라이언트가 보낸 고유 요청 키 (PK)',
    operation VARCHAR(50) NOT NULL COMMENT '수행하려는 작업 이름 (예: PARKING_ENTRY)',
    request_hash VARCHAR(255) NOT NULL COMMENT '요청 본문(Body)의 해시값 (위변조 검증용)',
    response_code INT NULL COMMENT '최종 응답 HTTP 상태 코드 (예: 200, 400)',
    response_body TEXT NULL COMMENT '최종 응답 데이터 본문 (재요청 시 이 값을 그대로 반환)',
    status VARCHAR(20) NOT NULL COMMENT '처리 상태 (STARTED, COMPLETED, FAILED)',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '요청 인입 시각',
    expires_at TIMESTAMP NULL COMMENT '기록 만료 시각 (보통 24시간 후 삭제)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;