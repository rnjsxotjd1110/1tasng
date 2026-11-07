// Package pairing holds the one-time pairing code, the per-IP rate limiter
// and device token helpers.
package pairing

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"math/big"
	"strings"
	"sync"
	"time"
)

// DefaultCodeTTL is how long a pairing code stays valid.
const DefaultCodeTTL = 10 * time.Minute

// DefaultMaxFailures is how many wrong guesses (from anyone) a single code
// survives before it is replaced.
const DefaultMaxFailures = 20

// CodeDigits is the length of a pairing code (digits only).
const CodeDigits = 8

// codeSpace is 10^CodeDigits.
const codeSpace = 100_000_000

// CodeManager owns the current 8-digit pairing code.
type CodeManager struct {
	mu          sync.Mutex
	code        string
	expires     time.Time
	failures    int
	used        bool // consumed by a successful pair; replaced on next Current
	ttl         time.Duration
	maxFailures int
	now         func() time.Time
	onRotate    func(code string, expires time.Time)
}

// NewCodeManager creates a manager with a fresh code. onRotate (may be nil)
// is called every time the code changes, including this first one.
func NewCodeManager(ttl time.Duration, onRotate func(code string, expires time.Time)) *CodeManager {
	return newCodeManager(ttl, DefaultMaxFailures, time.Now, onRotate)
}

func newCodeManager(ttl time.Duration, maxFailures int, now func() time.Time, onRotate func(string, time.Time)) *CodeManager {
	m := &CodeManager{ttl: ttl, maxFailures: maxFailures, now: now, onRotate: onRotate}
	m.mu.Lock()
	m.rotateLocked()
	code, exp := m.code, m.expires
	m.mu.Unlock()
	m.notify(code, exp)
	return m
}

func (m *CodeManager) notify(code string, exp time.Time) {
	if m.onRotate != nil {
		m.onRotate(code, exp)
	}
}

func (m *CodeManager) rotateLocked() {
	for {
		c := RandomCode()
		if c != m.code {
			m.code = c
			break
		}
	}
	m.expires = m.now().Add(m.ttl)
	m.failures = 0
	m.used = false
}

func (m *CodeManager) staleLocked() bool {
	return m.used || !m.now().Before(m.expires)
}

// Current returns the valid code, replacing it first if it has expired.
func (m *CodeManager) Current() (string, time.Time) {
	m.mu.Lock()
	rotated := false
	if m.staleLocked() {
		m.rotateLocked()
		rotated = true
	}
	code, exp := m.code, m.expires
	m.mu.Unlock()
	if rotated {
		m.notify(code, exp)
	}
	return code, exp
}

// Verify checks a code. A correct code is consumed at once; the next call
// to Current issues (and announces) the replacement, so the caller can log
// the successful pairing first. An expired code is never accepted.
func (m *CodeManager) Verify(input string) bool {
	input = NormalizeCode(input)
	m.mu.Lock()
	ok := false
	rotated := false
	switch {
	case m.staleLocked():
		m.rotateLocked()
		rotated = true
	case len(input) == len(m.code) && subtle.ConstantTimeCompare([]byte(input), []byte(m.code)) == 1:
		ok = true
		m.used = true
	default:
		m.failures++
		if m.failures >= m.maxFailures {
			m.rotateLocked()
			rotated = true
		}
	}
	code, exp := m.code, m.expires
	m.mu.Unlock()
	if rotated {
		m.notify(code, exp)
	}
	return ok
}

// Run replaces the code as soon as it expires, so the console always shows a
// valid one. It returns when ctx is cancelled.
func (m *CodeManager) Run(ctx context.Context) {
	for {
		m.mu.Lock()
		wait := m.expires.Sub(m.now())
		m.mu.Unlock()
		if wait < 0 {
			wait = 0
		}
		t := time.NewTimer(wait + 50*time.Millisecond)
		select {
		case <-ctx.Done():
			t.Stop()
			return
		case <-t.C:
			m.Current()
		}
	}
}

// NormalizeCode drops spaces and dashes people type for readability.
func NormalizeCode(s string) string {
	return strings.Map(func(r rune) rune {
		if r == ' ' || r == '-' {
			return -1
		}
		return r
	}, strings.TrimSpace(s))
}

// RandomCode returns a uniformly random 8-digit code from crypto/rand.
func RandomCode() string {
	n, err := rand.Int(rand.Reader, big.NewInt(codeSpace))
	if err != nil {
		panic("crypto/rand failed: " + err.Error())
	}
	return fmt.Sprintf("%0*d", CodeDigits, n.Int64())
}

// NewToken returns a new device token (32 random bytes, base64url) and its hash.
func NewToken() (token, hash string, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", "", err
	}
	token = base64.RawURLEncoding.EncodeToString(b)
	return token, HashToken(token), nil
}

// HashToken is the SHA-256 (hex) of a token; only this is ever stored.
func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// DefaultMaxKeys caps how many distinct keys a RateLimiter tracks. A flood
// of new source addresses beyond this is treated as limited rather than
// growing memory without bound.
const DefaultMaxKeys = 4096

// RateLimiter allows at most limit events per key in a sliding window.
// Allow only prunes the key it is asked about, plus a full sweep at most
// once per window, so a request never costs O(number of keys).
type RateLimiter struct {
	mu        sync.Mutex
	limit     int
	window    time.Duration
	maxKeys   int
	hits      map[string][]time.Time
	lastSweep time.Time
	now       func() time.Time
}

// NewRateLimiter creates a limiter (e.g. 5 per minute).
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{limit: limit, window: window, maxKeys: DefaultMaxKeys, hits: map[string][]time.Time{}, now: time.Now}
}

// SetClock replaces the clock (tests only).
func (r *RateLimiter) SetClock(now func() time.Time) { r.now = now }

// SetMaxKeys changes the key cap (tests only).
func (r *RateLimiter) SetMaxKeys(n int) { r.maxKeys = n }

// Len reports how many keys are tracked (tests only).
func (r *RateLimiter) Len() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.hits)
}

func pruneTimes(ts []time.Time, cutoff time.Time) []time.Time {
	i := 0
	for i < len(ts) && !ts[i].After(cutoff) {
		i++ // timestamps are appended in order, so stale ones are a prefix
	}
	return ts[i:]
}

func (r *RateLimiter) sweepLocked(now, cutoff time.Time) {
	for k, ts := range r.hits {
		if kept := pruneTimes(ts, cutoff); len(kept) == 0 {
			delete(r.hits, k)
		} else {
			r.hits[k] = kept
		}
	}
	r.lastSweep = now
}

// Allow records an attempt for key and reports whether it is allowed. When
// it is not, retryAfter says how long until the oldest attempt expires.
func (r *RateLimiter) Allow(key string) (ok bool, retryAfter time.Duration) {
	r.mu.Lock()
	defer r.mu.Unlock()
	now := r.now()
	cutoff := now.Add(-r.window)
	if now.Sub(r.lastSweep) >= r.window {
		r.sweepLocked(now, cutoff)
	}
	ts, known := r.hits[key]
	if known {
		ts = pruneTimes(ts, cutoff)
		if len(ts) == 0 {
			delete(r.hits, key)
			known = false
		} else {
			r.hits[key] = ts
		}
	}
	if !known && len(r.hits) >= r.maxKeys {
		return false, r.window
	}
	if len(ts) >= r.limit {
		return false, ts[0].Add(r.window).Sub(now)
	}
	r.hits[key] = append(ts, now)
	return true, 0
}

// Lockout refuses everything for a while once too many failures (from any
// source) happen within a window. It backs the global pairing lockout, which
// the per-IP limiter alone cannot provide against many source addresses.
type Lockout struct {
	mu          sync.Mutex
	maxFailures int
	window      time.Duration
	duration    time.Duration
	failures    []time.Time
	until       time.Time
	now         func() time.Time
}

// NewLockout locks for duration after maxFailures failures within window.
func NewLockout(maxFailures int, window, duration time.Duration) *Lockout {
	return &Lockout{maxFailures: maxFailures, window: window, duration: duration, now: time.Now}
}

// SetClock replaces the clock (tests only).
func (l *Lockout) SetClock(now func() time.Time) { l.now = now }

// Locked reports whether the lockout is active and for how much longer.
func (l *Lockout) Locked() (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if left := l.until.Sub(l.now()); left > 0 {
		return true, left
	}
	return false, 0
}

// Fail records one failure. It returns true when this failure started a
// lockout (so the caller can tell the user once).
func (l *Lockout) Fail() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	if now.Before(l.until) {
		return false
	}
	l.failures = append(pruneTimes(l.failures, now.Add(-l.window)), now)
	if len(l.failures) >= l.maxFailures {
		l.until = now.Add(l.duration)
		l.failures = l.failures[:0]
		return true
	}
	return false
}
