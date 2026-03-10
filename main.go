package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/google/uuid"
)

// 1. JSON 데이터 규격
type ParkingEvent struct {
	VehicleNum  string    `json:"vehicle_num"`
	VehicleType string    `json:"vehicle_type"`
	ZoneID      int       `json:"zone_id"`
	SlotCode    string    `json:"slot_code"`
	Status      string    `json:"status"`
	UpdateAt    time.Time `json:"update_at"`
}

// 차량 정보 구조체
type ParkedCar struct {
	VehicleNum  string
	VehicleType string
	ZoneID      int
}

var (
	// 현재 주차된 차량들을 기억하는 메모리 장부 (Key: SlotCode)
	parkingLot = make(map[string]ParkedCar)

	// 여러 고루틴이 동시에 장부를 건드리지 못하게 막는 자물쇠
	lotMutex sync.Mutex
)

// 2. 가상의 차량 번호판 생성 함수
func generatePlate() string {
	chars := []string{"가", "나", "다", "라", "마", "바", "사", "아", "자", "차"}
	front := rand.Intn(990) + 10 // 10 ~ 999
	char := chars[rand.Intn(len(chars))]
	back := rand.Intn(9000) + 1000 // 1000 ~ 9999
	return fmt.Sprintf("%02d%s%04d", front, char, back)
}

// 3. 가상의 차종(enum) 생성 함수
func generateVehicleType() string {
	types := []string{"GENERAL", "EV", "DISABLED"}
	return types[rand.Intn(len(types))]
}

// 4. 실제로 HTTP 요청을 쏘는 함수 (고루틴으로 비동기 실행됨)
func sendParkingEvent(apiUrl string, event ParkingEvent) {
	actionText := "출차(EXIT)"
	if event.Status == "PARKED" {
		actionText = "입차(ENTRY)"
	}

	jsonData, err := json.Marshal(event)
	if err != nil {
		fmt.Println("❌ JSON 변환 오류:", err)
		return
	}

	req, err := http.NewRequest("POST", apiUrl, bytes.NewBuffer(jsonData))
	if err != nil {
		fmt.Println("❌ HTTP 요청 생성 오류:", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Idempotency-Key", uuid.New().String())

	client := &http.Client{}
	resp, err := client.Do(req)

	if err != nil {
		fmt.Printf("❌ 전송 실패 | %s | %s | 사유: %v\n", actionText, event.VehicleNum, err)
		return
	}
	defer resp.Body.Close()
	fmt.Printf("✅ 전송 성공 | %s | %s | Zone: %d | Slot: %s | 상태 코드: %d\n", actionText, event.VehicleNum, event.ZoneID, event.SlotCode, resp.StatusCode)
}

func main() {
	apiUrl := os.Getenv("API_URL")
	if apiUrl == "" {
		apiUrl = "https://httpbin.org/post"
		//apiUrl = "http://localhost:8000/api/v1/parking/event"
		fmt.Println("⚠️ API_URL 환경 변수가 없어 기본값(localhost)을 사용합니다.")
	}

	fmt.Printf("🚀 주차장 트래픽 봇 가동 시작 (타겟: %s)\n", apiUrl)

	for {
		now := time.Now()
		hour := now.Hour()

		var burstCount int
		var sleepTime time.Duration

		if (hour >= 8 && hour <= 9) || (hour >= 18 && hour <= 19) {
			burstCount = 10
			sleepTime = 1 * time.Second
		} else if hour >= 0 && hour <= 5 {
			burstCount = 1
			sleepTime = 10 * time.Second
		} else {
			burstCount = 1
			sleepTime = 2 * time.Second
		}

		for i := 0; i < burstCount; i++ {
			// 장부 조작 시작 전 자물쇠 채우기 (데이터 충돌 방지)
			lotMutex.Lock()

			isEntry := true
			// 주차장에 차가 1대라도 있으면, 50% 확률로 입차/출차 결정
			if len(parkingLot) > 0 {
				isEntry = rand.Intn(2) == 0
			}

			var event ParkingEvent

			if isEntry {
				// ======= [입차 로직] =======
				var slotCode string
				var zoneID int
				// 빈 자리 찾을 때까지 무한 반복
				for {
					zoneID = rand.Intn(100) + 1
					slotNum := rand.Intn(100) + 1
					slotCode = fmt.Sprintf("Z%d-%03d", zoneID, slotNum)
					// 장부에 없는 자리면 통과!
					if _, exists := parkingLot[slotCode]; !exists {
						break
					}
				}

				plate := generatePlate()
				vType := generateVehicleType()

				// 장부에 새로 입차한 차 기록하기
				parkingLot[slotCode] = ParkedCar{
					VehicleNum:  plate,
					VehicleType: vType,
					ZoneID:      zoneID,
				}

				event = ParkingEvent{
					VehicleNum:  plate,
					VehicleType: vType,
					ZoneID:      zoneID,
					SlotCode:    slotCode,
					Status:      "PARKED",
					UpdateAt:    time.Now(),
				}
			} else {
				// ======= [출차 로직] =======
				var exitSlot string
				var carToExit ParkedCar

				// 장부를 훑어서 아무 차나 한 대 뽑기 (Go의 map 순회는 무작위로 작동함)
				for slot, car := range parkingLot {
					exitSlot = slot
					carToExit = car
					break // 한 대만 찾으면 바로 멈춤
				}

				// 장부에서 해당 차량 지우기 (출차 처리)
				delete(parkingLot, exitSlot)

				event = ParkingEvent{
					VehicleNum:  carToExit.VehicleNum,  // 입차했던 차 번호 그대로
					VehicleType: carToExit.VehicleType, // 입차했던 차종 그대로
					ZoneID:      carToExit.ZoneID,
					SlotCode:    exitSlot, // 입차했던 자리 그대로
					Status:      "EXITED",
					UpdateAt:    time.Now(),
				}
			}

			// 장부 조작이 끝났으니 자물쇠 풀기
			lotMutex.Unlock()

			go sendParkingEvent(apiUrl, event)
		}

		time.Sleep(sleepTime)
	}
}
