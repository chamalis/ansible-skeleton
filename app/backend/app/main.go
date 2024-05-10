package main

import (
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"
)

const (
	DEFAULT_BIND_IP   = "0.0.0.0"
	DEFAULT_BIND_PORT = "80"
)

type Config struct {
	BindIp   string
	BindPort string
}

func LoadSettings() Config {
	var bindIp, bindPort string
	var exists bool

	if bindIp, exists = os.LookupEnv("BIND_IP"); !exists {
		bindIp = DEFAULT_BIND_IP
	}
	if bindPort, exists = os.LookupEnv("BIND_PORT"); !exists {
		bindPort = DEFAULT_BIND_PORT
	}

	return Config{
		BindIp:   bindIp,
		BindPort: bindPort,
	}
}

func main() {
	settings := LoadSettings()
	m := http.NewServeMux()

	m.HandleFunc("/clock", func(writer http.ResponseWriter, request *http.Request) {
		tstamp := time.Now().Unix()

		writer.Header().Set("Access-Control-Allow-Origin", "*")
		writer.Write([]byte(strconv.FormatInt(tstamp, 10)))
	})
	m.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		clock_url, _ := url.JoinPath("http://", request.Host, "clock")
		resp := "Online. Head to " + clock_url

		writer.Header().Set("Access-Control-Allow-Origin", "*")
		writer.Write([]byte(resp))
	})

	s := &http.Server{
		Addr:         settings.BindIp + ":" + settings.BindPort,
		Handler:      m,
		IdleTimeout:  time.Second * 10,
		ReadTimeout:  time.Second * 10,
		WriteTimeout: time.Second * 10,
	}
	log.Fatal(s.ListenAndServe())
}
