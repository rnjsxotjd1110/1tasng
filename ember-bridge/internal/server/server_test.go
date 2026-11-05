package server

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"ember-bridge/internal/config"
	"ember-bridge/internal/pairing"
)

// fakeExec records what the server asked the OS to do.
type fakeExec struct {
	mu          sync.Mutex
	claudePath  string
	claudeFound bool
	launchErr   error
	clipErr     error
	clipboard   []string
	launched    []string
	opened      []string
}

func (f *fakeExec) FindClaude() (string, bool) { return f.claudePath, f.claudeFound }
func (f *fakeExec) CopyToClipboard(text string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.clipErr != nil {
		return f.clipErr
	}
	f.clipboard = append(f.clipboard, text)
	return nil
}
func (f *fakeExec) LaunchClaude(folder, claudePath string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.launchErr != nil {
		return f.launchErr
	}
	f.launched = append(f.launched, folder+"|"+claudePath)
	return nil
}
func (f *fakeExec) OpenFolder(folder string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.opened = append(f.opened, folder)
	return nil
}

type env struct {
	t     *testing.T
	srv   *Server
	exec  *fakeExec
	codes *pairing.CodeManager
	root  string
	logs  *bytes.Buffer
}

func newEnv(t *testing.T) *env {
	t.Helper()
	dir := t.TempDir()
	cfg, _, err := config.Load(filepath.Join(dir, "config", "config.json"), "TEST-PC")
	if err != nil {
		t.Fatal(err)
	}
	root := filepath.Join(dir, "EmberProjects")
	if err := cfg.SetRoot(root); err != nil {
		t.Fatal(err)
	}
	fx := &fakeExec{claudePath: "/usr/bin/claude", claudeFound: true}
	codes := pairing.NewCodeManager(10*time.Minute, nil)
	logs := &bytes.Buffer{}
	var mu sync.Mutex
	srv := New(cfg, codes, fx, "test", func(f string, a ...any) {
		mu.Lock()
		defer mu.Unlock()
		logs.WriteString(strings.TrimSpace(fmt.Sprintf(f, a...)) + "\n")
	})
	return &env{t: t, srv: srv, exec: fx, codes: codes, root: root, logs: logs}
}

func (e *env) do(method, path, token string, body any, remote string) (*httptest.ResponseRecorder, map[string]any) {
	e.t.Helper()
	var rdr *bytes.Reader
	switch b := body.(type) {
	case nil:
		rdr = bytes.NewReader(nil)
	case string:
		rdr = bytes.NewReader([]byte(b))
	case []byte:
		rdr = bytes.NewReader(b)
	default:
		raw, _ := json.Marshal(b)
		rdr = bytes.NewReader(raw)
	}
	req := httptest.NewRequest(method, path, rdr)
	if remote != "" {
		req.RemoteAddr = remote
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	e.srv.Handler().ServeHTTP(rec, req)
	var out map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		e.t.Fatalf("%s %s: response is not JSON: %q", method, path, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		e.t.Fatalf("content-type %q", ct)
	}
	return rec, out
}

func (e *env) pair() string {
	e.t.Helper()
	code, _ := e.codes.Current()
	rec, out := e.do("POST", "/ember/pair", "", map[string]string{"code": code, "deviceName": "Galaxy S24"}, "10.0.0.5:5555")
	if rec.Code != 200 {
		e.t.Fatalf("pair failed: %d %v", rec.Code, out)
	}
	return out["token"].(string)
}

func TestInfo(t *testing.T) {
	e := newEnv(t)
	rec, out := e.do("GET", "/ember/info", "", nil, "")
	if rec.Code != 200 || out["name"] != "TEST-PC" || out["pairingRequired"] != true || out["id"] == "" || out["version"] != "test" || out["os"] == "" {
		t.Fatalf("info = %d %v", rec.Code, out)
	}
	rec, out = e.do("POST", "/ember/info", "", nil, "")
	if rec.Code != 405 || out["error"] != "method_not_allowed" {
		t.Fatalf("POST info = %d %v", rec.Code, out)
	}
	rec, out = e.do("GET", "/nope", "", nil, "")
	if rec.Code != 404 || out["error"] != "not_found" {
		t.Fatalf("404 = %d %v", rec.Code, out)
	}
}

func TestPairSuccessAndOneTimeCode(t *testing.T) {
	e := newEnv(t)
	code, _ := e.codes.Current()
	rec, out := e.do("POST", "/ember/pair", "", map[string]string{"code": code, "deviceName": "Galaxy S24"}, "10.0.0.5:1")
	if rec.Code != 200 {
		t.Fatalf("pair = %d %v", rec.Code, out)
	}
	tok, _ := out["token"].(string)
	if len(tok) != 43 || out["name"] != "TEST-PC" || out["id"] != e.srv.Config.ID() {
		t.Fatalf("pair response %v", out)
	}
	if !strings.Contains(e.logs.String(), "새 기기 연결: Galaxy S24") {
		t.Fatalf("log missing: %s", e.logs.String())
	}
	if strings.Contains(e.logs.String(), tok) {
		t.Fatal("token leaked into the log")
	}
	// Only the hash is stored on disk.
	raw, _ := os.ReadFile(e.srv.Config.Path())
	if strings.Contains(string(raw), tok) || !strings.Contains(string(raw), pairing.HashToken(tok)) {
		t.Fatal("config must store the token hash only")
	}
	// Same code again → rejected (one-time use).
	rec, out = e.do("POST", "/ember/pair", "", map[string]string{"code": code, "deviceName": "Other"}, "10.0.0.6:1")
	if rec.Code != 403 || out["error"] != "bad_code" {
		t.Fatalf("reuse = %d %v", rec.Code, out)
	}
}

func TestPairWrongCode(t *testing.T) {
	e := newEnv(t)
	code, _ := e.codes.Current()
	wrong := "000000"
	if wrong == code {
		wrong = "999999"
	}
	rec, out := e.do("POST", "/ember/pair", "", map[string]string{"code": wrong, "deviceName": "x"}, "10.0.0.7:1")
	if rec.Code != 403 || out["error"] != "bad_code" || out["message"] == "" {
		t.Fatalf("wrong code = %d %v", rec.Code, out)
	}
	if e.srv.Config.DeviceCount() != 0 {
		t.Fatal("device added on wrong code")
	}
	rec, out = e.do("POST", "/ember/pair", "", "{broken", "10.0.0.8:1")
	if rec.Code != 400 || out["error"] != "bad_json" {
		t.Fatalf("bad json = %d %v", rec.Code, out)
	}
}

func TestPairRateLimit(t *testing.T) {
	e := newEnv(t)
	for i := 0; i < PairAttemptsPerMinute; i++ {
		rec, _ := e.do("POST", "/ember/pair", "", map[string]string{"code": "abcdef"}, "10.0.0.9:1000")
		if rec.Code != 403 {
			t.Fatalf("attempt %d = %d", i+1, rec.Code)
		}
	}
	// Even the right code is refused while limited.
	code, _ := e.codes.Current()
	rec, out := e.do("POST", "/ember/pair", "", map[string]string{"code": code}, "10.0.0.9:2000")
	if rec.Code != 429 || out["error"] != "rate_limited" || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("limited = %d %v", rec.Code, out)
	}
	// Another IP is unaffected.
	rec, _ = e.do("POST", "/ember/pair", "", map[string]string{"code": code, "deviceName": "ok"}, "10.0.0.10:1")
	if rec.Code != 200 {
		t.Fatalf("other ip = %d", rec.Code)
	}
}

func TestSendRequiresToken(t *testing.T) {
	e := newEnv(t)
	body := map[string]any{"title": "t", "mode": "file", "prompt": "p"}
	for _, tok := range []string{"", "not-a-real-token"} {
		rec, out := e.do("POST", "/ember/send", tok, body, "")
		if rec.Code != 401 || out["error"] != "unauthorized" {
			t.Fatalf("token %q = %d %v", tok, rec.Code, out)
		}
	}
	for _, p := range []string{"/ember/ping", "/ember/unpair"} {
		m := "POST"
		if p == "/ember/ping" {
			m = "GET"
		}
		if rec, _ := e.do(m, p, "bogus", nil, ""); rec.Code != 401 {
			t.Fatalf("%s = %d", p, rec.Code)
		}
	}
	if _, err := os.Stat(e.root); !os.IsNotExist(err) {
		t.Fatal("something was written without auth")
	}
}

func TestPingAndUnpair(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	rec, out := e.do("GET", "/ember/ping", tok, nil, "")
	if rec.Code != 200 || out["ok"] != true {
		t.Fatalf("ping = %d %v", rec.Code, out)
	}
	rec, _ = e.do("POST", "/ember/unpair", tok, nil, "")
	if rec.Code != 200 || e.srv.Config.DeviceCount() != 0 {
		t.Fatalf("unpair = %d", rec.Code)
	}
	rec, _ = e.do("GET", "/ember/ping", tok, nil, "")
	if rec.Code != 401 {
		t.Fatalf("ping after unpair = %d", rec.Code)
	}
}

func sampleFiles() []map[string]string {
	return []map[string]string{
		{"path": "CLAUDE.md", "content": "# 규칙"},
		{"path": "docs/DESIGN.md", "content": "# 설계"},
		{"path": "docs/WORLD.md", "content": "# 세계"},
	}
}

func TestSendFileMode(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{
		"title": "막차 정류장 등불", "mode": "file", "prompt": "게임을 만들어 줘", "files": sampleFiles(),
	}, "")
	if rec.Code != 200 || out["ok"] != true {
		t.Fatalf("send = %d %v", rec.Code, out)
	}
	want := filepath.Join(e.root, "막차-정류장-등불")
	if out["folder"] != want || out["mode"] != "file" || out["claudeFound"] != true {
		t.Fatalf("resp %v", out)
	}
	if out["message"] != "프로젝트 폴더에 파일 3개를 저장했어요" {
		t.Fatalf("message %q", out["message"])
	}
	if saved := out["saved"].([]any); len(saved) != 3 || saved[1] != "docs/DESIGN.md" {
		t.Fatalf("saved %v", saved)
	}
	for rel, content := range map[string]string{"CLAUDE.md": "# 규칙", "docs/WORLD.md": "# 세계", ".ember/prompt.md": "게임을 만들어 줘"} {
		b, err := os.ReadFile(filepath.Join(want, filepath.FromSlash(rel)))
		if err != nil || string(b) != content {
			t.Fatalf("%s = %q, %v", rel, b, err)
		}
	}
	if len(e.exec.clipboard)+len(e.exec.launched)+len(e.exec.opened) != 0 {
		t.Fatal("file mode must not launch anything")
	}
	if strings.Contains(e.logs.String(), "게임을 만들어 줘") {
		t.Fatal("prompt body leaked into the log")
	}
	if !strings.Contains(e.logs.String(), "막차 정류장 등불") || !strings.Contains(e.logs.String(), "파일 저장") {
		t.Fatalf("log should name title and mode: %s", e.logs.String())
	}
}

func TestSendCustomFolder(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{
		"title": "무시됨", "mode": "file", "prompt": "p", "folder": "my-game",
	}, "")
	if rec.Code != 200 || out["folder"] != filepath.Join(e.root, "my-game") {
		t.Fatalf("send = %d %v", rec.Code, out)
	}
	for _, bad := range []string{"../escape", "a/b", `..\x`, "C:", "/tmp"} {
		rec, out = e.do("POST", "/ember/send", tok, map[string]any{"title": "t", "mode": "file", "prompt": "p", "folder": bad}, "")
		if rec.Code != 400 || out["error"] != "bad_folder" {
			t.Fatalf("folder %q = %d %v", bad, rec.Code, out)
		}
	}
}

func TestSendRejectsBadPaths(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	bad := []string{
		"../evil.md", "../../evil.md", "docs/../../evil.md", `..\evil.md`, `docs\..\..\evil.md`,
		"/etc/evil.md", `C:\Windows\evil.md`, "C:/evil.md", "D:evil.md", `\\server\share\evil.md`,
		"evil\x00.md", "", ".git/hooks/post-checkout",
	}
	for _, p := range bad {
		files := []map[string]string{{"path": "good.md", "content": "ok"}, {"path": p, "content": "pwned"}}
		for _, mode := range []string{"file", "code", "clipboard"} {
			rec, out := e.do("POST", "/ember/send", tok, map[string]any{"title": "t", "mode": mode, "prompt": "p", "files": files}, "")
			if rec.Code != 400 || out["error"] != "bad_path" {
				t.Fatalf("path %q mode %s = %d %v", p, mode, rec.Code, out)
			}
		}
	}
	// The whole request was rejected: nothing at all was written.
	if _, err := os.Stat(e.root); !os.IsNotExist(err) {
		entries, _ := os.ReadDir(e.root)
		t.Fatalf("files were written: %v", entries)
	}
	if len(e.exec.clipboard)+len(e.exec.launched) != 0 {
		t.Fatal("nothing should be launched for a rejected request")
	}
}

func TestSendClipboardMode(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{"title": "t", "mode": "clipboard", "prompt": "한글 프롬프트 \"따옴표\""}, "")
	if rec.Code != 200 || out["folder"] != "" || len(out["saved"].([]any)) != 0 {
		t.Fatalf("clipboard = %d %v", rec.Code, out)
	}
	if len(e.exec.clipboard) != 1 || e.exec.clipboard[0] != "한글 프롬프트 \"따옴표\"" {
		t.Fatalf("clipboard got %v", e.exec.clipboard)
	}
	if _, err := os.Stat(e.root); !os.IsNotExist(err) {
		t.Fatal("clipboard mode without files must not create a folder")
	}
	// With files: also saved.
	rec, out = e.do("POST", "/ember/send", tok, map[string]any{"title": "클립 테스트", "mode": "clipboard", "prompt": "p", "files": sampleFiles()}, "")
	if rec.Code != 200 || out["folder"] != filepath.Join(e.root, "클립-테스트") || len(out["saved"].([]any)) != 3 {
		t.Fatalf("clipboard+files = %d %v", rec.Code, out)
	}
	// Clipboard failure is reported.
	e.exec.clipErr = errors.New("no clipboard")
	rec, out = e.do("POST", "/ember/send", tok, map[string]any{"title": "t", "mode": "clipboard", "prompt": "p"}, "")
	if rec.Code != 500 || out["error"] != "clipboard_failed" {
		t.Fatalf("clip fail = %d %v", rec.Code, out)
	}
}

func TestSendCodeModeWithClaude(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{"title": "코드 모드", "mode": "code", "prompt": "만들어 줘", "files": sampleFiles()}, "")
	if rec.Code != 200 || out["claudeFound"] != true {
		t.Fatalf("code = %d %v", rec.Code, out)
	}
	dir := filepath.Join(e.root, "코드-모드")
	if len(e.exec.launched) != 1 || e.exec.launched[0] != dir+"|/usr/bin/claude" {
		t.Fatalf("launched %v", e.exec.launched)
	}
	if len(e.exec.clipboard) != 0 || len(e.exec.opened) != 0 {
		t.Fatal("no fallback expected")
	}
	if b, err := os.ReadFile(filepath.Join(dir, ".ember", "prompt.md")); err != nil || string(b) != "만들어 줘" {
		t.Fatalf("prompt.md = %q %v", b, err)
	}
	if !strings.Contains(out["message"].(string), "Claude Code") {
		t.Fatalf("message %q", out["message"])
	}
}

func TestSendCodeModeWithoutClaude(t *testing.T) {
	e := newEnv(t)
	e.exec.claudeFound = false
	e.exec.claudePath = ""
	tok := e.pair()
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{"title": "없음", "mode": "code", "prompt": "프롬프트"}, "")
	if rec.Code != 200 || out["ok"] != true || out["claudeFound"] != false {
		t.Fatalf("code = %d %v", rec.Code, out)
	}
	dir := filepath.Join(e.root, "없음")
	if len(e.exec.launched) != 0 {
		t.Fatal("must not launch without claude")
	}
	if len(e.exec.clipboard) != 1 || e.exec.clipboard[0] != "프롬프트" {
		t.Fatalf("clipboard %v", e.exec.clipboard)
	}
	if len(e.exec.opened) != 1 || e.exec.opened[0] != dir {
		t.Fatalf("opened %v", e.exec.opened)
	}
	msg := out["message"].(string)
	if !strings.Contains(msg, "찾지 못해서") || !strings.Contains(msg, "클립보드") {
		t.Fatalf("message %q", msg)
	}
}

func TestSendCodeModeLaunchFails(t *testing.T) {
	e := newEnv(t)
	e.exec.launchErr = errors.New("no terminal")
	tok := e.pair()
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{"title": "x", "mode": "code", "prompt": "p"}, "")
	if rec.Code != 200 || out["claudeFound"] != true || len(e.exec.clipboard) != 1 || len(e.exec.opened) != 1 {
		t.Fatalf("code = %d %v", rec.Code, out)
	}
}

func TestSendValidation(t *testing.T) {
	e := newEnv(t)
	tok := e.pair()
	cases := []struct {
		body any
		code int
		err  string
	}{
		{map[string]any{"title": "t", "mode": "fax", "prompt": "p"}, 400, "bad_mode"},
		{map[string]any{"title": "t", "mode": "code", "prompt": "  "}, 400, "empty_prompt"},
		{map[string]any{"title": "t", "mode": "file"}, 400, "empty_prompt"},
		{"not json", 400, "bad_json"},
		{`{"title":"t","mode":"file","prompt":"` + strings.Repeat("a", MaxBodyBytes) + `"}`, 413, "too_large"},
	}
	for i, c := range cases {
		rec, out := e.do("POST", "/ember/send", tok, c.body, "")
		if rec.Code != c.code || out["error"] != c.err || out["message"] == "" {
			t.Fatalf("case %d = %d %v", i, rec.Code, out)
		}
	}
	// file mode with files and no prompt is fine; no prompt.md is written.
	rec, out := e.do("POST", "/ember/send", tok, map[string]any{"title": "no prompt", "mode": "file", "files": sampleFiles()}, "")
	if rec.Code != 200 {
		t.Fatalf("files only = %d %v", rec.Code, out)
	}
	if _, err := os.Stat(filepath.Join(e.root, "no-prompt", ".ember", "prompt.md")); !os.IsNotExist(err) {
		t.Fatal("empty prompt should not be written")
	}
}

func TestPrintableStripsControlChars(t *testing.T) {
	if got := Printable("a\x1b[31mred\x07\nb", 80); got != "a [31mred b" {
		t.Fatalf("got %q", got)
	}
	if got := Printable(strings.Repeat("가", 100), 10); got != strings.Repeat("가", 10)+"…" {
		t.Fatalf("got %q", got)
	}
}
