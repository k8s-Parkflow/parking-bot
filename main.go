package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"time"
)

// 1. JSON 데이터 규격
type ParkingEvent struct {
	VehicleNum      string    `json:"vehicle_num"`       // 차량 번호
	VehicleTypeCode string    `json:"vehicle_type_code"` // 차종 (SEDAN, SUV 등)
	ZoneID          int       `json:"zone_id"`           // 구역 ID
	SlotCode        string    `json:"slot_code"`         // 슬롯 코드
	Occupied        bool      `json:"occupied"`          // true(입차), false(출차)
	UpdateAt        time.Time `json:"update_at"`         // 이벤트 발생 시간
}

// 2. 가상의 차량 번호판 생성 함수
func generatePlate() string {
	chars := []string{"가", "나", "다", "라", "마", "바", "사", "아", "자", "차"}
	front := rand.Intn(90) + 10 // 10 ~ 99
	char := chars[rand.Intn(len(chars))]
	back := rand.Intn(9000) + 1000 // 1000 ~ 9999
	return fmt.Sprintf("%02d%s%04d", front, char, back)
}

// 3. 가상의 차종(enum) 생성 함수
func generateVehicleType() string {
	types := []string{"SEDAN", "SUV", "TRUCK", "COMPACT"}
	return types[rand.Intn(len(types))]
}

// 4. 실제로 HTTP 요청을 쏘는 함수 (고루틴으로 비동기 실행됨)
func sendParkingEvent(apiUrl string) {
	zoneID := rand.Intn(100) + 1
	slotNum := rand.Intn(100) + 1
	slotCode := fmt.Sprintf("Z%d-%03d", zoneID, slotNum)
	isOccupied := rand.Intn(2) == 1

	event := ParkingEvent{
		VehicleNum:      generatePlate(),
		VehicleTypeCode: generateVehicleType(),
		ZoneID:          zoneID,
		SlotCode:        slotCode,
		Occupied:        isOccupied,
		UpdateAt:        time.Now(),
	}

	jsonData, err := json.Marshal(event)
	if err != nil {
		fmt.Println("JSON 변환 오류:", err)
		return
	}

	// 💡 백엔드로 POST 요청 (에러가 나도 봇이 죽지 않도록 독립적으로 실행됨)
	resp, err := http.Post(apiUrl, "application/json", bytes.NewBuffer(jsonData))

	actionText := "출차(EXIT)"
	if isOccupied {
		actionText = "입차(ENTRY)"
	}

	if err != nil {
		fmt.Printf("❌ 전송 실패 | %s | %s | 사유: %v\n", actionText, event.VehicleNum, err)
	} else {
		fmt.Printf("✅ 전송 성공 | %s | %s | Zone: %d | 상태 코드: %d\n", actionText, event.VehicleNum, event.ZoneID, resp.StatusCode)
		resp.Body.Close()
	}
}

func main() {
	// 랜덤 시드 설정
	//rand.Seed(time.Now().UnixNano())

	// 환경 변수에서 API 주소 가져오기 (없으면 로컬 주소 사용)
	apiUrl := os.Getenv("API_URL")
	if apiUrl == "" {
		apiUrl = "http://localhost:8000/api/v1/parking/event"
		fmt.Println("⚠️ API_URL 환경 변수가 없어 기본값(localhost)을 사용합니다.")
	}

	fmt.Printf("🚀 주차장 트래픽 봇 가동 시작 (타겟: %s)\n", apiUrl)

	// 무한 루프로 24시간 트래픽 발생
	for {
		now := time.Now()
		hour := now.Hour()

		var burstCount int          // 한 번에 쏠 차량 대수
		var sleepTime time.Duration // 다음 발사까지 쉴 시간

		// 🚦 시간대별 트래픽 시나리오 제어
		if (hour >= 8 && hour <= 9) || (hour >= 18 && hour <= 19) {
			// 🔥 출퇴근 시간 (Rush Hour): 1초마다 10대씩 동시 발사 (초당 10건)
			burstCount = 10
			sleepTime = 1 * time.Second
		} else if hour >= 0 && hour <= 5 {
			// 🌙 새벽 시간: 10초마다 1대씩 발사 (매우 한산함)
			burstCount = 1
			sleepTime = 10 * time.Second
		} else {
			// ☀️ 평상시: 2초마다 1대씩 발사 (일반 트래픽)
			burstCount = 1
			sleepTime = 2 * time.Second
		}

		// 정해진 burstCount만큼 '고루틴(go)'을 생성하여 동시에 비동기 전송
		for i := 0; i < burstCount; i++ {
			// go 키워드 하나로 메인 루틴의 멈춤 없이 백그라운드에서 즉시 실행됩니다.
			go sendParkingEvent(apiUrl)
		}

		// 정해진 시간만큼 대기
		time.Sleep(sleepTime)
	}
}
