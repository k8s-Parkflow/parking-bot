# 1단계: 빌드 환경 (Go 설치된 환경에서 리눅스용 실행 파일로 빌드)
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
# 쿠버네티스(리눅스) 환경에 맞춰서 빌드
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o parking-bot main.go

# 2단계: 실행 환경 (초경량 알파인 리눅스 사용)
FROM alpine:latest
WORKDIR /root/
# 한국 시간대(KST) 적용을 위한 패키지 설치
RUN apk --no-cache add tzdata
ENV TZ=Asia/Seoul
# 1단계에서 빌드된 실행 파일만 가져오기
COPY --from=builder /app/parking-bot .

# 컨테이너가 켜지면 봇 실행
CMD ["./parking-bot"]