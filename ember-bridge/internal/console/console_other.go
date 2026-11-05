//go:build !windows

// Package console prepares the terminal window the bridge runs in.
package console

import (
	"fmt"
	"os"
)

// Setup sets the terminal title when stdout is a terminal (terminals on
// macOS/Linux are UTF-8 already).
func Setup(title string) {
	if fi, err := os.Stdout.Stat(); err == nil && fi.Mode()&os.ModeCharDevice != 0 {
		fmt.Printf("\033]0;%s\007", title)
	}
}

// WaitBeforeExit is a no-op outside Windows.
func WaitBeforeExit() {}
