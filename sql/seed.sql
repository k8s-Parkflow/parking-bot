-- 빈 주차장
-- 주차면 종류 생성 (ID는 자동 부여: 1=일반, 2=EV, 3=장애인)
INSERT INTO SLOT_TYPE (type) VALUES 
('일반'), 
('EV'), 
('장애인');

-- Zone 100개와 각 Zone의 주차면 100개를 모두 생성하는 프로시저
DELIMITER //
CREATE OR REPLACE PROCEDURE seed_all_empty_zones_and_slots()
BEGIN
    DECLARE v_zone INT DEFAULT 1;
    DECLARE v_slot INT;
    DECLARE v_type_id INT;
    DECLARE v_slot_code VARCHAR(20);
    DECLARE v_current_zone_id INT;
    
    -- Zone 1 ~ 100까지 반복
    WHILE v_zone <= 100 DO
        
        -- 구역(ZONE) 이름만 넣어서 생성 (zone_id는 AUTO_INCREMENT로 자동 생성됨)
        INSERT INTO ZONE (zone_name) VALUES (CONCAT('Zone ', v_zone));
        
        -- 방금 생성된 구역의 ID를 가져옴
        SET v_current_zone_id = LAST_INSERT_ID();
        
        -- 구역 현황(ZONE_AVAILABILITY) 초기화: 100자리 모두 비어있는 상태
        INSERT INTO ZONE_AVAILABILITY (
            zone_id, total_slots, occupied_slots, available_slots, 
            general_total, general_occupied, general_available, 
            ev_total, ev_occupied, ev_available, 
            disabled_total, disabled_occupied, disabled_available, 
            updated_at
        ) VALUES (
            v_current_zone_id, 100, 0, 100, 
            90, 0, 90, 
            5, 0, 5, 
            5, 0, 5, 
            NOW()
        );
        
        -- 해당 구역(Zone)의 빈 주차면 100개 생성
        SET v_slot = 1;
        WHILE v_slot <= 100 DO
            -- 타입 지정 (1~5번은 EV(2), 20의 배수는 장애인(3), 나머지는 일반(1))
            IF v_slot IN (1, 2, 3, 4, 5) THEN 
                SET v_type_id = 2;
            ELSEIF v_slot IN (20, 40, 60, 80, 100) THEN 
                SET v_type_id = 3;
            ELSE 
                SET v_type_id = 1;
            END IF;
            
            -- 슬롯 코드 생성 (예: Z1-001, Z100-100)
            SET v_slot_code = CONCAT('Z', v_zone, '-', LPAD(v_slot, 3, '0'));
            
            -- 주차면(PARKING_SLOT) 생성
            INSERT INTO PARKING_SLOT (zone_id, slot_type_id, slot_code, is_active) 
            VALUES (v_current_zone_id, v_type_id, v_slot_code, TRUE);
            
            -- 주차면 상태(SLOT_OCCUPANCY) '비어있음(FALSE)'으로 초기화
            -- PARKING_SLOT 생성 시 발생한 AUTO_INCREMENT ID를 바로 가져와서 사용
            INSERT INTO SLOT_OCCUPANCY (slot_id, occupied, updated_at) 
            VALUES (LAST_INSERT_ID(), FALSE, NOW());
            
            SET v_slot = v_slot + 1;
        END WHILE;
        
        SET v_zone = v_zone + 1;
    END WHILE;
END //
DELIMITER ;

-- 프로시저 실행 (100개 Zone + 10,000개 주차면 생성)
CALL seed_all_empty_zones_and_slots();