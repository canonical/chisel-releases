package hello_test

import (
	"hello"
	"testing"
)

func TestMain(t *testing.T) {
	expected := "Hello, World!"
	t.Logf("expected: %s", expected)
	if got := hello.Hello(); got != expected {
		t.Errorf("expect %v, got %v", expected, got)
	}
}
