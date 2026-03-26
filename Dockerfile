# 1단계: 빌드 환경
FROM golang:1.25-alpine AS builder
WORKDIR /app

# 의존성 설치
COPY go.mod go.sum ./
RUN go mod download

# 소스 복사 및 빌드
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o parking-bot main.go

# 2단계: 실행 환경
FROM alpine:latest
WORKDIR /root/

# 필수 패키지 설치 (시간대 설정 + HTTPS 통신 지원)
RUN apk --no-cache add tzdata ca-certificates
ENV TZ=Asia/Seoul

# 빌드된 바이너리만 복사
COPY --from=builder /app/parking-bot .

# 실행 권한 확인 및 환경 변수 기본값
ENV API_URL="http://orchestration-http:8000/api/v1/parking/event"

CMD ["./parking-bot"]
