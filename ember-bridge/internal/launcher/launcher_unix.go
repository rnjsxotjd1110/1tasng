//go:build !windows && !darwin

package launcher

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

type osExecutor struct{}

func (osExecutor) FindClaude() (string, bool) {
	return findClaude([]string{"claude"}, []string{
		homeJoin(".local", "bin"),
		homeJoin(".claude", "local"),
		homeJoin(".npm-global", "bin"),
		"/usr/local/bin",
	})
}

func (osExecutor) CopyToClipboard(text string) error {
	type tool struct {
		name string
		args []string
	}
	var tools []tool
	if os.Getenv("WAYLAND_DISPLAY") != "" {
		tools = append(tools, tool{"wl-copy", nil})
	}
	tools = append(tools,
		tool{"xclip", []string{"-selection", "clipboard"}},
		tool{"xsel", []string{"--clipboard", "--input"}},
		tool{"wl-copy", nil},
	)
	var lastErr error = errors.New("클립보드 도구(wl-copy, xclip, xsel)를 찾지 못했어요")
	for _, t := range tools {
		path, err := exec.LookPath(t.name)
		if err != nil {
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		cmd := exec.CommandContext(ctx, path, t.args...)
		cmd.Stdin = strings.NewReader(text)
		// No Stdout/Stderr pipes: xclip and wl-copy fork a helper that keeps
		// serving the clipboard and would hold a pipe open forever.
		err = cmd.Run()
		cancel()
		if err == nil {
			return nil
		}
		lastErr = fmt.Errorf("%s: %w", t.name, err)
	}
	return lastErr
}

func (osExecutor) LaunchClaude(folder, claudePath string) error {
	if os.Getenv("DISPLAY") == "" && os.Getenv("WAYLAND_DISPLAY") == "" {
		return errors.New("그래픽 화면(DISPLAY)이 없어 터미널 창을 열 수 없어요")
	}
	inner := UnixClaudeCommand(folder, claudePath) + `; exec "${SHELL:-bash}"`
	candidates := [][]string{
		{"x-terminal-emulator", "-e", "bash", "-c", inner},
		{"gnome-terminal", "--working-directory=" + folder, "--", "bash", "-c", inner},
		{"konsole", "--workdir", folder, "-e", "bash", "-c", inner},
		{"xfce4-terminal", "-x", "bash", "-c", inner},
		{"kitty", "bash", "-c", inner},
		{"alacritty", "-e", "bash", "-c", inner},
		{"xterm", "-e", "bash", "-c", inner},
	}
	for _, c := range candidates {
		path, err := exec.LookPath(c[0])
		if err != nil {
			continue
		}
		cmd := exec.Command(path, c[1:]...)
		cmd.Dir = folder
		if err := cmd.Start(); err != nil {
			continue
		}
		// A terminal that cannot open a window exits right away with an
		// error; one that works keeps running (or, like gnome-terminal,
		// hands off to a server and exits 0).
		done := make(chan error, 1)
		go func() { done <- cmd.Wait() }()
		select {
		case err := <-done:
			if err != nil {
				continue
			}
		case <-time.After(1500 * time.Millisecond):
		}
		return nil
	}
	return errors.New("터미널 프로그램을 찾지 못했어요")
}

func (osExecutor) OpenFolder(folder string) error {
	path, err := exec.LookPath("xdg-open")
	if err != nil {
		return err
	}
	cmd := exec.Command(path, folder)
	if err := cmd.Start(); err != nil {
		return err
	}
	go cmd.Wait() //nolint:errcheck
	return nil
}
