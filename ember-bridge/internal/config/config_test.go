package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLoadCreatesAndPersists(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ember-bridge", "config.json")
	s, warn, err := Load(path, "MY-PC")
	if err != nil || warn != "" {
		t.Fatal(err, warn)
	}
	if len(s.ID()) != 32 || s.Name() != "MY-PC" || s.Root() == "" {
		t.Fatalf("bad defaults: %q %q %q", s.ID(), s.Name(), s.Root())
	}
	if err := s.AddDevice("Galaxy S24", "abc123", time.Now()); err != nil {
		t.Fatal(err)
	}
	s2, _, err := Load(path, "OTHER")
	if err != nil {
		t.Fatal(err)
	}
	if s2.ID() != s.ID() || s2.Name() != "MY-PC" || s2.DeviceCount() != 1 {
		t.Fatal("config not persisted")
	}
	if d, ok := s2.FindDevice("abc123"); !ok || d.DeviceName != "Galaxy S24" {
		t.Fatal("device not found")
	}
	if _, ok, _ := s2.RemoveDevice("abc123"); !ok || s2.DeviceCount() != 0 {
		t.Fatal("remove failed")
	}
	raw, _ := os.ReadFile(path)
	if !strings.Contains(string(raw), `"projectsRoot"`) {
		t.Fatalf("unexpected file: %s", raw)
	}
}

func TestBrokenConfigIsMovedAside(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte("{not json"), 0o600); err != nil {
		t.Fatal(err)
	}
	s, warn, err := Load(path, "PC")
	if err != nil || warn == "" || s.Name() != "PC" {
		t.Fatalf("err=%v warn=%q", err, warn)
	}
	if _, err := os.Stat(path + ".broken"); err != nil {
		t.Fatal("backup missing")
	}
}

func TestResetDevices(t *testing.T) {
	s, _, _ := Load(filepath.Join(t.TempDir(), "c.json"), "PC")
	_ = s.AddDevice("a", "h1", time.Now())
	_ = s.AddDevice("b", "h2", time.Now())
	if err := s.ResetDevices(); err != nil || s.DeviceCount() != 0 {
		t.Fatal("reset failed")
	}
}
