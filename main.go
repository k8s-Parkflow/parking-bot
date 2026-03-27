package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

type ParkingEvent struct {
	VehicleNum  string `json:"vehicle_num"`
	VehicleType string `json:"vehicle_type"`
	ZoneID      int    `json:"zone_id"`
	SlotID      int    `json:"slot_id"`
	Status      string `json:"status"`
	RequestedAt string `json:"requested_at"`
}

type ParkedCar struct {
	VehicleNum  string
	VehicleType string
	SlotID      int
}

var (
	parkingLot = make(map[int]ParkedCar)
	lotMutex   sync.Mutex
	maxSlots   = 1000
)

func generateRegisteredPlate() string {
	num := rand.Intn(1000) + 1001
	return fmt.Sprintf("100가%d", num)
}

func getVehicleTypeByPlate(plate string) string {
	var num int
	fmt.Sscanf(plate, "100가%d", &num)
	remainder := num % 10
	if remainder >= 1 && remainder <= 7 { return "GENERAL" }
	if remainder == 8 || remainder == 9 { return "EV" }
	return "DISABLED"
}

// 🚀 추가: 슬롯 번호에 따른 타입 판별
func getSlotType(slotID int) string {
	remainder := slotID % 10
	if remainder >= 1 && remainder <= 7 { return "GENERAL" }
	if remainder == 8 || remainder == 9 { return "EV" }
	return "DISABLED"
}

func sendParkingEvent(baseApiUrl string, event ParkingEvent) {
	var targetUrl string
	action := ""
	cleanBaseUrl := strings.TrimRight(baseApiUrl, "/")

	if event.Status == "PARKED" {
		targetUrl = cleanBaseUrl + "/entries/"
		action = "입차(ENTRY)"
	} else {
		targetUrl = cleanBaseUrl + "/exits/"
		action = "출차(EXIT)"
	}

	jsonData, _ := json.Marshal(event)
	req, err := http.NewRequest("POST", targetUrl, bytes.NewBuffer(jsonData))
	if err != nil { return }

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Idempotency-Key", uuid.New().String())

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil { return }
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		fmt.Printf("✅ [%s] 성공 | 차량:%s(%s) | 슬롯:%d\n", action, event.VehicleNum, event.VehicleType, event.SlotID)
	} else {
		fmt.Printf("⚠️ [%s] 거절 | 코드:%d | 차량:%s(%s) | 슬롯:%d\n", action, resp.StatusCode, event.VehicleNum, event.VehicleType, event.SlotID)
	}
}

func main() {
	apiUrl := os.Getenv("API_URL")
	if apiUrl == "" { apiUrl = "http://orchestration-http:8000/api/v1/parking" }

	rand.Seed(time.Now().UnixNano())
	fmt.Printf("🚀 규칙 기반 전용구역 트래픽 봇 가동 (Target: %s)\n", apiUrl)

	for {
		lotMutex.Lock()

		isEntry := true
		if len(parkingLot) >= maxSlots {
			isEntry = false
		} else if len(parkingLot) > 0 {
			isEntry = rand.Intn(10) < 7
		}

		if isEntry {
			slotID := rand.Intn(maxSlots) + 1
			if _, exists := parkingLot[slotID]; !exists {
				// 🚀 수정된 섹션: 슬롯 타입에 맞는 차량을 찾을 때까지 생성 시도
				sType := getSlotType(slotID)
				var plate string
				var vType string
				
				for {
					plate = generateRegisteredPlate()
					vType = getVehicleTypeByPlate(plate)
					if vType == sType {
						break
					}
				}
				
				// 🚀 이후 로직 동일
				alreadyParked := false
				for _, car := range parkingLot {
					if car.VehicleNum == plate {
						alreadyParked = true
						break
					}
				}

				if !alreadyParked {
					currentZoneID := ((slotID - 1) / 100) + 1
					parkingLot[slotID] = ParkedCar{VehicleNum: plate, VehicleType: vType, SlotID: slotID}
					event := ParkingEvent{
						VehicleNum:  plate,
						VehicleType: vType,
						ZoneID:      currentZoneID,
						SlotID:      slotID,
						Status:      "PARKED",
						RequestedAt: time.Now().UTC().Format("2006-01-02T15:04:05Z"),
					}
					go sendParkingEvent(apiUrl, event)
				}
			}
		} else if len(parkingLot) > 0 {
			var targetSlot int
			for sID := range parkingLot {
				targetSlot = sID
				break
			}
			currentZoneID := ((targetSlot - 1) / 100) + 1
			car := parkingLot[targetSlot]
			event := ParkingEvent{
				VehicleNum:  car.VehicleNum,
				VehicleType: car.VehicleType,
				ZoneID:      currentZoneID,
				SlotID:      targetSlot,
				Status:      "EXITED",
				RequestedAt: time.Now().UTC().Format("2006-01-02T15:04:05Z"),
			}
			delete(parkingLot, targetSlot)
			go sendParkingEvent(apiUrl, event)
		}

		lotMutex.Unlock()
		time.Sleep(1 * time.Second)
	}
}
