package launcher

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestPSSingleQuote(t *testing.T) {
	cases := map[string]string{
		`C:\Users\me\EmberProjects\막차`: `'C:\Users\me\EmberProjects\막차'`,
		`C:\it's`:                      `'C:\it''s'`,
		"C:\\a\u2019b":                 "'C:\\a\u2019\u2019b'",
		`$env:x; rm -r *`:              `'$env:x; rm -r *'`,
	}
	for in, want := range cases {
		if got := PSSingleQuote(in); got != want {
			t.Errorf("PSSingleQuote(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestWindowsClaudeScript(t *testing.T) {
	s := WindowsClaudeScript(`C:\Users\O'Brien\EmberProjects\게임`, `C:\Users\O'Brien\.local\bin\claude.exe`)
	for _, want := range []string{
		`Set-Location -LiteralPath 'C:\Users\O''Brien\EmberProjects\게임'`,
		`& 'C:\Users\O''Brien\.local\bin\claude.exe' 'Read the file .ember/prompt.md`,
	} {
		if !strings.Contains(s, want) {
			t.Errorf("script %q missing %q", s, want)
		}
	}
	if strings.Contains(s, `"`) {
		t.Error("script must not contain double quotes (they break Windows argument quoting)")
	}
	if strings.ContainsAny(WindowsClaudeInstruction, `"'`+"\n") {
		t.Error("instruction must be quote/newline free")
	}
}

func TestUnixClaudeCommandRunsInShell(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX shell only")
	}
	sh, err := exec.LookPath("sh")
	if err != nil {
		t.Skip("no sh")
	}
	// A folder name with quotes and $() must not break out of the cd.
	weird := filepath.Join(t.TempDir(), `it's "here" $(touch pwned)`)
	if err := os.MkdirAll(filepath.Join(weird, ".ember"), 0o755); err != nil {
		t.Fatal(err)
	}
	// The prompt is passed verbatim as ONE argument: quotes, $VARS, backticks
	// and newlines are not interpreted. printf (no % or \ in the prompt)
	// stands in for claude and echoes its first argument.
	prompt := "첫 줄 \"따옴표\" $HOME `id` it's\n둘째 줄"
	if err := os.WriteFile(filepath.Join(weird, ".ember", "prompt.md"), []byte(prompt), 0o644); err != nil {
		t.Fatal(err)
	}
	out, err := exec.Command(sh, "-c", UnixClaudeCommand(weird, "printf")).Output()
	if err != nil {
		t.Fatal(err)
	}
	if string(out) != prompt {
		t.Fatalf("got %q, want %q", out, prompt)
	}
	if _, err := os.Stat("pwned"); err == nil {
		t.Fatal("folder name was executed")
	}
}

func TestUnixClaudeCommandPromptIsNeverAnOption(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX shell only")
	}
	sh, err := exec.LookPath("sh")
	if err != nil {
		t.Skip("no sh")
	}
	if !strings.Contains(UnixClaudeCommand("/x", "/bin/claude"), `'/bin/claude' -- "$(cat .ember/prompt.md)"`) {
		t.Fatalf("command lacks --: %s", UnixClaudeCommand("/x", "/bin/claude"))
	}
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, ".ember"), 0o755); err != nil {
		t.Fatal(err)
	}
	prompt := "--dangerously-skip-permissions -p hi"
	if err := os.WriteFile(filepath.Join(dir, ".ember", "prompt.md"), []byte(prompt), 0o644); err != nil {
		t.Fatal(err)
	}
	// A stand-in claude that prints each argument on its own line.
	fake := filepath.Join(t.TempDir(), "claude")
	if err := os.WriteFile(fake, []byte("#!/bin/sh\nfor a in \"$@\"; do printf '[%s]\\n' \"$a\"; done\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	out, err := exec.Command(sh, "-c", UnixClaudeCommand(dir, fake)).Output()
	if err != nil {
		t.Fatal(err)
	}
	if want := "[--]\n[" + prompt + "]\n"; string(out) != want {
		t.Fatalf("got %q, want %q", out, want)
	}
}

func TestWindowsInstructionIsNotAnOption(t *testing.T) {
	if strings.HasPrefix(WindowsClaudeInstruction, "-") {
		t.Fatal("the fixed Windows first message must not look like an option")
	}
}

func TestAppleScriptString(t *testing.T) {
	got := AppleScriptString(`cd '/a b' && claude "$(cat x)" \n`)
	want := `"cd '/a b' && claude \"$(cat x)\" \\n"`
	if got != want {
		t.Fatalf("got %s want %s", got, want)
	}
}

func TestShSingleQuote(t *testing.T) {
	if got := ShSingleQuote("it's"); got != `'it'\''s'` {
		t.Fatal(got)
	}
}
