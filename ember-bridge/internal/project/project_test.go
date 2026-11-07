package project

import (
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"unicode/utf8"
)

func TestSlug(t *testing.T) {
	cases := map[string]string{
		"막차 정류장 등불":           "막차-정류장-등불",
		"  Hello, World!!  ":  "hello-world",
		"My_Game v2.0":        "my-game-v2-0",
		"":                    FallbackSlug,
		"!!! ??? ...":         FallbackSlug,
		"../../etc/passwd":    "etc-passwd",
		`C:\Windows\System32`: "c-windows-system32",
		"東京 タワー":              "東京-タワー",
		"Ключ-Игра":           "ключ-игра",
		"CON":                 "con-project",
		"게임—설계 🎲 문서":          "게임-설계-문서",
	}
	for in, want := range cases {
		if got := Slug(in); got != want {
			t.Errorf("Slug(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestSlugMaxLength(t *testing.T) {
	long := strings.Repeat("가", 100)
	got := Slug(long)
	if n := utf8.RuneCountInString(got); n != MaxSlugRunes {
		t.Fatalf("len = %d, want %d", n, MaxSlugRunes)
	}
	// A cut that lands right after a separator must not leave a trailing '-'.
	s := Slug(strings.Repeat("a", 59) + " bcd")
	if strings.HasSuffix(s, "-") || utf8.RuneCountInString(s) > MaxSlugRunes {
		t.Fatalf("bad trimmed slug %q", s)
	}
}

func TestCleanRelPathAccepts(t *testing.T) {
	ok := map[string]string{
		"CLAUDE.md":              "CLAUDE.md",
		"docs/DESIGN.md":         "docs/DESIGN.md",
		`docs\DESIGN.md`:         "docs/DESIGN.md",
		"기획/세계관 설정.md":           "기획/세계관 설정.md",
		".ember/notes.md":        ".ember/notes.md",
		"a/b/c/d.txt":            "a/b/c/d.txt",
		"..hidden/file..name.md": "..hidden/file..name.md",
		".github/workflows/x.md": ".github/workflows/x.md",
		".gitignore":             ".gitignore",
		"notes~draft.md":         "notes~draft.md",
		"claude/notes.md":        "claude/notes.md",
	}
	for in, want := range ok {
		got, err := CleanRelPath(in)
		if err != nil || got != want {
			t.Errorf("CleanRelPath(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
}

func TestCleanRelPathRejects(t *testing.T) {
	bad := []string{
		"",
		"..",
		"../x",
		"../../etc/passwd",
		"docs/../../x",
		"docs/..",
		"./x",
		"a/./b",
		`..\x`,
		`docs\..\..\x`,
		"/etc/passwd",
		`\Windows\System32\x`,
		`\\server\share\x`,
		"//server/share/x",
		"C:/Windows/x",
		`C:\Windows\x`,
		"C:x",
		"c:",
		"file.txt:stream",
		"a//b",
		"a/",
		"nul\x00byte",
		"a/b\x00",
		"line\nbreak",
		"CON",
		"docs/aux.txt",
		"LPT1.md",
		"trailing.",
		"trailing ",
		" leading",
		"what?.md",
		"star*.md",
		"pipe|x",
		"<x>",
		`quote".md`,
		".git/hooks/pre-commit",
		".GIT/config",
		"sub/.git/config",
		"sub/.Git",
		"GIT~1/config",
		"git~12/hooks/x",
		"docs/PROGRA~1.md",
		".claude/settings.json",
		"x/.CLAUDE/commands/a.md",
		".vscode/tasks.json",
		"a/b/.idea/workspace.xml",
		".mcp.json",
		"nested/.MCP.json",
		".envrc",
		"app/.envrc",
		"evil\u202egpj.md",
		"docs/\u200bhidden.md",
		"bom\ufeff.md",
		"c1\u0085ctrl.md",
		strings.Repeat("a", 600),
		"bad\xffutf8",
	}
	for _, in := range bad {
		if got, err := CleanRelPath(in); !errors.Is(err, ErrBadPath) {
			t.Errorf("CleanRelPath(%q) = %q, %v; want ErrBadPath", in, got, err)
		}
	}
}

func TestValidateFolderName(t *testing.T) {
	for _, ok := range []string{"my-game", "막차 정류장", "game_v2"} {
		if err := ValidateFolderName(ok); err != nil {
			t.Errorf("%q rejected: %v", ok, err)
		}
	}
	for _, bad := range []string{"", ".", "..", "a/b", `a\b`, "../x", "C:", "/abs", "nul", "50%off", "x\x00", "dot.",
		".git", ".GIT", "GIT~1", "my~2game", ".claude", ".vscode", ".idea", ".mcp.json", ".envrc",
		"a\u202eb", "zero\u200bwidth", "c1\u009bx"} {
		if err := ValidateFolderName(bad); err == nil {
			t.Errorf("%q accepted", bad)
		}
	}
}

func TestSafeJoin(t *testing.T) {
	base := t.TempDir()
	if _, err := SafeJoin(base, "a/b.md"); err != nil {
		t.Fatal(err)
	}
	for _, bad := range []string{"..", "../x", "a/../../x", ".", ""} {
		if _, err := SafeJoin(base, bad); err == nil {
			t.Errorf("SafeJoin(%q) accepted", bad)
		}
	}
}

func TestProjectDir(t *testing.T) {
	root := t.TempDir()
	dir, err := ProjectDir(root, "", "막차 정류장 등불")
	if err != nil || dir != filepath.Join(root, "막차-정류장-등불") {
		t.Fatalf("got %q, %v", dir, err)
	}
	dir, err = ProjectDir(root, "custom", "ignored")
	if err != nil || dir != filepath.Join(root, "custom") {
		t.Fatalf("got %q, %v", dir, err)
	}
	if _, err := ProjectDir(root, "../escape", "x"); !errors.Is(err, ErrBadFolder) {
		t.Fatalf("expected ErrBadFolder, got %v", err)
	}
}

func TestWriteStaysInsideFolder(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "proj")
	files := []File{
		{Path: "CLAUDE.md", Content: "# 규칙"},
		{Path: `docs\DESIGN.md`, Content: "설계"},
	}
	saved, err := Write(root, dir, files, "프롬프트 본문")
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(saved, ",") != "CLAUDE.md,docs/DESIGN.md" {
		t.Fatalf("saved = %v", saved)
	}
	b, err := os.ReadFile(filepath.Join(dir, "docs", "DESIGN.md"))
	if err != nil || string(b) != "설계" {
		t.Fatalf("DESIGN.md = %q, %v", b, err)
	}
	b, err = os.ReadFile(filepath.Join(dir, ".ember", "prompt.md"))
	if err != nil || string(b) != "프롬프트 본문" {
		t.Fatalf("prompt.md = %q, %v", b, err)
	}
	assertOnlyInside(t, root, dir)
}

func TestWriteRejectsWholeRequestOnBadPath(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "proj")
	files := []File{
		{Path: "ok.md", Content: "x"},
		{Path: "../evil.md", Content: "x"},
	}
	if _, err := Write(root, dir, files, "p"); !errors.Is(err, ErrBadPath) {
		t.Fatalf("expected ErrBadPath, got %v", err)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatalf("project folder should not have been created")
	}
	if _, err := os.Stat(filepath.Join(root, "evil.md")); !os.IsNotExist(err) {
		t.Fatalf("evil.md written outside")
	}
}

func TestWriteRefusesSymlinkEscape(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("symlinks need privileges on Windows")
	}
	root := t.TempDir()
	outside := t.TempDir()
	dir := filepath.Join(root, "proj")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	// A pre-existing link inside the project that points outside it.
	if err := os.Symlink(outside, filepath.Join(dir, "docs")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(outside, "target.md"), filepath.Join(dir, "link.md")); err != nil {
		t.Fatal(err)
	}
	if _, err := Write(root, dir, []File{{Path: "docs/x.md", Content: "x"}}, ""); err == nil {
		t.Fatal("write through symlinked folder accepted")
	}
	if _, err := Write(root, dir, []File{{Path: "link.md", Content: "x"}}, ""); err == nil {
		t.Fatal("write through symlinked file accepted")
	}
	entries, _ := os.ReadDir(outside)
	if len(entries) != 0 {
		t.Fatalf("files appeared outside: %v", entries)
	}
}

func TestWritePermissions(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Unix permission bits only")
	}
	root := filepath.Join(t.TempDir(), "EmberProjects")
	dir := filepath.Join(root, "proj")
	if _, err := Write(root, dir, []File{{Path: "docs/a.md", Content: "x"}}, "p"); err != nil {
		t.Fatal(err)
	}
	for rel, want := range map[string]os.FileMode{
		"":                      0o700,
		"proj":                  0o700,
		"proj/docs":             0o700,
		"proj/.ember":           0o700,
		"proj/docs/a.md":        0o600,
		"proj/.ember/prompt.md": 0o600,
	} {
		fi, err := os.Stat(filepath.Join(root, filepath.FromSlash(rel)))
		if err != nil {
			t.Fatal(err)
		}
		if got := fi.Mode().Perm(); got != want {
			t.Errorf("%s: mode %o, want %o", rel, got, want)
		}
	}
}

// assertOnlyInside fails if anything under root lives outside dir.
func assertOnlyInside(t *testing.T, root, dir string) {
	t.Helper()
	_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if p == root || p == dir {
			return nil
		}
		if !strings.HasPrefix(p, dir+string(filepath.Separator)) {
			t.Errorf("unexpected path outside project folder: %s", p)
		}
		return nil
	})
}
