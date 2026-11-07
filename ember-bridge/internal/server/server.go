// Package server implements the Ember bridge JSON API.
package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"

	"ember-bridge/internal/config"
	"ember-bridge/internal/launcher"
	"ember-bridge/internal/pairing"
	"ember-bridge/internal/project"
)

const (
	// MaxBodyBytes caps every request body.
	MaxBodyBytes = 2 << 20
	// MaxPairBodyBytes caps /ember/pair bodies (a code and a device name).
	MaxPairBodyBytes = 1 << 10
	// MaxFiles caps the number of files in one send.
	MaxFiles = 500
	// PairAttemptsPerMinute is the per-IP (IPv6: per /64) pairing rate limit.
	PairAttemptsPerMinute = 5
	// PairGlobalMaxFailures wrong codes from any sources within
	// PairGlobalWindow pause all pairing for PairLockoutDuration.
	PairGlobalMaxFailures = 10
	PairGlobalWindow      = 10 * time.Minute
	PairLockoutDuration   = 5 * time.Minute
	// CodeLaunchCooldown is the minimum gap between two code-mode sends
	// (each opens a terminal) from one device.
	CodeLaunchCooldown = 10 * time.Second
	// HTTPWriteTimeout is the http.Server WriteTimeout. It must exceed the
	// slowest /ember/send (launch timeout + clipboard + open folder).
	HTTPWriteTimeout = 120 * time.Second

	maxDeviceNameRunes = 64
	maxTitleRunes      = 80
)

// Modes accepted by /ember/send.
const (
	ModeCode      = "code"
	ModeClipboard = "clipboard"
	ModeFile      = "file"
)

// Server holds everything the handlers need.
type Server struct {
	Config  *config.Store
	Codes   *pairing.CodeManager
	Limiter *pairing.RateLimiter
	Lockout *pairing.Lockout // global wrong-code lockout for pairing
	Exec    launcher.Executor
	Version string
	Logf    func(format string, args ...any) // console status lines; never secrets
	Now     func() time.Time
	mux     *http.ServeMux

	launchMu   sync.Mutex
	lastLaunch map[string]time.Time // device token hash → last code-mode send
}

// New wires a server with default limits.
func New(cfg *config.Store, codes *pairing.CodeManager, exec launcher.Executor, version string, logf func(string, ...any)) *Server {
	if logf == nil {
		logf = func(string, ...any) {}
	}
	s := &Server{
		Config:  cfg,
		Codes:   codes,
		Limiter: pairing.NewRateLimiter(PairAttemptsPerMinute, time.Minute),
		Lockout: pairing.NewLockout(PairGlobalMaxFailures, PairGlobalWindow, PairLockoutDuration),
		Exec:    exec,
		Version: version,
		Logf:    logf,
		Now:     time.Now,
		mux:     http.NewServeMux(),

		lastLaunch: map[string]time.Time{},
	}
	s.mux.HandleFunc("/ember/info", s.method(http.MethodGet, s.handleInfo))
	s.mux.HandleFunc("/ember/pair", s.method(http.MethodPost, s.handlePair))
	s.mux.HandleFunc("/ember/send", s.method(http.MethodPost, s.auth(s.handleSend)))
	s.mux.HandleFunc("/ember/unpair", s.method(http.MethodPost, s.auth(s.handleUnpair)))
	s.mux.HandleFunc("/ember/ping", s.method(http.MethodGet, s.auth(s.handlePing)))
	s.mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "not_found", "없는 주소예요.")
	})
	return s
}

// Handler returns the HTTP handler for the API, behind the LAN/browser guard.
func (s *Server) Handler() http.Handler { return s.guard(s.mux) }

// ---- helpers ---------------------------------------------------------------

type errorBody struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, errorBody{Error: code, Message: msg})
}

func (s *Server) method(m string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != m {
			w.Header().Set("Allow", m)
			writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", m+" 요청만 받아요.")
			return
		}
		if m == http.MethodPost && !isJSON(r.Header.Get("Content-Type")) {
			writeError(w, http.StatusUnsupportedMediaType, "unsupported_media_type",
				"Content-Type 은 application/json 이어야 해요.")
			return
		}
		h(w, r)
	}
}

type ctxDevice struct {
	hash string
	dev  config.Device
}

type authedHandler func(w http.ResponseWriter, r *http.Request, d ctxDevice)

func (s *Server) auth(h authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearer(r)
		if !ok {
			writeError(w, http.StatusUnauthorized, "unauthorized", "연결 정보가 없어요. 앱에서 이 PC와 다시 연결해 주세요.")
			return
		}
		hash := pairing.HashToken(token)
		dev, found := s.Config.FindDevice(hash)
		if !found {
			writeError(w, http.StatusUnauthorized, "unauthorized", "이 PC에 연결된 기기가 아니에요. 앱에서 다시 연결해 주세요.")
			return
		}
		h(w, r, ctxDevice{hash: hash, dev: dev})
	}
}

func bearer(r *http.Request) (string, bool) {
	h := r.Header.Get("Authorization")
	const prefix = "bearer "
	if len(h) <= len(prefix) || !strings.EqualFold(h[:len(prefix)], prefix) {
		return "", false
	}
	t := strings.TrimSpace(h[len(prefix):])
	return t, t != ""
}

// decode reads a JSON body capped at limit bytes. It writes the error
// response itself and returns false on failure.
func decode(w http.ResponseWriter, r *http.Request, v any, limit int64) bool {
	r.Body = http.MaxBytesReader(w, r.Body, limit)
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(v); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			size := fmt.Sprintf("%dMB", limit>>20)
			if limit < 1<<20 {
				size = fmt.Sprintf("%dKB", limit>>10)
			}
			writeError(w, http.StatusRequestEntityTooLarge, "too_large", "보낸 내용이 너무 커요(최대 "+size+").")
			return false
		}
		writeError(w, http.StatusBadRequest, "bad_json", "요청 형식이 올바르지 않아요.")
		return false
	}
	return true
}

// Printable removes control characters (so a phone cannot inject terminal
// escape sequences into the console) and caps the length.
func Printable(s string, maxRunes int) string {
	s = strings.Map(func(r rune) rune {
		if unicode.IsControl(r) || r == utf8.RuneError || unicode.Is(unicode.Cf, r) {
			return ' '
		}
		return r
	}, s)
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) > maxRunes {
		s = string([]rune(s)[:maxRunes]) + "…"
	}
	return s
}

func (s *Server) logf(format string, args ...any) {
	s.Logf("[%s] "+format, append([]any{s.Now().Format("15:04:05")}, args...)...)
}

// ---- handlers --------------------------------------------------------------

type infoResponse struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	Version         string `json:"version"`
	OS              string `json:"os"`
	PairingRequired bool   `json:"pairingRequired"`
}

func (s *Server) handleInfo(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, infoResponse{
		ID:              s.Config.ID(),
		Name:            s.Config.Name(),
		Version:         s.Version,
		OS:              runtime.GOOS,
		PairingRequired: true,
	})
}

type pairRequest struct {
	Code       string `json:"code"`
	DeviceName string `json:"deviceName"`
}

type pairResponse struct {
	Token string `json:"token"`
	Name  string `json:"name"`
	ID    string `json:"id"`
}

// retrySeconds rounds a wait up to whole seconds for Retry-After.
func retrySeconds(d time.Duration) int {
	secs := int((d + time.Second - 1) / time.Second)
	if secs < 1 {
		secs = 1
	}
	return secs
}

func tooMany(w http.ResponseWriter, wait time.Duration, msgf string) {
	secs := retrySeconds(wait)
	w.Header().Set("Retry-After", strconv.Itoa(secs))
	writeError(w, http.StatusTooManyRequests, "rate_limited", fmt.Sprintf(msgf, secs))
}

func (s *Server) handlePair(w http.ResponseWriter, r *http.Request) {
	if locked, left := s.Lockout.Locked(); locked {
		tooMany(w, left, "틀린 페어링 코드가 너무 많이 들어와서 PC가 연결을 잠시 막았어요. %d초 뒤에 다시 해 주세요.")
		return
	}
	key := rateKey(r.RemoteAddr)
	if ok, retry := s.Limiter.Allow(key); !ok {
		tooMany(w, retry, "시도가 너무 많아요. %d초 뒤에 다시 해 주세요.")
		return
	}
	var req pairRequest
	if !decode(w, r, &req, MaxPairBodyBytes) {
		return
	}
	if !s.Codes.Verify(req.Code) {
		s.logf("페어링 실패: 코드가 맞지 않아요 (%s)", Printable(key, 64))
		if s.Lockout.Fail() {
			s.logf("! 틀린 페어링 코드가 %d분 안에 %d번 들어와서 페어링을 %d분 동안 멈춰요. 모르는 기기가 연결을 시도하고 있을 수 있어요.",
				int(PairGlobalWindow/time.Minute), PairGlobalMaxFailures, int(PairLockoutDuration/time.Minute))
		}
		writeError(w, http.StatusForbidden, "bad_code",
			fmt.Sprintf("페어링 코드가 맞지 않거나 만료됐어요. PC 화면에 보이는 %d자리 코드를 다시 확인해 주세요.", pairing.CodeDigits))
		return
	}
	name := Printable(req.DeviceName, maxDeviceNameRunes)
	if name == "" {
		name = "이름 없는 기기"
	}
	token, hash, err := pairing.NewToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal", "연결 정보를 만들지 못했어요.")
		return
	}
	if err := s.Config.AddDevice(name, hash, s.Now()); err != nil {
		writeError(w, http.StatusInternalServerError, "config_write_failed", "설정 파일을 저장하지 못했어요.")
		return
	}
	s.logf("새 기기 연결: %s", name)
	s.Codes.Current() // issue and announce the next code
	writeJSON(w, http.StatusOK, pairResponse{Token: token, Name: s.Config.Name(), ID: s.Config.ID()})
}

type sendRequest struct {
	Title  string         `json:"title"`
	Mode   string         `json:"mode"`
	Prompt string         `json:"prompt"`
	Files  []project.File `json:"files"`
	Folder string         `json:"folder"`
}

type sendResponse struct {
	OK          bool     `json:"ok"`
	Mode        string   `json:"mode"`
	Folder      string   `json:"folder"`
	Saved       []string `json:"saved"`
	Message     string   `json:"message"`
	ClaudeFound bool     `json:"claudeFound"`
}

var modeLabels = map[string]string{
	ModeCode:      "Claude Code 실행",
	ModeClipboard: "클립보드 복사",
	ModeFile:      "파일 저장",
}

func (s *Server) handleSend(w http.ResponseWriter, r *http.Request, d ctxDevice) {
	var req sendRequest
	if !decode(w, r, &req, MaxBodyBytes) {
		return
	}
	label, okMode := modeLabels[req.Mode]
	if !okMode {
		writeError(w, http.StatusBadRequest, "bad_mode", "mode 는 code, clipboard, file 중 하나여야 해요.")
		return
	}
	if len(req.Files) > MaxFiles {
		writeError(w, http.StatusBadRequest, "too_many_files", fmt.Sprintf("파일은 한 번에 %d개까지 보낼 수 있어요.", MaxFiles))
		return
	}
	if strings.TrimSpace(req.Prompt) == "" && (req.Mode != ModeFile || len(req.Files) == 0) {
		writeError(w, http.StatusBadRequest, "empty_prompt", "보낼 프롬프트가 비어 있어요.")
		return
	}
	// Validate every path before touching the disk: one bad path rejects all.
	for _, f := range req.Files {
		if _, err := project.CleanRelPath(f.Path); err != nil {
			writeError(w, http.StatusBadRequest, "bad_path",
				"파일 경로가 안전하지 않아요(상대 경로만, '..'·절대 경로·드라이브 문자 불가): "+Printable(f.Path, 80))
			return
		}
	}
	root := s.Config.Root()
	dir, err := project.ProjectDir(root, req.Folder, req.Title)
	if err != nil {
		writeError(w, http.StatusBadRequest, "bad_folder", "폴더 이름이 올바르지 않아요(한 단계 폴더 이름만, 특수문자 불가).")
		return
	}

	if req.Mode == ModeCode {
		if wait := s.reserveLaunch(d.hash); wait > 0 {
			tooMany(w, wait, fmt.Sprintf("Claude Code는 기기마다 %d초에 한 번만 실행할 수 있어요. %%d초 뒤에 다시 보내 주세요.",
				int(CodeLaunchCooldown/time.Second)))
			return
		}
	}

	title := Printable(req.Title, maxTitleRunes)
	if title == "" {
		title = "(제목 없음)"
	}
	s.logf("받음: \"%s\" · 모드: %s · 기기: %s", title, label, Printable(d.dev.DeviceName, maxDeviceNameRunes))

	claudePath, claudeFound := s.Exec.FindClaude()
	resp := sendResponse{OK: true, Mode: req.Mode, Saved: []string{}, ClaudeFound: claudeFound}

	// Decide whether anything goes to disk.
	needFolder := req.Mode != ModeClipboard || len(req.Files) > 0
	if needFolder {
		saved, err := project.Write(root, dir, req.Files, req.Prompt)
		if err != nil {
			s.logf("  ! 저장 실패: %s", Printable(err.Error(), 300))
			if errors.Is(err, project.ErrBadPath) {
				writeError(w, http.StatusBadRequest, "bad_path", "프로젝트 폴더 밖으로 나가는 경로라서 저장하지 않았어요.")
				return
			}
			writeError(w, http.StatusInternalServerError, "write_failed", "PC에 파일을 저장하지 못했어요: "+Printable(err.Error(), 200))
			return
		}
		resp.Folder = dir
		resp.Saved = saved
	}

	switch req.Mode {
	case ModeFile:
		if len(resp.Saved) > 0 {
			resp.Message = fmt.Sprintf("프로젝트 폴더에 파일 %d개를 저장했어요", len(resp.Saved))
		} else {
			resp.Message = "프로젝트 폴더에 프롬프트를 저장했어요"
		}
		s.logf("  → 저장: %s (파일 %d개)", Printable(dir, 300), len(resp.Saved))

	case ModeClipboard:
		if err := s.Exec.CopyToClipboard(req.Prompt); err != nil {
			s.logf("  ! 클립보드 복사 실패: %s", Printable(err.Error(), 300))
			msg := "PC 클립보드에 복사하지 못했어요."
			if resp.Folder != "" {
				msg += " 프롬프트는 프로젝트 폴더의 .ember/prompt.md 에 저장했어요."
			}
			writeError(w, http.StatusInternalServerError, "clipboard_failed", msg)
			return
		}
		resp.Message = "프롬프트를 PC 클립보드에 복사했어요"
		if len(resp.Saved) > 0 {
			resp.Message += fmt.Sprintf(" (파일 %d개는 프로젝트 폴더에 저장했어요)", len(resp.Saved))
		}
		s.logf("  → 클립보드에 복사했어요")
		if resp.Folder != "" {
			s.logf("  → 저장: %s (파일 %d개)", Printable(dir, 300), len(resp.Saved))
		}

	case ModeCode:
		launched := false
		var launchErr error
		if claudeFound {
			launchErr = s.Exec.LaunchClaude(dir, claudePath)
			launched = launchErr == nil
		}
		if launched {
			resp.Message = "PC에서 새 터미널을 열고 Claude Code를 시작했어요"
			s.logf("  → Claude Code 실행: %s", Printable(dir, 300))
			break
		}
		// Fallback: clipboard + open the folder.
		clipErr := s.Exec.CopyToClipboard(req.Prompt)
		openErr := s.Exec.OpenFolder(dir)
		var reason string
		if !claudeFound {
			reason = "PC에서 Claude Code(claude)를 찾지 못해서"
			s.logf("  ! Claude Code(claude)를 찾지 못했어요 — 클립보드 복사로 대신해요")
		} else {
			reason = "터미널을 열지 못해서"
			s.logf("  ! 터미널 실행 실패: %s — 클립보드 복사로 대신해요", Printable(launchErr.Error(), 300))
		}
		switch {
		case clipErr == nil:
			resp.Message = reason + " 프롬프트를 클립보드에 복사"
			if openErr == nil {
				resp.Message += "하고 프로젝트 폴더를 열었어요"
			} else {
				resp.Message += "했어요"
			}
		default:
			s.logf("  ! 클립보드 복사 실패: %s", Printable(clipErr.Error(), 300))
			resp.Message = reason + " 프롬프트를 프로젝트 폴더의 .ember/prompt.md 에 저장해 두었어요"
		}
		if !claudeFound {
			resp.Message += ". Claude Code를 설치하면 다음부터 바로 실행돼요"
		}
		s.logf("  → 저장: %s (파일 %d개)", Printable(dir, 300), len(resp.Saved))
	}

	writeJSON(w, http.StatusOK, resp)
}

// reserveLaunch records a code-mode send for the device and returns 0, or,
// if the device sent one less than CodeLaunchCooldown ago, how long to wait.
func (s *Server) reserveLaunch(hash string) time.Duration {
	s.launchMu.Lock()
	defer s.launchMu.Unlock()
	now := s.Now()
	if last, ok := s.lastLaunch[hash]; ok {
		if wait := last.Add(CodeLaunchCooldown).Sub(now); wait > 0 {
			return wait
		}
	}
	for h, t := range s.lastLaunch { // at most one entry per paired device
		if now.Sub(t) >= CodeLaunchCooldown {
			delete(s.lastLaunch, h)
		}
	}
	s.lastLaunch[hash] = now
	return 0
}

func (s *Server) handleUnpair(w http.ResponseWriter, r *http.Request, d ctxDevice) {
	dev, ok, err := s.Config.RemoveDevice(d.hash)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "config_write_failed", "설정 파일을 저장하지 못했어요.")
		return
	}
	if ok {
		s.logf("기기 연결 해제: %s", Printable(dev.DeviceName, maxDeviceNameRunes))
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handlePing(w http.ResponseWriter, r *http.Request, d ctxDevice) {
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
