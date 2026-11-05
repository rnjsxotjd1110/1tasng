// Package discovery advertises the bridge on the LAN with mDNS/DNS-SD.
package discovery

import (
	"strings"
	"unicode"

	"github.com/libp2p/zeroconf/v2"
)

// ServiceType is what the Ember app browses for.
const ServiceType = "_ember._tcp"

// Domain is the mDNS domain.
const Domain = "local."

// Advertiser is a running mDNS registration.
type Advertiser struct{ srv *zeroconf.Server }

// Advertise registers instance name = display name with TXT id, v and name.
// ips are the addresses announced for the bridge's host record.
func Advertise(displayName, id string, port int, ips []string) (*Advertiser, error) {
	instance := InstanceName(displayName)
	text := []string{"id=" + id, "v=1", "name=" + truncateBytes(displayName, 200)}
	// A fixed ASCII host name avoids problems with non-ASCII PC names.
	host := "ember-bridge-" + id[:min(8, len(id))]
	srv, err := zeroconf.RegisterProxy(instance, ServiceType, Domain, port, host, ips, text, nil)
	if err != nil {
		return nil, err
	}
	return &Advertiser{srv: srv}, nil
}

// Shutdown sends goodbye packets and stops answering.
func (a *Advertiser) Shutdown() {
	if a != nil && a.srv != nil {
		a.srv.Shutdown()
	}
}

// InstanceName makes the display name safe as one DNS label: dots and
// backslashes would be read as label separators/escapes, and a label is at
// most 63 bytes.
func InstanceName(name string) string {
	name = strings.Map(func(r rune) rune {
		if r == '.' || r == '\\' || unicode.IsControl(r) {
			return '-'
		}
		return r
	}, name)
	name = strings.TrimSpace(truncateBytes(name, 63))
	if name == "" {
		return "Ember Bridge"
	}
	return name
}

func truncateBytes(s string, max int) string {
	if len(s) <= max {
		return s
	}
	cut := 0 // start of the last rune that still fits
	for i := range s {
		if i > max {
			break
		}
		cut = i
	}
	return s[:cut]
}
