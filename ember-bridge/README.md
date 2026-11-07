# Ember 브리지

Ember 브리지는 PC에서 켜 두는 작은 프로그램입니다. 휴대폰의 **Ember** 앱에서 쓴 게임·앱 설계 문서와 프롬프트를 같은 Wi‑Fi에 있는 PC로 보내고, PC에서는 받은 내용을 다음 중 하나로 처리합니다.

- **Claude Code 실행**: 프로젝트 폴더를 만들고 새 터미널 창에서 Claude Code를 바로 시작
- **클립보드 복사**: 프롬프트를 PC 클립보드에 복사(붙여넣기만 하면 됨)
- **파일 저장**: `CLAUDE.md`, `docs/DESIGN.md` 같은 파일을 프로젝트 폴더에 저장

설치 프로그램이 없는 파일 하나짜리 프로그램입니다. 창을 닫으면 꺼집니다.

---

## Windows에서 실행하기

1. `ember-bridge-windows-amd64.exe` 를 내려받습니다. (Surface Pro X 같은 ARM PC라면 `ember-bridge-windows-arm64.exe`)
2. 파일을 **더블클릭**합니다.
   - "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**을 누릅니다(서명되지 않은 프로그램이라 처음 한 번 나옵니다).
3. **Windows 방화벽** 창이 뜨면 **"개인 네트워크"에 체크하고 "액세스 허용"**을 누릅니다.
   - 이걸 허용하지 않으면 휴대폰이 PC를 찾지도, 연결하지도 못합니다.
   - 집 Wi‑Fi가 "공용 네트워크"로 설정돼 있으면 `설정 → 네트워크 및 인터넷 → Wi‑Fi → (연결된 네트워크) → 네트워크 프로필 유형`을 **개인**으로 바꿔 주세요.
4. 검은 창에 다음이 표시됩니다.

```
========================================================
  Ember 브리지 v1.0.0
========================================================
  브리지 이름   DESKTOP-ABC123
  주소          192.168.0.12:47615   (Wi-Fi)
  프로젝트 폴더 C:\Users\me\EmberProjects
  연결된 기기   0대

  페어링 코드   48291375   (14:45까지 유효)
  Ember 앱 → 대장간 → 작업대 연결 에서 이 코드를 입력하세요.
  코드는 10분마다, 그리고 연결에 한 번 성공하면 새로 바뀌어요.

  이 창을 닫으면 브리지가 꺼져요.
========================================================
```

창은 앱에서 보낼 때까지 열어 두세요. 휴대폰이 연결되거나 무언가를 보내면 창에 한 줄씩 기록됩니다.

```
[14:36:12] 새 기기 연결: Galaxy S24
[14:36:12] 새 페어링 코드: 61143402  (14:46까지 유효)
[14:40:03] 받음: "막차 정류장 등불" · 모드: Claude Code 실행 · 기기: Galaxy S24
[14:40:03]   → Claude Code 실행: C:\Users\me\EmberProjects\막차-정류장-등불
```

### macOS / Linux

- macOS(Apple Silicon): `ember-bridge-macos-arm64`
  ```bash
  chmod +x ember-bridge-macos-arm64
  xattr -d com.apple.quarantine ember-bridge-macos-arm64   # "확인되지 않은 개발자" 경고를 피하려면
  ./ember-bridge-macos-arm64
  ```
  처음 Claude Code 모드를 쓰면 "터미널을 제어하려고 합니다" 권한 창이 뜹니다. 허용해 주세요.
- Linux(x86‑64): `chmod +x ember-bridge-linux-amd64 && ./ember-bridge-linux-amd64`
  클립보드에는 `wl-copy`(Wayland) 또는 `xclip`/`xsel`(X11)이 필요합니다.

### 실행 옵션

| 옵션 | 설명 |
|---|---|
| `--name "작업실 PC"` | 앱에 보일 브리지 이름(기본: PC 이름). 한 번 지정하면 저장됩니다 |
| `--port 47615` | HTTP 포트(기본 47615). 사용 중이면 다음 10개 포트를 차례로 시도합니다 |
| `--root D:\Ember` | 프로젝트를 만들 폴더(기본: `내 폴더\EmberProjects`). 한 번 지정하면 저장됩니다 |
| `--reset` | 연결된 기기를 모두 잊습니다(모든 휴대폰이 다시 페어링해야 함) |
| `--version` | 버전 출력 |
| `--print-code-file <파일>` | (개발·테스트용) 현재 페어링 코드를 파일에 써 둡니다 |

Windows에서 옵션을 쓰려면 바로가기를 만들고 "대상" 끝에 옵션을 붙이거나, PowerShell에서 `.\ember-bridge-windows-amd64.exe --name "작업실 PC"` 처럼 실행합니다.

---

## Ember 앱에서 연결하기

1. PC와 휴대폰이 **같은 Wi‑Fi**에 있는지 확인합니다.
2. Ember 앱에서 **대장간 → 작업대 연결**(또는 문서 화면의 **작업대로 보내기**)을 엽니다.
3. 목록에 PC 이름이 보이면 누르고, PC 창에 보이는 **8자리 페어링 코드**를 입력합니다.
   - 목록에 안 보이면 **주소 직접 입력**에 PC 창의 주소(예: `192.168.0.12:47615`)를 넣습니다. PC 이름(예: `my-pc:47615`)은 받지 않습니다. IP 주소나 `이름.local` 형식만 됩니다.
4. 연결되면 앱에 "연결됨"이 표시되고, 이후로는 코드 없이 바로 보낼 수 있습니다.

페어링 코드는 한 번만 쓸 수 있고, 10분마다 그리고 연결에 성공할 때마다 새로 바뀝니다.

누군가 틀린 코드를 10분 안에 10번 넣으면(어느 기기에서든) 브리지가 **5분 동안 모든 페어링을 멈추고** 창에 다음처럼 알립니다. 내 휴대폰이 아니라면 모르는 기기가 같은 네트워크에서 코드를 맞히려는 것일 수 있습니다.

```
[14:41:20] ! 틀린 페어링 코드가 10분 안에 10번 들어와서 페어링을 5분 동안 멈춰요. 모르는 기기가 연결을 시도하고 있을 수 있어요.
```

## 보내기 모드

| 모드 | PC에서 일어나는 일 |
|---|---|
| **Claude Code 실행** (`code`) | 파일과 프롬프트를 프로젝트 폴더에 저장하고, **새 터미널 창**을 열어 그 폴더에서 Claude Code를 시작합니다. Claude Code를 찾지 못하면 프롬프트를 클립보드에 복사하고 프로젝트 폴더를 열어 줍니다. 터미널 창이 쏟아지지 않도록 기기마다 **10초에 한 번**만 실행합니다 |
| **클립보드 복사** (`clipboard`) | 프롬프트를 PC 클립보드에 복사합니다. 함께 보낸 파일이 있으면 프로젝트 폴더에도 저장합니다 |
| **파일 저장** (`file`) | 파일을 프로젝트 폴더에 저장하고, 프롬프트는 `.ember/prompt.md` 에 저장합니다 |

### 파일이 저장되는 곳

```
<프로젝트 루트>\<폴더 이름>\
    CLAUDE.md
    docs\DESIGN.md
    .ember\prompt.md        ← 보낸 프롬프트
```

- 프로젝트 루트 기본값: Windows `C:\Users\<사용자>\EmberProjects`, macOS/Linux `~/EmberProjects` (`--root` 로 변경)
- 폴더 이름: 앱이 폴더를 지정하면 그 이름, 아니면 제목으로 만듭니다. 글자(한글 포함)와 숫자는 그대로, 나머지는 `-` 로 바꾸고 최대 60자입니다. 예: "막차 정류장 등불" → `막차-정류장-등불`
- 같은 제목으로 다시 보내면 같은 폴더의 같은 파일을 덮어씁니다.
- 프로젝트 폴더 밖(`..`, 절대 경로, `C:\` 같은 드라이브 경로 등)으로 나가는 경로가 하나라도 있으면 요청 전체를 거부합니다.
- 폴더를 열 때 명령을 실행할 수 있는 설정 파일·폴더(`.git`, `GIT~1` 같은 Windows 짧은 이름, `.claude`, `.vscode`, `.idea`, `.mcp.json`, `.envrc`)는 어느 깊이에 있든 쓰지 않습니다(요청 전체 거부).
- macOS/Linux에서는 새로 만드는 파일을 `0600`, 폴더를 `0700`(내 계정만 읽기)으로 만듭니다.

## Claude Code 준비

Claude Code 모드를 쓰려면 PC에 Claude Code가 설치되어 있고 `claude` 명령이 실행되어야 합니다.

- 공식 설치 안내(https://claude.com/claude-code)의 설치 프로그램을 쓰거나
- Node.js가 있다면 `npm i -g @anthropic-ai/claude-code`
- 설치 후 새 터미널에서 `claude` 를 한 번 실행해 로그인해 두세요.
- 브리지를 켠 **뒤에** 설치했다면 브리지 창을 닫고 다시 실행하세요(새 PATH를 읽기 위해).

브리지는 PATH와 흔한 설치 위치(`%USERPROFILE%\.local\bin`, `%APPDATA%\npm`, `~/.local/bin`, `/opt/homebrew/bin` 등)에서 `claude` 를 찾습니다.

> **Windows 참고**: 긴 여러 줄 프롬프트를 명령줄 인자로 넘기면 PowerShell 5.1과 npm의 `claude.cmd` 를 거치며 따옴표·줄바꿈이 깨집니다. 그래서 Windows에서는 Claude Code에게 *"이 폴더의 .ember/prompt.md 를 읽고 그대로 작업하라"*는 짧은 첫 메시지를 주고, Claude가 프롬프트 파일을 직접 읽게 합니다. macOS/Linux는 프롬프트 전체를 그대로 첫 메시지로 넘깁니다(`claude -- "$(cat .ember/prompt.md)"`. `--` 덕분에 `-` 로 시작하는 프롬프트도 옵션으로 해석되지 않습니다).

---

## 문제 해결

| 증상 | 확인할 것 |
|---|---|
| 앱 목록에 PC가 안 보임 | 휴대폰과 PC가 **같은 Wi‑Fi**인지(2.4GHz/5GHz 이름이 다르거나 "게스트" Wi‑Fi면 다른 네트워크입니다). 그래도 안 보이면 **주소 직접 입력**에 `192.168.0.12:47615` 처럼 PC 창의 주소를 넣으세요 |
| 주소를 넣었더니 "주소가 올바르지 않아요"(421) | PC 이름(예: `my-pc:47615`)으로는 연결할 수 없습니다. PC 창에 보이는 IP 주소(예: `192.168.0.12:47615`)나 `이름.local` 을 넣으세요 |
| "같은 네트워크(LAN)에 있는 기기에서만 연결할 수 있어요"(403) | 브리지는 사설 주소(`192.168.x.x`, `10.x.x.x`, `172.16~31.x.x`, `169.254.x.x`, IPv6 `fe80::`·`fc00::/7`)와 이 PC 자신에서 오는 요청만 받습니다. 휴대폰이 모바일 데이터(LTE/5G)로 접속 중이거나 VPN을 켰는지 확인하세요 |
| 주소를 넣어도 연결 안 됨 | **Windows 방화벽**: `제어판 → Windows Defender 방화벽 → 앱 허용`에서 ember-bridge 의 "개인"에 체크. 네트워크 프로필이 "공용"이면 "개인"으로 변경 |
| 같은 Wi‑Fi인데도 안 됨 | 공유기의 **AP 격리 / 클라이언트 격리 / 무선 격리** 기능이 켜져 있으면 기기끼리 통신할 수 없습니다. 공유기 설정에서 끄거나, 카페·회사 Wi‑Fi라면 휴대폰 핫스팟에 PC를 연결해 보세요 |
| 주소가 여러 개 나옴 | 보통 `192.168.x.x` 인 첫 줄이 Wi‑Fi 주소입니다. `vEthernet`, `VirtualBox`, `WSL` 같은 가상 어댑터 주소는 휴대폰에서 쓸 수 없습니다 |
| "자동 검색(mDNS)을 켜지 못했어요" | 연결 자체는 됩니다. 앱에서 주소를 직접 입력하세요 |
| "Ember 브리지가 이미 실행 중이에요" | 다른 브리지 창이 열려 있습니다. 그 창을 쓰거나 닫고 다시 실행하세요 |
| 앱에서 "연결 정보가 없어요"(401) | PC에서 `--reset` 을 했거나 설정 파일이 바뀐 경우입니다. 앱에서 다시 페어링하세요 |
| "시도가 너무 많아요"(429) | 같은 휴대폰(IP)에서 페어링을 1분에 5번 넘게 시도했습니다. 1분 뒤 다시 하세요 |
| "틀린 페어링 코드가 너무 많이 들어와서…"(429) | 10분 안에 틀린 코드가 10번 들어와 브리지가 5분 동안 페어링을 멈췄습니다. 앱에 표시된 시간만큼 기다린 뒤 PC 창의 **새** 코드로 다시 하세요 |
| "Claude Code는 기기마다 10초에 한 번만…"(429) | Claude Code 실행 모드를 너무 빨리 연달아 보냈습니다. 몇 초 뒤 다시 보내세요 |
| Claude Code 대신 클립보드에 복사됨 | PC에서 `claude` 를 못 찾았습니다. 위의 "Claude Code 준비"를 확인하세요 |
| 창의 한글이 깨짐 | 브리지는 시작할 때 콘솔을 UTF‑8로 바꿉니다. 그래도 깨지면 창 제목줄 우클릭 → 속성 → 글꼴에서 한글 글꼴(예: 돋움체, D2Coding)을 고르세요. Windows 터미널에서는 대개 문제없습니다 |

## 보안 메모

- 브리지는 PC의 **모든 네트워크 연결**에서 포트를 엽니다. 다만 요청을 보낸 주소가 이 PC 자신(루프백)이거나 사설·링크 로컬 주소(`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, IPv6 `fe80::/10`, `fc00::/7`)가 아니면 처리하기 전에 403으로 거부합니다. 클라우드를 거치지 않습니다.
  - 그래도 같은 사설망에 있는 기기(카페·회사·기숙사 Wi‑Fi의 모르는 사람, VPN·Docker 같은 가상 네트워크 포함)는 브리지에 접속할 수 있습니다. 믿을 수 있는 네트워크에서만 켜 두세요.
  - 공유기에서 포트 포워딩을 하지 마세요. 공유기가 주소를 바꿔(NAT·프록시) 사설 주소로 보이게 만들면 이 검사를 통과할 수 있습니다.
- 웹 브라우저가 보낸 요청은 받지 않습니다. `Origin` 헤더가 있는 요청(403), `Content-Type: application/json` 이 아닌 POST(415), `Host` 가 IP 주소·`localhost`·`*.local` 이 아닌 요청(421, DNS 리바인딩 방지)은 모두 거부합니다.
- 처음 연결할 때만 PC 화면의 **8자리** 코드가 필요합니다. 코드는 한 번 쓰면 사라지고 10분마다 바뀌며, IP당(IPv6는 /64 대역당) 1분에 5번까지만 시도할 수 있습니다. 어느 기기에서든 틀린 코드가 10분에 10번 들어오면 5분 동안 모든 페어링을 멈추고, 20번 틀리면 코드가 바로 바뀝니다.
- 연결된 휴대폰마다 **별도의 토큰**(무작위 32바이트)을 받습니다. PC에는 토큰의 **SHA‑256 해시만** 저장됩니다.
- 설정 파일: Windows `%APPDATA%\ember-bridge\config.json`, macOS `~/Library/Application Support/ember-bridge/config.json`, Linux `~/.config/ember-bridge/config.json`
- 휴대폰을 잃어버렸거나 모든 연결을 끊고 싶으면 `--reset` 으로 실행하세요.
- 창에는 제목·모드·기기 이름·저장 위치만 표시됩니다. 토큰이나 프롬프트 본문은 기록하지 않습니다. 창에 찍는 이름과 경로는 제어 문자를 지워 터미널 조작 문자열이 실행되지 않게 합니다.
- 파일은 프로젝트 폴더 안에만 써지며(경로 검사 + 심볼릭 링크/정션 차단), `.git`·`.claude`·`.vscode`·`.idea`·`.mcp.json`·`.envrc` 와 Windows 짧은 이름(`GIT~1` 등), 보이지 않는 유니코드 서식 문자(예: U+202E)가 든 경로는 쓰지 않습니다.
- Claude Code 실행 모드는 기기마다 10초에 한 번으로 제한됩니다. 페어링 요청 본문은 1KB, 보내기 요청 본문은 2MB까지 받습니다.
- 페어링된 휴대폰은 PC에서 Claude Code를 실행시킬 수 있다는 점을 기억하세요. 내 휴대폰만 연결하세요.

### 알려진 한계

- **LAN 통신은 암호화되지 않습니다(TLS 없음).** 같은 네트워크에서 트래픽을 엿볼 수 있는 사람은 페어링 코드, 토큰, 보내는 프롬프트·파일을 볼 수 있고, 가로챈 토큰으로 요청을 보낼 수도 있습니다. 공용 Wi‑Fi에서는 쓰지 마세요.
- **토큰은 만료되지 않습니다.** 한 번 연결된 기기는 앱에서 연결을 끊거나 PC에서 `--reset` 을 할 때까지 계속 유효합니다.
- **mDNS 자동 검색은 인증되지 않습니다.** 같은 네트워크의 다른 기기가 같은 이름으로 브리지인 척 광고할 수 있습니다. 처음 페어링할 때 앱에 보이는 주소가 PC 창의 주소와 같은지 확인하세요.

---

## 앱 개발자용: API 계약 (v1)

- 검색: mDNS/DNS‑SD 서비스 타입 `_ember._tcp`, 도메인 `local.`, 인스턴스 이름 = 브리지 이름, TXT `id=<브리지 id>`, `v=1`, `name=<브리지 이름>`. 기본 포트 47615(사용 중이면 47616~47625).
- 모든 응답은 JSON(`Content-Type: application/json; charset=utf-8`). 오류는 `{"error":"<코드>","message":"<한국어 문장>"}`.
- 요청 본문 최대 2MB(`/ember/pair` 는 1KB, 초과 시 413 `too_large`). 잘못된 JSON은 400 `bad_json`. 메서드가 다르면 405 `method_not_allowed`, 없는 경로는 404 `not_found`.
- 모든 경로 공통 검사(핸들러보다 먼저):
  - 보낸 쪽 주소가 루프백·사설 IPv4(RFC 1918)·IPv4 링크 로컬·IPv6 링크 로컬(`fe80::/10`)·IPv6 ULA(`fc00::/7`)가 아니면 403 `forbidden`
  - `Origin` 헤더가 있으면(값과 관계없이) 403 `forbidden`
  - `Host` 헤더의 이름 부분(포트 제외)이 IP 리터럴, `localhost`, `*.local` 이 아니면 421 `bad_host`
- 모든 POST는 `Content-Type: application/json`(매개변수 `; charset=utf-8` 허용)이어야 합니다. 아니면 415 `unsupported_media_type`. 본문이 필요 없는 `/ember/unpair` 도 `{}` 와 함께 보냅니다.

### `GET /ember/info`
```json
{"id":"06e05b1a39513ddb5256a7b78af2040e","name":"DESKTOP-ABC123","version":"1.0.0","os":"windows","pairingRequired":true}
```
`os` 는 `windows` / `darwin` / `linux`.

### `POST /ember/pair`
요청 `{"code":"12345678","deviceName":"Galaxy S24"}` (숫자 8자리. 공백·`-` 는 무시)

- 200 `{"token":"<32바이트 base64url, 패딩 없음 43자>","name":"<브리지 이름>","id":"<브리지 id>"}`
- 403 `bad_code` — 틀렸거나 만료되었거나 이미 쓴 코드
- 429 `rate_limited` — 같은 IP(IPv6는 같은 /64)에서 1분에 5회 초과, 또는 전체 잠금 중(어디서든 틀린 코드가 10분에 10번 → 5분 동안 모든 페어링 거부). 둘 다 `Retry-After` 헤더(초)와 한국어 `message`
- 413 `too_large` — 본문 1KB 초과

토큰은 앱이 안전하게 저장하고, 이후 요청에 `Authorization: Bearer <token>` 으로 보냅니다.

### `GET /ember/ping` (Bearer)
200 `{"ok":true}` → 앱에 "연결됨" 표시. 401 `unauthorized` 면 다시 페어링.

### `POST /ember/send` (Bearer)
```json
{
  "title": "막차 정류장 등불",
  "mode": "code",
  "prompt": "...",
  "files": [
    {"path": "CLAUDE.md", "content": "..."},
    {"path": "docs/DESIGN.md", "content": "..."}
  ],
  "folder": "optional-subfolder-name"
}
```
- `mode`: `code` | `clipboard` | `file`
- `prompt`: `code`·`clipboard` 에서는 필수. `file` 은 파일이 있으면 생략 가능
- `files[].path`: 프로젝트 폴더 기준 **상대 경로**(`/` 권장, `\` 도 구분자로 처리). `..`, `.`, 빈 구간, 절대 경로, 드라이브 문자(`C:`), `:`·`*`·`?`·`"`·`<`·`>`·`|`, 제어 문자/NUL, 유니코드 제어(Cc)·서식(Cf) 문자(예: U+202E, U+200B), 끝의 점·공백, Windows 예약 이름(`CON`, `NUL`, `COM1`…), 어느 깊이든 `.git`·`.claude`·`.vscode`·`.idea`·`.mcp.json`·`.envrc` 구간(대소문자 무시), `~` 뒤에 숫자가 오는 구간(Windows 8.3 짧은 이름, 예: `GIT~1`)은 거부 → **요청 전체가** 400 `bad_path`, 아무것도 저장되지 않음. 최대 500개
- `folder`: 선택. 프로젝트 루트 아래 **한 단계 폴더 이름**(위 구간 규칙 + `%` 불가). 없으면 `slug(title)`. 올바르지 않으면 400 `bad_folder`

200 응답:
```json
{"ok":true,"mode":"code","folder":"C:\\Users\\me\\EmberProjects\\막차-정류장-등불","saved":["CLAUDE.md","docs/DESIGN.md"],"message":"PC에서 새 터미널을 열고 Claude Code를 시작했어요","claudeFound":true}
```
- `folder`: 사용한 절대 경로. 파일 없이 `clipboard` 로 보낸 경우는 `""`
- `saved`: 저장한 파일 경로(정규화된 `/` 형식, `.ember/prompt.md` 는 포함하지 않음)
- `message`: 앱에 그대로 보여 줄 한국어 문장
- `claudeFound`: PC에서 `claude` 를 찾았는지. `code` 모드에서 `false` 면 프롬프트를 클립보드에 복사하고 폴더를 열었다는 뜻(`ok` 는 `true`)

그 밖의 오류: 400 `bad_mode`, 400 `empty_prompt`, 400 `too_many_files`, 401 `unauthorized`, 429 `rate_limited`(`code` 모드를 같은 기기에서 10초 안에 다시 보냄. `Retry-After` 헤더, 아무것도 저장·실행하지 않음), 500 `write_failed`, 500 `clipboard_failed`(`clipboard` 모드에서 복사 실패).

### `POST /ember/unpair` (Bearer)
200 `{"ok":true}` — 이 기기의 토큰을 PC에서 지웁니다.

---

## 빌드 (개발자용)

Go 1.24 이상.

```bash
go vet ./...
go test -race ./...
./build.sh            # dist/ 에 Windows(amd64, arm64)·macOS(arm64)·Linux(amd64) 바이너리 생성
```

구성: `main.go`(시작·콘솔 출력), `internal/server`(HTTP API), `internal/pairing`(코드·속도 제한·토큰), `internal/project`(폴더 이름·경로 검사·파일 저장), `internal/launcher`(터미널·클립보드·파일 탐색기 실행, OS별), `internal/config`(설정 파일), `internal/discovery`(mDNS), `internal/netinfo`(LAN 주소), `internal/console`(Windows UTF‑8 콘솔).
