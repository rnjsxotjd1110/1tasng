// Package config stores the bridge identity and paired devices in
// <UserConfigDir>/ember-bridge/config.json.
package config

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Device is one paired phone. Only the SHA-256 of its token is stored.
type Device struct {
	DeviceName string    `json:"deviceName"`
	TokenHash  string    `json:"tokenHash"`
	PairedAt   time.Time `json:"pairedAt"`
}

// Data is the on-disk JSON shape.
type Data struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Devices      []Device `json:"devices"`
	ProjectsRoot string   `json:"projectsRoot"`
}

// Store is a concurrency-safe view of the config file.
type Store struct {
	mu   sync.Mutex
	path string
	data Data
}

// DefaultPath returns <UserConfigDir>/ember-bridge/config.json.
func DefaultPath() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "ember-bridge", "config.json"), nil
}

// DefaultRoot returns ~/EmberProjects.
func DefaultRoot() string {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return "EmberProjects"
	}
	return filepath.Join(home, "EmberProjects")
}

// Load reads the config, creating a new identity if the file does not exist.
// A file that cannot be parsed is moved aside (warning is non-empty) and a
// fresh config is used instead, so a broken file never blocks startup.
func Load(path, defaultName string) (s *Store, warning string, err error) {
	s = &Store{path: path}
	raw, err := os.ReadFile(path)
	switch {
	case errors.Is(err, fs.ErrNotExist):
	case err != nil:
		return nil, "", err
	default:
		if jerr := json.Unmarshal(raw, &s.data); jerr != nil {
			backup := path + ".broken"
			_ = os.Rename(path, backup)
			warning = fmt.Sprintf("설정 파일을 읽지 못해 새로 만들었어요(이전 파일: %s)", backup)
			s.data = Data{}
		}
	}
	changed := false
	if s.data.ID == "" {
		s.data.ID = randomID()
		changed = true
	}
	if s.data.Name == "" {
		s.data.Name = defaultName
		changed = true
	}
	if s.data.ProjectsRoot == "" {
		s.data.ProjectsRoot = DefaultRoot()
		changed = true
	}
	if s.data.Devices == nil {
		s.data.Devices = []Device{}
	}
	if changed {
		if err := s.saveLocked(); err != nil {
			return nil, warning, err
		}
	}
	return s, warning, nil
}

func randomID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		panic("crypto/rand failed: " + err.Error())
	}
	return hex.EncodeToString(b)
}

// Path is where the config lives.
func (s *Store) Path() string { return s.path }

// ID is the random bridge id.
func (s *Store) ID() string { s.mu.Lock(); defer s.mu.Unlock(); return s.data.ID }

// Name is the display name.
func (s *Store) Name() string { s.mu.Lock(); defer s.mu.Unlock(); return s.data.Name }

// Root is the projects root folder.
func (s *Store) Root() string { s.mu.Lock(); defer s.mu.Unlock(); return s.data.ProjectsRoot }

// SetName changes and saves the display name.
func (s *Store) SetName(name string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data.Name = name
	return s.saveLocked()
}

// SetRoot changes and saves the projects root.
func (s *Store) SetRoot(root string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data.ProjectsRoot = root
	return s.saveLocked()
}

// DeviceCount is the number of paired devices.
func (s *Store) DeviceCount() int { s.mu.Lock(); defer s.mu.Unlock(); return len(s.data.Devices) }

// AddDevice stores a newly paired device.
func (s *Store) AddDevice(name, tokenHash string, at time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data.Devices = append(s.data.Devices, Device{DeviceName: name, TokenHash: tokenHash, PairedAt: at.UTC()})
	return s.saveLocked()
}

// FindDevice looks a device up by token hash (constant-time per entry).
func (s *Store) FindDevice(tokenHash string) (Device, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	i := s.indexLocked(tokenHash)
	if i < 0 {
		return Device{}, false
	}
	return s.data.Devices[i], true
}

// RemoveDevice forgets the device with this token hash.
func (s *Store) RemoveDevice(tokenHash string) (Device, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	i := s.indexLocked(tokenHash)
	if i < 0 {
		return Device{}, false, nil
	}
	d := s.data.Devices[i]
	s.data.Devices = append(s.data.Devices[:i], s.data.Devices[i+1:]...)
	return d, true, s.saveLocked()
}

// ResetDevices forgets every paired device.
func (s *Store) ResetDevices() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data.Devices = []Device{}
	return s.saveLocked()
}

func (s *Store) indexLocked(tokenHash string) int {
	found := -1
	for i, d := range s.data.Devices {
		if subtle.ConstantTimeCompare([]byte(d.TokenHash), []byte(tokenHash)) == 1 {
			found = i
		}
	}
	return found
}

// saveLocked writes the file atomically (temp file + rename), mode 0600.
func (s *Store) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	raw, err := json.MarshalIndent(s.data, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(s.path), "config-*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(append(raw, '\n')); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return err
	}
	_ = os.Chmod(tmpName, 0o600)
	if err := os.Rename(tmpName, s.path); err != nil {
		os.Remove(tmpName)
		return err
	}
	return nil
}
