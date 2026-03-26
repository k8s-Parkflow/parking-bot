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
        parkingLot  = make(map[int]ParkedCar)
        lotMutex    sync.Mutex
        maxSlots    = 1000 // DB에 생성한 슬롯 1000개
)

// 🚀 DB에 미리 등록한 100가1001 ~ 2000 번호판만 생성
func generateRegisteredPlate() string {
        num := rand.Intn(1000) + 1001
        return fmt.Sprintf("100가%d", num)
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
        if err != nil {
                fmt.Printf("❌ [%s] 요청 생성 실패: %v\n", action, err)
                return
        }

        req.Header.Set("Content-Type", "application/json")
        req.Header.Set("Idempotency-Key", uuid.New().String())

        client := &http.Client{Timeout: 10 * time.Second}
        resp, err := client.Do(req)
        if err != nil {
                fmt.Printf("❌ [%s] 네트워크 오류: %v\n", action, err)
                return
        }
        defer resp.Body.Close()

        if resp.StatusCode >= 200 && resp.StatusCode < 300 {
                fmt.Printf("✅ [%s] 성공 | 차량:%s | 슬롯:%d\n", action, event.VehicleNum, event.SlotID)
        } else {
                fmt.Printf("⚠️ [%s] 거절 | 코드:%d | 차량:%s | 슬롯:%d\n", action, resp.StatusCode, event.VehicleNum, event.SlotID)
        }
}

func main() {
        apiUrl := os.Getenv("API_URL")
        if apiUrl == "" {
                apiUrl = "http://orchestration-http:8000/api/v1/parking"
        }

        rand.Seed(time.Now().UnixNano())
        fmt.Printf("🚀 등록 차량 전용 트래픽 봇 가동 (Target: %s)\n", apiUrl)

        for {
                lotMutex.Lock()

                // 입차할지 출차할지 결정 (입차 확률 70%)
                isEntry := true
                if len(parkingLot) >= maxSlots {
                        isEntry = false
                } else if len(parkingLot) > 0 {
                        isEntry = rand.Intn(10) < 7
                }

                if isEntry {
                        // 빈 슬롯 찾기 시도
                        slotID := rand.Intn(maxSlots) + 1
                        currentZoneID := ((slotID - 1) / 100) + 1
                        if _, exists := parkingLot[slotID]; !exists {
                                plate := generateRegisteredPlate()
                                vType := "GENERAL" // DB 등록 시 기본값으로 맞춤

                                // 이미 주차된 차량인지 체크 (중복 입차 방지)
                                alreadyParked := false
                                for _, car := range parkingLot {
                                        if car.VehicleNum == plate {
                                                alreadyParked = true
                                                break
                                        }
                                }

                                if !alreadyParked {
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
                        // 주차된 차 중 하나 무작위 출차
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
                time.Sleep(3 * time.Second)
        }
}
