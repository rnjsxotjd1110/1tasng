// Package launcher hides everything that starts other programs (terminal,
// Claude Code, clipboard tools, file manager) behind an interface, so the
// HTTP server can be tested with a fake.
package launcher

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Executor is the OS-facing side of the bridge.
type Executor interface {
	// FindClaude returns the path of the Claude Code CLI if it is installed.
	FindClaude() (path string, ok bool)
	// CopyToClipboard puts UTF-8 text on the system clipboard.
	CopyToClipboard(text string) error
	// LaunchClaude opens a NEW terminal window in folder and starts Claude
	// Code (claudePath) with the prompt saved at folder/.ember/prompt.md.
	LaunchClaude(folder, claudePath string) error
	// OpenFolder shows folder in the file manager.
	OpenFolder(folder string) error
}

// Timeouts for the helper programs. The HTTP server's WriteTimeout must be
// longer than the slowest path through /ember/send (launch, then the
// clipboard fallback), or the phone never gets the response.
const (
	// LaunchTimeout bounds osascript (macOS), which may wait on the
	// "control Terminal" permission dialog the first time.
	LaunchTimeout = 40 * time.Second
	// ClipboardTimeout bounds one clipboard helper run.
	ClipboardTimeout = 20 * time.Second
	// OpenFolderTimeout bounds opening the file manager (darwin waits for it).
	OpenFolderTimeout = 10 * time.Second
)

// New returns the Executor for the current OS.
func New() Executor { return osExecutor{} }

// WindowsClaudeInstruction is the first message given to Claude Code on
// Windows. Passing a long multi-line prompt with quotes as a command-line
// argument through PowerShell 5.1 (and npm's claude.cmd shim) mangles it, so
// on Windows Claude is asked to read the saved prompt file instead. It is
// plain ASCII with no quotes so it survives every quoting layer.
const WindowsClaudeInstruction = "Read the file .ember/prompt.md in this folder and do what it asks. It is my request, written in the Ember app."

// PSSingleQuote returns s as a PowerShell single-quoted string literal.
// PowerShell also treats the typographic quotes as single quotes, so those
// are doubled too.
func PSSingleQuote(s string) string {
	var b strings.Builder
	b.WriteByte('\'')
	for _, r := range s {
		switch r {
		case '\'', '‘', '’', '‚', '‛':
			b.WriteRune(r)
			b.WriteRune(r)
		default:
			b.WriteRune(r)
		}
	}
	b.WriteByte('\'')
	return b.String()
}

// ShSingleQuote returns s quoted for a POSIX shell.
func ShSingleQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// AppleScriptString returns s as an AppleScript string literal.
func AppleScriptString(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return `"` + s + `"`
}

// UnixClaudeCommand is the shell command run in the new terminal on
// macOS/Linux: cd into the project and start Claude with the saved prompt.
// The "--" ends option parsing, so a prompt that starts with '-' (say
// "--dangerously-skip-permissions") is always the prompt, never a flag.
func UnixClaudeCommand(folder, claudePath string) string {
	return "cd " + ShSingleQuote(folder) + " && " + ShSingleQuote(claudePath) +
		` -- "$(cat .ember/prompt.md)"`
}

// WindowsClaudeScript is the PowerShell -Command script for the new window.
func WindowsClaudeScript(folder, claudePath string) string {
	return "$Host.UI.RawUI.WindowTitle = 'Ember - Claude Code'; " +
		"Set-Location -LiteralPath " + PSSingleQuote(folder) + "; " +
		"& " + PSSingleQuote(claudePath) + " " + PSSingleQuote(WindowsClaudeInstruction)
}

// findClaude looks in PATH first, then in the usual install locations (a
// bridge started from a desktop shortcut may not see the user's shell PATH).
func findClaude(names []string, extraDirs []string) (string, bool) {
	for _, n := range names {
		if p, err := exec.LookPath(n); err == nil {
			if abs, err := filepath.Abs(p); err == nil {
				p = abs
			}
			return p, true
		}
	}
	for _, d := range extraDirs {
		if d == "" {
			continue
		}
		for _, n := range names {
			p := filepath.Join(d, n)
			if fi, err := os.Stat(p); err == nil && !fi.IsDir() {
				return p, true
			}
		}
	}
	return "", false
}

func homeJoin(parts ...string) string {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return ""
	}
	return filepath.Join(append([]string{home}, parts...)...)
}
