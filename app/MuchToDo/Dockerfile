FROM golang:1.25.1-alpine AS builder
WORKDIR /src
RUN apk add --no-cache git ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/much-to-do ./cmd/api/main.go

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=builder /out/much-to-do /app/much-to-do
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/much-to-do"]