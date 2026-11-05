package discovery

import (
	"strings"
	"testing"
	"unicode/utf8"
)

func TestInstanceName(t *testing.T) {
	cases := map[string]string{
		"DESKTOP-ABC": "DESKTOP-ABC",
		"민수의 PC":      "민수의 PC",
		"my.pc.local": "my-pc-local",
		`a\b`:         "a-b",
		"   ":         "Ember Bridge",
	}
	for in, want := range cases {
		if got := InstanceName(in); got != want {
			t.Errorf("InstanceName(%q) = %q, want %q", in, got, want)
		}
	}
	long := InstanceName(strings.Repeat("가", 40)) // 120 bytes
	if len(long) > 63 || !utf8.ValidString(long) {
		t.Fatalf("bad truncation: %d bytes, valid=%v", len(long), utf8.ValidString(long))
	}
}
