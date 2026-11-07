//go:build darwin

package launcher

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type osExecutor struct{}

func (osExecutor) FindClaude() (string, bool) {
	return findClaude([]string{"claude"}, []string{
		homeJoin(".local", "bin"),
		homeJoin(".claude", "local"),
		homeJoin(".npm-global", "bin"),
		"/opt/homebrew/bin",
		"/usr/local/bin",
	})
}

func (osExecutor) CopyToClipboard(text string) error {
	ctx, cancel := context.WithTimeout(context.Background(), ClipboardTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "pbcopy")
	// pbcopy decodes stdin according to the locale; force UTF-8.
	cmd.Env = append(os.Environ(), "LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8")
	cmd.Stdin = strings.NewReader(text)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("pbcopy: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (osExecutor) LaunchClaude(folder, claudePath string) error {
	shell := UnixClaudeCommand(folder, claudePath)
	// The first run may show the macOS "control Terminal" permission dialog,
	// so allow plenty of time, but less than the HTTP WriteTimeout so the
	// phone still gets an answer (the clipboard fallback) if it times out.
	ctx, cancel := context.WithTimeout(context.Background(), LaunchTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "osascript",
		"-e", `tell application "Terminal"`,
		"-e", "activate",
		"-e", "do script "+AppleScriptString(shell),
		"-e", "end tell")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("osascript: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (osExecutor) OpenFolder(folder string) error {
	ctx, cancel := context.WithTimeout(context.Background(), OpenFolderTimeout)
	defer cancel()
	return exec.CommandContext(ctx, "open", folder).Run()
}
