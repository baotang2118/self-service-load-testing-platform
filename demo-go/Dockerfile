FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /demo-go .

FROM alpine:3.21
RUN adduser -D -u 10001 app
USER app
COPY --from=build /demo-go /usr/local/bin/demo-go
EXPOSE 8080
CMD ["demo-go"]