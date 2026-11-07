# Ember 개인정보 처리방침

시행일 [미입력]

[미입력](이하 "회사")는 Ember 앱(이하 "앱")을 운영하며 「개인정보 보호법」에 따라 이용자의 개인정보를 다음과 같이 처리해요.

## 1. 처리 목적·항목·보유기간

| 구분 | 항목 | 목적 | 보유기간 |
|---|---|---|---|
| 앱 안 저장 | 프로젝트, 설계서, 메모, 참고 이미지, 설정, 개발자 프로필 | 앱 기능 제공 | 이 휴대폰에만 저장, 이용자가 지우거나 앱을 지울 때까지 |
| 크레딧 계정 | Google 계정 고유 식별자(숫자 ID), 설치마다 무작위로 만드는 식별자(가명 ID), 계정 토큰의 해시 | 크레딧 계정 생성·로그인·복구 | 계정 삭제 시까지. 무료 크레딧만 있는 계정은 마지막 사용 후 1년, 유료 크레딧이 남은 계정은 마지막 구매일로부터 5년 |
| 크레딧 사용 기록 | 모델, 토큰 수, 차감한 크레딧, 시각 | 크레딧 차감·정산, 분쟁 대응 | 1년 |
| 결제 기록 | Google Play 주문번호, 상품, 수량, 지급 크레딧, 결제·환불 시각 | 크레딧 지급, 환불·청약철회 처리 | 결제일로부터 5년(전자상거래법). 계정 삭제 시 계정과의 연결을 끊고 보관 |
| 부정 이용 방지 | IP 주소(IPv6는 앞 64비트), 기기 무결성 판정 결과 | 과도한 요청·무료 크레딧 부정 수령 방지 | IP 주소 2일. 무결성 판정 결과는 저장하지 않음 |
| 무료 크레딧 중복 방지 | Google 계정 식별자를 되돌릴 수 없게 변환한 값(HMAC) | 계정을 지웠다 다시 만들어 무료 크레딧을 반복해 받는 것을 막기 위해 | 계정 삭제 후 3년 |
| AI 결과 신고 | 신고 이유, 메모, 신고한 AI 결과 | 신고 검토, 서비스 안전성 개선 | 1년 |
| 문의·오류 보고 | 이용자가 보낸 메일 주소와 내용, 오류 보고서(앱·기기·Android 버전, 오류 위치) | 답변, 오류 수정 | 3년 |

회사는 요청 내용(질문 답변, 입력한 문장, 이미지, 설계서)을 서버에 저장하지 않아요. 광고 ID, 쿠키, 분석 도구를 쓰지 않아요.

## 2. 처리위탁과 국외 이전

회사는 서비스 제공(계약 이행)을 위해 아래와 같이 개인정보 처리를 맡기고 국외로 이전해요.

| 이전받는 자(연락처) | 국가 | 시기·방법 | 항목 | 목적 | 보유기간 |
|---|---|---|---|---|---|
| Anthropic, PBC (privacy@anthropic.com) | 미국 | AI 생성을 요청할 때마다 암호화 통신(HTTPS)으로 | 질문 답변, 입력한 문장, 참고 이미지, 개발자 프로필, 아이디어·설계서, 웹 검색어 | 아이디어·설계서 생성 | Anthropic의 데이터 보존 정책에 따름 |
| Cloudflare, Inc. (privacyquestions@cloudflare.com) | 미국 등 Cloudflare 데이터센터 소재국(DB 위치: [미입력]) | Ember 크레딧 이용 시 HTTPS로 | 1번의 크레딧 계정·사용·결제·부정 이용 방지·신고 항목, 크레딧 모드의 AI 요청(저장하지 않고 전달만) | 중계 서버와 DB 운영 | 1번의 보유기간과 같음 |
| Google LLC (Google 개인정보처리방침의 문의처) | 미국 | 로그인·가입·구매 시 HTTPS로 | Google ID 토큰, 기기 무결성 토큰, 구매 토큰 | 로그인 확인, 부정 이용 방지, 결제 확인 | Google 정책에 따름 |

**거부 방법과 효과**: 국외 이전을 원하지 않으면 AI 생성 기능을 쓰지 않으면 돼요(체험 모드와 앱 안 편집은 쓸 수 있어요). Ember 크레딧을 쓰지 않으면 Cloudflare·Google로는 전송되지 않아요. 내 API 키를 쓰면 요청은 휴대폰에서 Anthropic으로 바로 가요.

'실제 작품 검색'을 켜 두면 검색어에 입력한 아이디어의 키워드가 들어갈 수 있고, Anthropic과 Anthropic이 쓰는 검색 서비스로 전달돼요.

## 3. 제3자 제공

회사는 이용자의 개인정보를 제3자에게 제공하지 않아요. 다만 법령에 따라 요구받은 경우는 예외예요.

## 4. 파기 절차와 방법

보유기간이 끝나거나 목적을 이루면 지체 없이 파기해요. 서버의 전자 기록은 복구할 수 없는 방법으로 지우고, 법령에 따라 보관해야 하는 기록은 다른 정보와 분리해 그 기간 동안만 보관한 뒤 파기해요.

## 5. 이용자의 권리와 행사 방법

이용자는 언제든 개인정보의 열람·정정·삭제·처리정지를 요구할 수 있어요.

- 크레딧 계정 삭제: 앱의 대장간 → Claude 연결 → 크레딧 계정 삭제, 또는 [미입력]
- 이 휴대폰의 데이터 삭제: 대장간 → 모든 데이터 지우기, 또는 앱 삭제
- 그 밖의 요구: [미입력]로 보내 주시면 10일 안에 처리하고 결과를 알려 드려요.

## 6. 안전성 확보조치

전송 구간 암호화(HTTPS), 휴대폰 안 키·토큰의 Android Keystore 암호화, 서버 토큰의 해시 저장, 관리자 기능의 접근 키 제한, 접근 권한 최소화를 하고 있어요.

## 7. 앱 접근권한

- 알림(선택): 작업이 끝나면 알려 드려요. 거부해도 다른 기능은 쓸 수 있어요.
- 사진: 시스템 사진 선택기에서 고른 사진만 써요(별도 권한 없음).
- 음성: '말로 적기'는 휴대폰의 음성 인식 서비스(예: Google)를 써요. 음성은 그 서비스의 정책에 따라 처리되고 회사는 음성을 받지 않아요.

## 8. 만 14세 미만 아동

Ember는 만 14세 미만 아동의 개인정보를 수집하지 않아요. 만 14세 미만 아동의 정보가 수집된 사실을 알게 되면 바로 삭제해요.

## 9. 개인정보 보호책임자

- 개인정보 보호책임자: [미입력]
- 연락처: [미입력], [미입력]

## 10. 권익침해 구제

- 개인정보분쟁조정위원회: 1833-6972 (kopico.go.kr)
- 개인정보침해신고센터: 118 (privacy.kisa.or.kr)
- 대검찰청: 1301 (spo.go.kr)
- 경찰청: 182 (ecrm.police.go.kr)

## 11. 방침의 변경

방침을 바꾸면 시행 7일 전부터 앱과 이 페이지에 알려 드려요. 이용자에게 불리한 중요한 변경은 30일 전에 알려 드려요.

---

회사 정보: [미입력] · 대표 [미입력] · 사업자등록번호 [미입력] · 주소 [미입력]


---

# Ember Privacy Policy

Effective [not set]

[not set] ("we") operates the Ember app and processes personal information as described below, in line with Korea's Personal Information Protection Act.

## 1. What we process, why, and for how long

| Category | Items | Purpose | Retention |
|---|---|---|---|
| On your phone | Projects, design docs, notes, reference images, settings, developer profile | Running the app | On this phone only, until you delete them or the app |
| Credit account | Google account ID (numeric), a random per-install ID (pseudonymous), a hash of your account token | Creating, signing in to and recovering your credit account | Until you delete the account. Free-only accounts: 1 year after last use. Accounts with paid credits: 5 years from the last purchase |
| Credit usage | Model, token counts, credits charged, time | Charging and settling credits, disputes | 1 year |
| Purchases | Google Play order ID, product, quantity, credits granted, purchase and refund times | Granting credits, refunds and withdrawals | 5 years from purchase (Korean e-commerce law); unlinked from the account when it is deleted |
| Abuse prevention | IP address (first 64 bits for IPv6), device integrity verdict | Preventing excessive requests and free-credit abuse | IP: 2 days. The verdict is not stored |
| Free-credit duplicate check | An irreversible keyed hash (HMAC) of your Google account ID | Stopping people from deleting and recreating accounts to get free credits again | 3 years after account deletion |
| AI content reports | Reason, note, reported content | Reviewing reports, improving safety | 1 year |
| Support and crash reports | Your email address and message, crash report (app, device and Android version, error location) | Replies and bug fixes | 3 years |

We do not store request content (your answers, text, images or documents) on our servers. We do not use advertising IDs, cookies or analytics.

## 2. Processors and overseas transfer

| Recipient (contact) | Country | When and how | Items | Purpose | Retention |
|---|---|---|---|---|---|
| Anthropic, PBC (privacy@anthropic.com) | USA | Each AI request, over HTTPS | Answers, text, reference images, developer profile, ideas and docs, web search queries | Generating ideas and design docs | Under Anthropic's retention policy |
| Cloudflare, Inc. (privacyquestions@cloudflare.com) | USA and Cloudflare data-center countries (database: [not set]) | When you use Ember credits, over HTTPS | Credit, usage, purchase, abuse-prevention and report items in section 1; AI requests in credit mode (passed through, not stored) | Running the relay server and database | As in section 1 |
| Google LLC (see Google's privacy policy) | USA | At sign-in, registration and purchase, over HTTPS | Google ID token, device integrity token, purchase token | Sign-in, abuse prevention, purchase verification | Under Google's policy |

**How to refuse and what happens**: if you don't want your data transferred abroad, don't use AI generation (demo mode and on-device editing still work). Without Ember credits nothing goes to Cloudflare or Google. With your own API key, requests go straight from your phone to Anthropic.

With "Search real works" on, search queries may include keywords from your idea and are passed to Anthropic and the search service it uses.

## 3. Third parties

We do not provide your personal information to third parties, except when required by law.

## 4. Deletion

We delete information without delay when its retention period ends or its purpose is met, using methods that can't be undone. Records we must keep by law are kept separately and only for that period.

## 5. Your rights

You can ask to see, correct, delete or stop processing your information at any time.

- Delete your credit account: Workshop → Claude access → Delete credit account, or [not set]
- Delete data on this phone: Workshop → Erase all data, or uninstall the app
- Anything else: email [not set]; we act within 10 days and tell you the result.

## 6. Security

HTTPS in transit, Android Keystore encryption for keys and tokens on the phone, hashed tokens on the server, key-restricted admin functions, least-privilege access.

## 7. App permissions

- Notifications (optional): tell you when work finishes. Everything else works without them.
- Photos: only photos you pick in the system photo picker (no permission needed).
- Voice: "Dictate" uses your phone's speech recognition service (e.g. Google). Audio is handled under that service's policy; we never receive it.

## 8. Children

Ember does not collect information from children under 14. If we learn that we have, we delete it immediately.

## 9. Privacy officer

- Privacy officer: [not set]
- Contact: [not set], [not set]

## 10. Changes

We announce changes in the app and on this page 7 days before they take effect, or 30 days before for important changes that are unfavorable to you.

---

[not set] · CEO [not set] · Business reg. no. [not set] · [not set]
