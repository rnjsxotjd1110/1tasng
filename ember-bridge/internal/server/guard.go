package server

import (
	"mime"
	"net"
	"net/http"
	"net/netip"
	"strings"
)

// guard runs before every handler. It turns away requests that cannot come
// from the Ember app on the same LAN:
//
//   - the peer address is not loopback, private (RFC 1918 / IPv6 ULA) or
//     link-local, i.e. the bridge was reached from the internet;
//   - the request has an Origin header, i.e. it was made by a web page in a
//     browser (CSRF); the app never sends one;
//   - the Host header is a DNS name other than localhost or *.local, the
//     sign of a DNS-rebinding attack from a web page.
func (s *Server) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		addr, ok := peerAddr(r.RemoteAddr)
		if !ok || !allowedPeer(addr) {
			writeError(w, http.StatusForbidden, "forbidden",
				"같은 네트워크(LAN)에 있는 기기에서만 연결할 수 있어요.")
			return
		}
		if _, has := r.Header["Origin"]; has {
			writeError(w, http.StatusForbidden, "forbidden",
				"웹 브라우저에서 보낸 요청은 받지 않아요. Ember 앱에서 연결해 주세요.")
			return
		}
		if !allowedHost(r.Host) {
			writeError(w, http.StatusMisdirectedRequest, "bad_host",
				"주소가 올바르지 않아요. PC 창에 보이는 IP 주소(예: 192.168.0.12:47615)로 연결해 주세요.")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// peerAddr parses r.RemoteAddr ("ip:port", "[ipv6%zone]:port" or a bare IP)
// into an address without zone, IPv4-mapped IPv6 turned into plain IPv4.
func peerAddr(remote string) (netip.Addr, bool) {
	var a netip.Addr
	if ap, err := netip.ParseAddrPort(remote); err == nil {
		a = ap.Addr()
	} else if host, _, err := net.SplitHostPort(remote); err == nil {
		if a, err = netip.ParseAddr(host); err != nil {
			return netip.Addr{}, false
		}
	} else if a, err = netip.ParseAddr(remote); err != nil {
		return netip.Addr{}, false
	}
	return a.WithZone("").Unmap(), true
}

// allowedPeer: loopback, RFC 1918 IPv4, IPv4 link-local (169.254/16), IPv6
// link-local (fe80::/10) or IPv6 unique local (fc00::/7).
func allowedPeer(a netip.Addr) bool {
	return a.IsValid() && (a.IsLoopback() || a.IsPrivate() || a.IsLinkLocalUnicast())
}

// rateKey is the per-source key for the pairing limiter: the IPv4 address,
// or the /64 prefix for IPv6 (one device can use many addresses in its /64).
func rateKey(remote string) string {
	a, ok := peerAddr(remote)
	if !ok {
		return remote
	}
	if a.Is4() {
		return a.String()
	}
	return netip.PrefixFrom(a, 64).Masked().String()
}

// allowedHost accepts a Host header whose name part is an IP literal,
// "localhost" or a name ending in ".local" (mDNS).
func allowedHost(hostport string) bool {
	host := hostport
	if h, _, err := net.SplitHostPort(hostport); err == nil {
		host = h
	} else if strings.HasPrefix(host, "[") && strings.HasSuffix(host, "]") {
		host = host[1 : len(host)-1]
	}
	host = strings.TrimSuffix(host, ".")
	if host == "" {
		return false
	}
	if _, err := netip.ParseAddr(host); err == nil {
		return true
	}
	lower := strings.ToLower(host)
	return lower == "localhost" || (strings.HasSuffix(lower, ".local") && len(lower) > len(".local"))
}

// isJSON reports whether a Content-Type header names application/json.
func isJSON(contentType string) bool {
	mt, _, err := mime.ParseMediaType(contentType)
	return err == nil && mt == "application/json"
}
