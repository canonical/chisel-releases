package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"time"
)

func main() {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "ok")
	}))
	defer server.Close()

	client := server.Client()
	client.Timeout = 10 * time.Second
	response, err := client.Get(server.URL)
	if err != nil {
		panic(err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		panic(err)
	}
	if response.StatusCode != http.StatusOK || string(body) != "ok" {
		panic("unexpected HTTPS response")
	}
	fmt.Println("httptest works")
}
