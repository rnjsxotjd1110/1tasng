// Ember 브리지: lets the Ember Android app send prompts and design docs to
// this PC over the local network (Claude Code / clipboard / project files).
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"ember-bridge/internal/config"
	"ember-bridge/internal/console"
	"ember-bridge/internal/discovery"
	"ember-bridge/internal/launcher"
	"ember-bridge/internal/netinfo"
	"ember-bridge/internal/pairing"
	"ember-bridge/internal/server"
)

// version is overridable with -ldflags "-X main.version=...".
var version = "1.0.0"

const (
	defaultPort   = 47615
	portFallbacks = 10
)

func main() {
	// The mDNS library logs harmless per-interface notes (e.g. "no IPv6");
	// the bridge prints its own Korean status lines instead.
	log.SetOutput(io.Discard)
	console.Setup("Ember 브리지")
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr)
		fmt.Fprintln(os.Stderr, "오류:", err)
		console.WaitBeforeExit()
		os.Exit(1)
	}
}

// printer writes status lines from a single goroutine so HTTP handlers never
// block on the console (e.g. while text is being selected in a Windows
// console window, writes to it pause).
type printer struct{ ch chan string }

func newPrinter() *printer {
	p := &printer{ch: make(chan string, 256)}
	go func() {
		for line := range p.ch {
			fmt.Println(line)
		}
	}()
	return p
}

func (p *printer) Printf(format string, args ...any) {
	select {
	case p.ch <- fmt.Sprintf(format, args...):
	default: // console is stuck; drop the line rather than block a request
	}
}

func (p *printer) flush() {
	for i := 0; i < 50 && len(p.ch) > 0; i++ {
		time.Sleep(10 * time.Millisecond)
	}
}

func run() error {
	var (
		name          = flag.String("name", "", "브리지 이름(기본: PC 이름). 지정하면 설정에 저장돼요")
		port          = flag.Int("port", defaultPort, "HTTP 포트(사용 중이면 다음 10개 포트를 차례로 시도)")
		root          = flag.String("root", "", "프로젝트 폴더 위치(기본: ~/EmberProjects). 지정하면 설정에 저장돼요")
		reset         = flag.Bool("reset", false, "연결된 기기를 모두 잊기")
		printCodeFile = flag.String("print-code-file", "", "(개발용) 현재 페어링 코드를 이 파일에 써 두기")
		showVersion   = flag.Bool("version", false, "버전 출력")
	)
	flag.Parse()
	if *showVersion {
		fmt.Println("ember-bridge", version)
		return nil
	}
	if *port < 1 || *port > 65535-portFallbacks {
		return fmt.Errorf("포트 번호가 올바르지 않아요: %d", *port)
	}

	hostname, _ := os.Hostname()
	if hostname == "" {
		hostname = "Ember PC"
	}
	cfgPath, err := config.DefaultPath()
	if err != nil {
		return fmt.Errorf("설정 폴더를 찾지 못했어요: %w", err)
	}
	cfg, warning, err := config.Load(cfgPath, hostname)
	if err != nil {
		return fmt.Errorf("설정 파일을 열지 못했어요(%s): %w", server.Printable(cfgPath, 300), err)
	}
	if warning != "" {
		fmt.Println("주의:", server.Printable(warning, 400))
	}
	if *name != "" {
		n := server.Printable(*name, 64)
		if n == "" {
			return errors.New("--name 이 비어 있어요")
		}
		if err := cfg.SetName(n); err != nil {
			return err
		}
	}
	if *root != "" {
		r, err := expandPath(*root)
		if err != nil {
			return fmt.Errorf("--root 경로가 올바르지 않아요: %w", err)
		}
		if err := cfg.SetRoot(r); err != nil {
			return err
		}
	}
	if *reset {
		if err := cfg.ResetDevices(); err != nil {
			return err
		}
		fmt.Println("연결된 기기를 모두 잊었어요. 앱에서 다시 연결해 주세요.")
	}

	ln, actualPort, err := listen(*port, cfg.ID())
	if err != nil {
		return err
	}

	out := newPrinter()
	var bannerDone atomic.Bool
	codes := pairing.NewCodeManager(pairing.DefaultCodeTTL, func(code string, exp time.Time) {
		if *printCodeFile != "" {
			_ = os.WriteFile(*printCodeFile, []byte(code+"\n"), 0o600)
		}
		if bannerDone.Load() {
			out.Printf("[%s] 새 페어링 코드: %s  (%s까지 유효)", time.Now().Format("15:04:05"), code, exp.Format("15:04"))
		}
	})

	srv := server.New(cfg, codes, launcher.New(), version, out.Printf)
	httpSrv := &http.Server{
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      server.HTTPWriteTimeout, // longer than the slowest /ember/send
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	serveErr := make(chan error, 1)
	go func() { serveErr <- httpSrv.Serve(ln) }()

	addrs := netinfo.LANAddrs()
	var ips []string
	for _, a := range addrs {
		ips = append(ips, a.IP.String())
	}
	var mdnsNote string
	var adv *discovery.Advertiser
	if len(ips) == 0 {
		mdnsNote = "네트워크 주소를 찾지 못해 자동 검색을 켜지 못했어요."
	} else if adv, err = discovery.Advertise(cfg.Name(), cfg.ID(), actualPort, ips); err != nil {
		mdnsNote = "자동 검색(mDNS)을 켜지 못했어요: " + err.Error()
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go codes.Run(ctx)

	printBanner(cfg, addrs, actualPort, *port, codes, mdnsNote)
	bannerDone.Store(true)

	select {
	case <-ctx.Done():
	case err := <-serveErr:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			adv.Shutdown()
			return fmt.Errorf("서버가 멈췄어요: %w", err)
		}
	}
	out.Printf("브리지를 끄는 중이에요…")
	out.flush()
	adv.Shutdown()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutdownCtx)
	if *printCodeFile != "" {
		_ = os.Remove(*printCodeFile)
	}
	return nil
}

func printBanner(cfg *config.Store, addrs []netinfo.Addr, port, wantedPort int, codes *pairing.CodeManager, mdnsNote string) {
	code, exp := codes.Current()
	line := strings.Repeat("=", 56)
	fmt.Println(line)
	fmt.Printf("  Ember 브리지 v%s\n", version)
	fmt.Println(line)
	fmt.Printf("  브리지 이름   %s\n", server.Printable(cfg.Name(), 64))
	if len(addrs) == 0 {
		fmt.Printf("  주소          (네트워크 연결을 찾지 못했어요) 포트 %d\n", port)
	}
	for i, a := range addrs {
		label := "  주소          "
		if i > 0 {
			label = "                "
		}
		fmt.Printf("%s%s:%d   (%s)\n", label, a.IP, port, server.Printable(a.Iface, 40))
	}
	if port != wantedPort {
		fmt.Printf("  (포트 %d 이 사용 중이라 %d 을 쓰고 있어요)\n", wantedPort, port)
	}
	fmt.Printf("  프로젝트 폴더 %s\n", server.Printable(cfg.Root(), 300))
	fmt.Printf("  연결된 기기   %d대\n", cfg.DeviceCount())
	fmt.Println()
	fmt.Printf("  페어링 코드   %s   (%s까지 유효)\n", code, exp.Format("15:04"))
	fmt.Println("  Ember 앱 → 대장간 → 작업대 연결 에서 이 코드를 입력하세요.")
	fmt.Println("  코드는 10분마다, 그리고 연결에 한 번 성공하면 새로 바뀌어요.")
	fmt.Println()
	if mdnsNote != "" {
		fmt.Println("  참고: " + mdnsNote)
		fmt.Println("  앱에서 위 주소(예: 192.168.0.12:47615)를 직접 입력하면 연결할 수 있어요.")
		fmt.Println()
	}
	fmt.Println("  이 창을 닫으면 브리지가 꺼져요.")
	fmt.Println(line)
}

// listen binds the first free port in [port, port+portFallbacks]. If a busy
// port turns out to be this same bridge, it reports that instead.
func listen(port int, ownID string) (net.Listener, int, error) {
	var lastErr error
	for p := port; p <= port+portFallbacks; p++ {
		ln, err := net.Listen("tcp", ":"+strconv.Itoa(p))
		if err == nil {
			return ln, p, nil
		}
		lastErr = err
		if isSameBridge(p, ownID) {
			return nil, 0, fmt.Errorf("Ember 브리지가 이미 실행 중이에요(포트 %d). 열려 있는 다른 창을 확인해 주세요", p)
		}
	}
	return nil, 0, fmt.Errorf("포트 %d~%d 를 모두 쓸 수 없어요: %w", port, port+portFallbacks, lastErr)
}

func isSameBridge(port int, ownID string) bool {
	c := http.Client{Timeout: time.Second}
	resp, err := c.Get("http://127.0.0.1:" + strconv.Itoa(port) + "/ember/info")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	var info struct {
		ID string `json:"id"`
	}
	if json.NewDecoder(http.MaxBytesReader(nil, resp.Body, 4096)).Decode(&info) != nil {
		return false
	}
	return info.ID == ownID
}

func expandPath(p string) (string, error) {
	if p == "~" || strings.HasPrefix(p, "~/") || strings.HasPrefix(p, `~\`) {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		p = filepath.Join(home, p[1:])
	}
	return filepath.Abs(p)
}
