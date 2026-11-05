// Package netinfo lists the LAN addresses a phone could use to reach the PC.
package netinfo

import (
	"net"
	"sort"
	"strings"
)

// Addr is one IPv4 address with the interface it belongs to.
type Addr struct {
	IP    net.IP
	Iface string
}

// LANAddrs returns the IPv4 addresses of interfaces that are up, excluding
// loopback and link-local (169.254.x.x). Private ranges come first, with
// 192.168.x.x (home Wi-Fi) at the top.
func LANAddrs() []Addr {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}
	var out []Addr
	for _, ifc := range ifaces {
		if ifc.Flags&net.FlagUp == 0 || ifc.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := ifc.Addrs()
		if err != nil {
			continue
		}
		for _, a := range addrs {
			ipn, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			ip4 := ipn.IP.To4()
			if ip4 == nil || ip4.IsLinkLocalUnicast() || ip4.IsLoopback() {
				continue
			}
			out = append(out, Addr{IP: ip4, Iface: ifc.Name})
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		ri, rj := rank(out[i]), rank(out[j])
		if ri != rj {
			return ri < rj
		}
		return out[i].IP.String() < out[j].IP.String()
	})
	return out
}

func rank(a Addr) int {
	r := 3
	switch {
	case a.IP[0] == 192 && a.IP[1] == 168:
		r = 0
	case a.IP[0] == 10:
		r = 1
	case a.IP.IsPrivate():
		r = 2
	}
	// Virtual adapters (Hyper-V, WSL, VirtualBox, Docker, VPNs) go last.
	n := strings.ToLower(a.Iface)
	for _, v := range []string{"vethernet", "virtualbox", "vmware", "docker", "br-", "veth", "wsl", "tailscale", "zerotier", "vpn", "utun", "tun", "tap"} {
		if strings.Contains(n, v) {
			r += 10
			break
		}
	}
	return r
}
