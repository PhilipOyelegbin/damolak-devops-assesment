# First stage: Build the Go application
FROM golang:1.25.5-alpine AS builder
WORKDIR /app
COPY MuchToDo/go.mod .
COPY MuchToDo/go.sum .
RUN go mod tidy
COPY MuchToDo/ .
RUN go build -v -o /app/main ./cmd/api/main.go
RUN adduser -D appuser
RUN chown -R appuser:appuser /app
USER appuser

# Second stage: Minimal runtime image
FROM alpine:latest
RUN adduser -D appuser
USER appuser
WORKDIR /app
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
