package main

import (
	"bytes"
	"crypto/mlkem"
	"crypto/mlkem/mlkemtest"
	"fmt"
)

func main() {
	key, err := mlkem.NewDecapsulationKey768(make([]byte, 64))
	if err != nil {
		panic(err)
	}
	sharedKey, ciphertext, err := mlkemtest.Encapsulate768(key.EncapsulationKey(), make([]byte, 32))
	if err != nil {
		panic(err)
	}
	recoveredKey, err := key.Decapsulate(ciphertext)
	if err != nil {
		panic(err)
	}
	if !bytes.Equal(sharedKey, recoveredKey) {
		panic("ML-KEM shared keys differ")
	}
	fmt.Println("mlkemtest works")
}
