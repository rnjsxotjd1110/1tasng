// Package project turns an Ember send request into files inside a project
// folder. Everything here is about never writing outside that folder.
package project

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"unicode"
	"unicode/utf8"
)

const (
	// FallbackSlug is used when a title has no letters or digits.
	FallbackSlug = "ember-project"
	// MaxSlugRunes is the longest folder name Slug produces.
	MaxSlugRunes = 60
	// PromptPath is where the prompt is saved, relative to the project folder.
	PromptPath = ".ember/prompt.md"

	maxPathBytes    = 512
	maxSegmentBytes = 200
	maxFolderRunes  = 100
)

var (
	// ErrBadPath means a file path in the request is not a safe relative path.
	ErrBadPath = errors.New("bad_path")
	// ErrBadFolder means the requested folder name is not a single safe name.
	ErrBadFolder = errors.New("bad_folder")
)

// File is one file the phone wants saved.
type File struct {
	Path    string `json:"path"`
	Content string `json:"content"`
}

// Slug turns a title into a folder name: letters and digits of any script are
// kept (Latin is lower-cased), every other run of characters becomes one '-'.
func Slug(title string) string {
	var b strings.Builder
	pendingDash := false
	for _, r := range title {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || (unicode.IsMark(r) && b.Len() > 0) {
			if pendingDash && b.Len() > 0 {
				b.WriteByte('-')
			}
			pendingDash = false
			b.WriteRune(unicode.ToLower(r))
			continue
		}
		pendingDash = true
	}
	s := b.String()
	if utf8.RuneCountInString(s) > MaxSlugRunes {
		s = string([]rune(s)[:MaxSlugRunes])
	}
	s = strings.Trim(s, "-")
	if s == "" {
		return FallbackSlug
	}
	if isWindowsReserved(s) {
		s += "-project"
	}
	return s
}

// ValidateFolderName checks the optional "folder" field: it must be one plain
// folder name (no separators, no traversal, nothing Windows refuses).
func ValidateFolderName(name string) error {
	if name == "" || utf8.RuneCountInString(name) > maxFolderRunes {
		return ErrBadFolder
	}
	if err := checkSegment(name); err != nil {
		return ErrBadFolder
	}
	if strings.ContainsRune(name, '%') {
		// '%' is expanded by cmd.exe; keep folder names boring.
		return ErrBadFolder
	}
	return nil
}

// CleanRelPath validates a file path from the request and returns it in a
// normalised forward-slash form. Backslashes are treated as separators so
// "..\\x" is caught as traversal on every OS.
func CleanRelPath(p string) (string, error) {
	if p == "" || len(p) > maxPathBytes || !utf8.ValidString(p) {
		return "", ErrBadPath
	}
	p = strings.ReplaceAll(p, "\\", "/")
	segs := strings.Split(p, "/")
	for _, seg := range segs {
		// An empty segment covers absolute paths ("/etc"), UNC paths
		// ("\\\\server\\share") and doubled separators.
		if err := checkSegment(seg); err != nil {
			return "", ErrBadPath
		}
	}
	if strings.EqualFold(segs[0], ".git") {
		return "", ErrBadPath
	}
	return strings.Join(segs, "/"), nil
}

func checkSegment(seg string) error {
	if seg == "" || seg == "." || seg == ".." || len(seg) > maxSegmentBytes {
		return ErrBadPath
	}
	for _, r := range seg {
		if r < 0x20 || r == 0x7f || r == utf8.RuneError {
			return ErrBadPath // control characters, NUL, invalid UTF-8
		}
		switch r {
		case '/', '\\', ':', '*', '?', '"', '<', '>', '|':
			// ':' also rules out drive letters ("C:") and NTFS streams.
			return ErrBadPath
		}
	}
	// Windows silently strips trailing dots and spaces, which would make two
	// different names point at the same file.
	if strings.HasSuffix(seg, ".") || strings.HasSuffix(seg, " ") || strings.HasPrefix(seg, " ") {
		return ErrBadPath
	}
	if isWindowsReserved(seg) {
		return ErrBadPath
	}
	return nil
}

var reservedNames = map[string]bool{
	"con": true, "prn": true, "aux": true, "nul": true,
	"com1": true, "com2": true, "com3": true, "com4": true, "com5": true,
	"com6": true, "com7": true, "com8": true, "com9": true,
	"lpt1": true, "lpt2": true, "lpt3": true, "lpt4": true, "lpt5": true,
	"lpt6": true, "lpt7": true, "lpt8": true, "lpt9": true,
}

func isWindowsReserved(seg string) bool {
	base := strings.ToLower(seg)
	if i := strings.IndexByte(base, '.'); i >= 0 {
		base = base[:i]
	}
	return reservedNames[strings.TrimRight(base, " ")]
}

// ProjectDir returns root/<folder or slug(title)> as an absolute path.
func ProjectDir(root, folder, title string) (string, error) {
	name := Slug(title)
	if folder != "" {
		if err := ValidateFolderName(folder); err != nil {
			return "", err
		}
		name = folder
	}
	absRoot, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	dir, err := SafeJoin(absRoot, name)
	if err != nil {
		return "", ErrBadFolder
	}
	return dir, nil
}

// SafeJoin joins a cleaned relative slash path onto base and verifies, after
// filepath.Clean, that the result is strictly inside base.
func SafeJoin(base, rel string) (string, error) {
	base = filepath.Clean(base)
	target := filepath.Clean(filepath.Join(base, filepath.FromSlash(rel)))
	r, err := filepath.Rel(base, target)
	if err != nil || r == "." || r == ".." || filepath.IsAbs(r) ||
		strings.HasPrefix(r, ".."+string(filepath.Separator)) {
		return "", ErrBadPath
	}
	return target, nil
}

// Write saves files (and the prompt, when not empty) into dir, which is
// created inside root if needed. All paths are validated before anything is
// written. It returns the cleaned paths of the saved files (prompt excluded).
func Write(root, dir string, files []File, prompt string) ([]string, error) {
	cleaned := make([]string, len(files))
	for i, f := range files {
		p, err := CleanRelPath(f.Path)
		if err != nil {
			return nil, fmt.Errorf("%w: %q", ErrBadPath, f.Path)
		}
		if _, err := SafeJoin(dir, p); err != nil {
			return nil, fmt.Errorf("%w: %q", ErrBadPath, f.Path)
		}
		cleaned[i] = p
	}

	absRoot, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(absRoot, 0o755); err != nil {
		return nil, err
	}
	rel, err := filepath.Rel(absRoot, dir)
	if err != nil || rel == "." || rel == ".." || filepath.IsAbs(rel) ||
		strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return nil, ErrBadFolder
	}
	if err := mkdirNoLinks(absRoot, filepath.ToSlash(rel)); err != nil {
		return nil, err
	}

	saved := make([]string, 0, len(files))
	for i, f := range files {
		if err := writeOne(dir, cleaned[i], f.Content); err != nil {
			return saved, err
		}
		saved = append(saved, cleaned[i])
	}
	if prompt != "" {
		if err := writeOne(dir, PromptPath, prompt); err != nil {
			return saved, err
		}
	}
	return saved, nil
}

func writeOne(dir, rel, content string) error {
	target, err := SafeJoin(dir, rel)
	if err != nil {
		return err
	}
	if parent := filepath.ToSlash(filepath.Dir(rel)); parent != "." {
		if err := mkdirNoLinks(dir, parent); err != nil {
			return err
		}
	}
	if fi, err := os.Lstat(target); err == nil && !fi.Mode().IsRegular() {
		return fmt.Errorf("%w: %s is not a regular file", ErrBadPath, rel)
	}
	return os.WriteFile(target, []byte(content), 0o644)
}

// mkdirNoLinks creates base/rel one level at a time and refuses to walk
// through anything that is not a plain directory (symlinks, junctions), so a
// pre-existing link cannot redirect writes outside the project folder.
func mkdirNoLinks(base, rel string) error {
	cur := base
	for _, seg := range strings.Split(rel, "/") {
		cur = filepath.Join(cur, seg)
		fi, err := os.Lstat(cur)
		if errors.Is(err, fs.ErrNotExist) {
			if err := os.Mkdir(cur, 0o755); err != nil && !errors.Is(err, fs.ErrExist) {
				return err
			}
			continue
		}
		if err != nil {
			return err
		}
		if fi.Mode().Type() != fs.ModeDir {
			return fmt.Errorf("%w: %s is not a plain folder", ErrBadPath, cur)
		}
	}
	return nil
}
