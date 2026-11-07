package pairing

import (
	"encoding/base64"
	"regexp"
	"testing"
	"time"
)

type clock struct{ t time.Time }

func (c *clock) now() time.Time          { return c.t }
func (c *clock) advance(d time.Duration) { c.t = c.t.Add(d) }

func TestRandomCodeFormat(t *testing.T) {
	re := regexp.MustCompile(`^\d{8}$`)
	seen := map[string]bool{}
	for i := 0; i < 200; i++ {
		c := RandomCode()
		if !re.MatchString(c) {
			t.Fatalf("bad code %q", c)
		}
		seen[c] = true
	}
	if len(seen) < 190 {
		t.Fatalf("codes look non-random: %d unique of 200", len(seen))
	}
}

func TestCodeIsOneTimeUse(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	var rotations []string
	m := newCodeManager(10*time.Minute, 20, c.now, func(code string, _ time.Time) { rotations = append(rotations, code) })
	code, _ := m.Current()
	if !m.Verify(code) {
		t.Fatal("correct code rejected")
	}
	if m.Verify(code) {
		t.Fatal("code accepted twice")
	}
	next, _ := m.Current()
	if next == code {
		t.Fatal("code did not rotate after a successful pair")
	}
	if len(rotations) != 2 {
		t.Fatalf("rotations = %v", rotations)
	}
}

func TestCodeAcceptsSpacesAndDashes(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	m := newCodeManager(10*time.Minute, 20, c.now, nil)
	code, _ := m.Current()
	if !m.Verify(" " + code[:3] + "-" + code[3:] + " ") {
		t.Fatal("formatted code rejected")
	}
}

func TestWrongCode(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	m := newCodeManager(10*time.Minute, 20, c.now, nil)
	code, _ := m.Current()
	wrong := "00000000"
	if code == wrong {
		wrong = "11111111"
	}
	for _, in := range []string{wrong, "", "1234567", "123456789", "abcdefgh", code[:6], code + "0"} {
		if m.Verify(in) {
			t.Fatalf("accepted %q", in)
		}
	}
	if cur, _ := m.Current(); cur != code {
		t.Fatal("a few wrong guesses should not rotate the code")
	}
}

func TestCodeRotatesAfterTooManyFailures(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	m := newCodeManager(10*time.Minute, 3, c.now, nil)
	code, _ := m.Current()
	for i := 0; i < 3; i++ {
		m.Verify("xxxxxxxx")
	}
	if cur, _ := m.Current(); cur == code {
		t.Fatal("code should rotate after max failures")
	}
	if m.Verify(code) {
		t.Fatal("old code accepted after rotation")
	}
}

func TestCodeExpires(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	m := newCodeManager(10*time.Minute, 20, c.now, nil)
	code, exp := m.Current()
	if want := c.t.Add(10 * time.Minute); !exp.Equal(want) {
		t.Fatalf("expires %v, want %v", exp, want)
	}
	c.advance(10*time.Minute + time.Second)
	if m.Verify(code) {
		t.Fatal("expired code accepted")
	}
	if cur, _ := m.Current(); cur == code {
		t.Fatal("expired code not rotated")
	}
}

func TestRateLimiter(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	r := NewRateLimiter(5, time.Minute)
	r.SetClock(c.now)
	for i := 0; i < 5; i++ {
		if ok, _ := r.Allow("10.0.0.2"); !ok {
			t.Fatalf("attempt %d blocked", i+1)
		}
		c.advance(time.Second)
	}
	ok, retry := r.Allow("10.0.0.2")
	if ok || retry <= 0 || retry > time.Minute {
		t.Fatalf("6th attempt: ok=%v retry=%v", ok, retry)
	}
	if ok, _ := r.Allow("10.0.0.3"); !ok {
		t.Fatal("other IP blocked")
	}
	c.advance(time.Minute)
	if ok, _ := r.Allow("10.0.0.2"); !ok {
		t.Fatal("not allowed again after the window")
	}
}

func TestRateLimiterPrunesAndCaps(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	r := NewRateLimiter(5, time.Minute)
	r.SetClock(c.now)
	r.SetMaxKeys(3)
	for _, k := range []string{"a", "b", "c"} {
		if ok, _ := r.Allow(k); !ok {
			t.Fatalf("%s blocked", k)
		}
	}
	// The map is full: a new key is treated as limited, known keys still work.
	if ok, retry := r.Allow("d"); ok || retry <= 0 {
		t.Fatalf("new key over cap: ok=%v retry=%v", ok, retry)
	}
	if ok, _ := r.Allow("a"); !ok {
		t.Fatal("known key blocked by the cap")
	}
	if r.Len() != 3 {
		t.Fatalf("len = %d", r.Len())
	}
	// After the window the periodic sweep frees the stale keys.
	c.advance(time.Minute + time.Second)
	if ok, _ := r.Allow("d"); !ok {
		t.Fatal("new key blocked after stale keys expired")
	}
	if r.Len() != 1 {
		t.Fatalf("stale keys not pruned: len = %d", r.Len())
	}
}

func TestLockout(t *testing.T) {
	c := &clock{t: time.Unix(1_700_000_000, 0)}
	l := NewLockout(10, 10*time.Minute, 5*time.Minute)
	l.SetClock(c.now)
	// Failures older than the window do not count.
	for i := 0; i < 9; i++ {
		if l.Fail() {
			t.Fatal("locked too early")
		}
	}
	c.advance(10*time.Minute + time.Second)
	for i := 0; i < 9; i++ {
		if l.Fail() {
			t.Fatalf("locked at %d after window reset", i+1)
		}
		c.advance(time.Second)
	}
	if locked, _ := l.Locked(); locked {
		t.Fatal("locked before the 10th failure")
	}
	if !l.Fail() {
		t.Fatal("10th failure should start the lockout")
	}
	locked, left := l.Locked()
	if !locked || left != 5*time.Minute {
		t.Fatalf("locked=%v left=%v", locked, left)
	}
	if l.Fail() {
		t.Fatal("failures while locked must not re-announce")
	}
	c.advance(5 * time.Minute)
	if locked, _ := l.Locked(); locked {
		t.Fatal("still locked after the lockout")
	}
	if l.Fail() {
		t.Fatal("counter should restart after a lockout")
	}
}

func TestTokens(t *testing.T) {
	tok, hash, err := NewToken()
	if err != nil {
		t.Fatal(err)
	}
	raw, err := base64.RawURLEncoding.DecodeString(tok)
	if err != nil || len(raw) != 32 {
		t.Fatalf("token %q not 32-byte base64url: %v", tok, err)
	}
	if HashToken(tok) != hash || len(hash) != 64 {
		t.Fatalf("hash mismatch")
	}
	tok2, _, _ := NewToken()
	if tok2 == tok {
		t.Fatal("tokens repeat")
	}
}
