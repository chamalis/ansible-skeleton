FROM golang:alpine AS build

WORKDIR /go/src/app

RUN apk --no-cache add gcc g++ make git

COPY . .

# RUN go mod init webserver
# RUN go mod tidy
RUN GOOS=linux go build -ldflags="-s -w" -o ./bin/webapp ./app/main.go


FROM alpine:3.17

EXPOSE 8000
WORKDIR /usr/bin

COPY --from=build /go/src/app/bin /go/bin

RUN adduser --uid 1000 --disabled-password --gecos '' --home /home/deploy deploy
USER deploy

ENTRYPOINT /go/bin/webapp
