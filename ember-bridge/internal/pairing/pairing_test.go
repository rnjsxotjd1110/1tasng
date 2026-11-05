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
	re := regexp.MustCompile(`^\d{6}$`)
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
	wrong := "000000"
	if code == wrong {
		wrong = "111111"
	}
	for _, in := range []string{wrong, "", "12345", "1234567", "abcdef", code + "0"} {
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
		m.Verify("xxxxxx")
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
