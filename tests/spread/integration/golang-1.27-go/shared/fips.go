package main

import (
	"crypto/fips140"
	"crypto/sha256"
	"fmt"
	"runtime/debug"
)

func main() {
	if !fips140.Enabled() {
		panic("FIPS mode is disabled")
	}
	fmt.Printf("%x\n", sha256.Sum256([]byte("abc")))
	info, ok := debug.ReadBuildInfo()
	if !ok {
		panic("missing build information")
	}
	for _, setting := range info.Settings {
		if setting.Key == "GOFIPS140" {
			fmt.Println(setting.Value)
			return
		}
	}
	panic("missing GOFIPS140 build setting")
}
