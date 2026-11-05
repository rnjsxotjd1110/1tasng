//go:build windows

// Package console prepares the terminal window the bridge runs in.
package console

import (
	"bufio"
	"fmt"
	"os"
	"unsafe"

	"golang.org/x/sys/windows"
)

// Setup switches the console to UTF-8 so Korean text prints correctly in
// the classic conhost window, and sets the window title.
func Setup(title string) {
	_ = windows.SetConsoleOutputCP(65001)
	_ = windows.SetConsoleCP(65001)
	if p, err := windows.UTF16PtrFromString(title); err == nil {
		proc := windows.NewLazySystemDLL("kernel32.dll").NewProc("SetConsoleTitleW")
		if proc.Find() == nil {
			_, _, _ = proc.Call(uintptr(unsafe.Pointer(p)))
		}
	}
}

// WaitBeforeExit keeps a double-clicked window open after a fatal error so
// the message can be read.
func WaitBeforeExit() {
	fmt.Println()
	fmt.Println("엔터 키를 누르면 창이 닫혀요.")
	_, _ = bufio.NewReader(os.Stdin).ReadString('\n')
}
