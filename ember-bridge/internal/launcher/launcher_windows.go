//go:build windows

package launcher

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/windows"
)

type osExecutor struct{}

func powershellPath() string {
	if root := os.Getenv("SystemRoot"); root != "" {
		p := filepath.Join(root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return "powershell.exe"
}

func (osExecutor) FindClaude() (string, bool) {
	return findClaude(
		[]string{"claude.exe", "claude.cmd"},
		[]string{
			homeJoin(".local", "bin"),
			filepath.Join(os.Getenv("APPDATA"), "npm"),
			homeJoin(".claude", "local"),
		},
	)
}

// CopyToClipboard writes the text to a temporary UTF-8 file and lets
// PowerShell read it with an explicit encoding, so Korean text survives
// regardless of the console code page.
func (osExecutor) CopyToClipboard(text string) error {
	f, err := os.CreateTemp("", "ember-clip-*.txt")
	if err != nil {
		return err
	}
	tmp := f.Name()
	defer os.Remove(tmp)
	if _, err := f.WriteString(text); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	script := "Get-Content -Raw -Encoding UTF8 -LiteralPath " + PSSingleQuote(tmp) + " | Set-Clipboard"
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, powershellPath(), "-NoProfile", "-NonInteractive", "-Command", script)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("Set-Clipboard: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

// LaunchClaude starts PowerShell in its own new console window (the same
// effect as `start`, without cmd.exe's quoting rules) and runs Claude Code
// there. -ExecutionPolicy Bypass lets npm's claude.ps1 shim run for this
// window only.
func (osExecutor) LaunchClaude(folder, claudePath string) error {
	cmd := exec.Command(powershellPath(), "-NoExit", "-ExecutionPolicy", "Bypass",
		"-Command", WindowsClaudeScript(folder, claudePath))
	cmd.Dir = folder
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: windows.CREATE_NEW_CONSOLE}
	if err := cmd.Start(); err != nil {
		return err
	}
	go cmd.Wait() //nolint:errcheck // reap the child; its exit code does not matter
	return nil
}

func (osExecutor) OpenFolder(folder string) error {
	cmd := exec.Command("explorer.exe", folder)
	if err := cmd.Start(); err != nil {
		return err
	}
	go cmd.Wait() //nolint:errcheck // explorer.exe returns 1 even on success
	return nil
}
