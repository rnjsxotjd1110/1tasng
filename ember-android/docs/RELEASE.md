# Ember 출시 안내

Google Play에 올리기까지 해야 하는 일을 순서대로 적었어요. 코드로 할 수 있는 부분은 이미 들어가 있고, 아래는 계정·콘솔에서 직접 해야 하는 일이에요.

## 1. 중계 서버 배포(키 없이 쓰는 크레딧 모드)

1. `../ember-server/README.md` 를 따라 Cloudflare Workers에 배포해요.
2. 배포 주소(`https://ember-server.<계정>.workers.dev`)를 아래 빌드 설정에 넣어요.
3. 서버를 배포하지 않으면 앱은 지금처럼 '내 API 키' 방식만 보여 줘요.

## 2. 빌드 설정

`gradle.properties` 또는 `-P` 옵션으로 넣어요. 비워 두면 그 기능이 숨겨져요.

| 속성 | 예시 | 쓰는 곳 |
|---|---|---|
| `ember.serverUrl` | `https://ember-server.example.workers.dev` | 크레딧 모드, 서버 신고 |
| `ember.reportEmail` | `support@example.com` | 문의 메일, 서버가 없을 때 신고·오류 보고서 받는 곳 |
| `ember.privacyUrl` | `https://<사용자>.github.io/<저장소>/privacy.html` | 스토어 등록용(앱 안에서는 내장 화면을 보여 줌) |
| `ember.freeCredits` | `20` | 무료 크레딧 안내 문구(서버 `FREE_CREDITS` 와 같게) |
| `ember.creditMarkup` | `2.5` | 예상 크레딧 계산(서버 `MARKUP` 과 같게) |

```bash
./gradlew :app:bundleRelease \
  -Pember.serverUrl=https://ember-server.example.workers.dev \
  -Pember.reportEmail=support@example.com
# 결과: app/build/outputs/bundle/release/app-release.aab (Play 콘솔에는 AAB 를 올린다)
```

서명: 프로젝트 루트의 `keystore.properties`(저장소에 넣지 않음)로 업로드 키를 지정해요. Play 콘솔에서 **Play 앱 서명**을 켜면 이 키는 '업로드 키'가 되고, 키를 잃어버려도 콘솔에서 재설정할 수 있어요.

## 3. Play 콘솔 준비

1. **개발자 계정**: 개인 계정은 출시 전에 **테스터 12명 이상이 14일 동안 비공개 테스트**를 해야 프로덕션에 올릴 수 있어요.
2. **인앱 상품**(수익 창출 → 인앱 상품, 모두 '소비성'):
   | 상품 ID | 크레딧 | 판매가(부가세 포함) |
   |---|---|---|
   | `ember_credits_500` | 500 | ₩5,900 |
   | `ember_credits_1500` | 1,650 (+10%) | ₩17,900 |
   | `ember_credits_5000` | 5,750 (+15%) | ₩59,000 |

   - 마크업 2.5: 1크레딧 = API 원가 $0.004. Opus로 탐색 + 표준 설계서 한 세트에 약 175크레딧(약 ₩1,800~2,000).
   - Google 수수료 15%(연 100만 달러까지)와 부가세 10%를 빼고 판매가의 약 21~28%가 남아요(환율 ₩1,450 가정). 환율이 크게 오르거나 수수료가 30%가 되면 다시 계산해요.
   - 판매가를 바꾸면 서버 `PRODUCT_PRICES_KRW` 도 같이 바꿔요(환불 계산에 써요).
   - 무료 크레딧: Google 계정당 20크레딧, 결제 전에는 모든 요청을 Haiku로 처리(웹 검색 없음). Haiku로 탐색 1번 + 표준 설계서 1개. 하루 새 계정 100명(2,000크레딧)까지, 상한이 매일 차도 한 달 원가는 보통 약 ₩8만, 최악 약 ₩28만.
3. **서비스 계정**: 서버가 영수증을 확인하려면 Google Cloud 서비스 계정을 만들고 Play 콘솔 → 사용자 및 권한에서 '재무 데이터 보기·주문 관리' 권한을 줘요(자세한 단계는 서버 README).
4. **라이선스 테스터**: 설정 → 라이선스 테스트에 테스트 계정을 넣으면 실제 결제 없이 구매를 시험할 수 있어요.

## 4. 정책 양식

### 사업자 정보·약관·개인정보 처리방침
- `gradle.properties` 의 `ember.biz.*`(상호·대표·사업자등록번호·통신판매업 신고번호·주소·전화·이메일·개인정보 보호책임자·DB 위치)와 `ember.legalEffective`(시행일), `ember.termsUrl`, `ember.privacyUrl`, `ember.deleteUrl` 을 채워요. 비어 있으면 `bundleRelease` 가 멈춰요.
- `python3 tools/gen_legal.py` 로 `docs/privacy.html`, `docs/terms.html`, `docs/delete-account.html` 을 만들고 GitHub Pages 등으로 공개해요.
- 약관·방침 본문은 `app/src/main/assets/legal/*.md` 하나만 고치면 앱 화면과 웹 페이지에 함께 반영돼요(고친 뒤 스크립트를 다시 돌려요).
- 통신판매업 신고 면제 여부, 환불 수수료(10%), 유료 크레딧 유효기간(5년) 등은 출시 전에 법률 자문으로 확인하기를 권해요.

### 데이터 보안 양식(Data safety)
| 항목 | 답 |
|---|---|
| 수집하는 데이터 | **개인 정보 → 사용자 ID**(Google 계정 고유 ID, 설치마다 만드는 가명 ID), **사진**(사용자가 고른 참고 이미지, AI 생성용 전송), **앱 활동 → 기타 사용자 생성 콘텐츠**(질문 답변·입력 문장·메모, AI 생성용 전송), **앱 활동 → 앱 상호작용**(크레딧 사용 기록: 모델·토큰 수·시각), **구매 내역**(크레딧 지급·환불), **앱 정보 및 성능 → 비정상 종료 로그**(사용자가 보낼 때만), **기기 또는 기타 ID**(가명 설치 ID) |
| 공유 | 없음. Anthropic·Cloudflare·Google 은 서비스 제공업체라 '수집'으로 신고해요. |
| 처리 목적 | 앱 기능, 계정 관리, 사기 방지·보안·규정 준수(IP·기기 무결성·무료 크레딧 중복 방지) |
| 전송 중 암호화 | 예(HTTPS) |
| 삭제 요청 | 예: 앱 안(대장간 → Claude 연결 → 크레딧 계정 삭제)과 웹 URL(`ember.deleteUrl`, `docs/delete-account.html`) |
| 필수 여부 | 사용자 생성 콘텐츠는 필수(핵심 기능), 사용자 ID·구매 내역은 크레딧 모드에서만, 비정상 종료 로그는 선택 |
| 계정 삭제 URL | `docs/delete-account.html` 을 공개한 주소 |

### 생성형 AI 앱 정책
- 앱 안 신고 기능이 있어요: 프로젝트 ⋮ 메뉴와 아이디어 상세의 **AI 결과 신고**. 서버가 있으면 서버의 `reports` 표로, 없으면 `ember.reportEmail` 로 가요.
- 서버 관리자 페이지: `GET /ember/admin/reports`(헤더 `x-admin-key`)로 신고를 확인해요.

### 포그라운드 서비스 신고
- 작업이 진행되는 동안 앱이 꺼지지 않도록 `dataSync` 유형 포그라운드 서비스를 써요.
- 앱 콘텐츠 → 포그라운드 서비스 권한에서 '사용자가 시작한 네트워크 작업(AI 응답 생성)을 끝까지 받기 위해 사용'이라고 적고, 작업 중 알림이 보이는 짧은 화면 녹화를 첨부해요.

### 콘텐츠 등급·대상 연령
- 설문에서 사용자 생성 콘텐츠·AI 생성 콘텐츠가 있다고 답해요.
- 대상 연령은 **18세 이상**으로 정해요. Play 의 연령 구간(13–15 등)에는 만 14세 미만이 섞여 방침("만 14세 미만 아동의 정보를 수집하지 않음")과 맞지 않고, 유료 결제가 있어서예요.

## 5. 스토어 등록정보 초안

- **앱 이름**: Ember: 게임·앱 아이디어 설계
- **짧은 설명**: 질문 카드에 답하면 Claude가 아이디어를 찾고 개발용 설계서까지 만들어 줘요.
- **자세한 설명**:
  만들고 싶은 게 있는데 무엇부터 정해야 할지 막막할 때, Ember가 질문 카드로 하나씩 물어봐요.
  - 게임·앱·웹 중 무엇을, 어디서, 누구를 위해 만들지 카드로 고르기
  - 내 취향과 개발 규모에 맞춘 아이디어 4개, 실제로 비슷한 작품이 있는지 웹에서 확인한 링크
  - 엔진·아트·핵심 루프 같은 설계 결정을 카드로 정하고, 개발에 바로 쓰는 설계서 받기
  - 버전 기록과 바뀐 부분 비교, 단락별 직접 편집
  - Claude 앱이나 Claude Code로 이어서 개발하기, GitHub 저장소로 바로 보내기
  - 스케치나 참고 이미지를 올려 분위기 전하기
- **스크린샷**: `docs/screenshots/` 의 05, 06, 09, 13, 15, 30 번을 추천해요(휴대폰 화면 비율 그대로).

## 6. 출시 전 확인 목록

- [ ] 실제 기기에서 키 연결 → 탐색 → 아이디어 → 설계서 → Claude로 이어가기 한 바퀴
- [ ] 서버 DB 마이그레이션: 배포 전에 `migrations/0002_voided_integrity.sql`(안 했다면) → `migrations/0003_billing_guards.sql` 순서로 실행(`npx wrangler d1 execute ember --remote --file=...`)
- [ ] 서버 설정: `INTEGRITY_MODE="grant"`(기본값), Google 서비스 계정 연결(없으면 무료 크레딧 0), `ALLOW_TEST_PURCHASES` 는 출시 환경에서 켜지 않기, `FREE_CREDITS_DAILY_CAP`·`REPORTS_DAILY_CAP` 확인
- [ ] 작업대(PC 브리지)는 이번 출시에서 꺼져 있어요(`ember.workbench` 비움 = `WORKBENCH_ENABLED=false`). 다시 켜려면 LAN 전송 암호화와 방침 반영이 먼저예요.
- [ ] Google 로그인: Google Cloud 에서 OAuth 동의 화면과 **웹 클라이언트 ID**(앱의 `ember.googleWebClientId`, 서버의 `GOOGLE_OAUTH_CLIENT_IDS`), 그리고 출시 키 SHA-1 로 **Android 클라이언트 ID** 를 만들어요(서버 README 4-6). 서버에 `npx wrangler secret put SUB_HASH_SECRET`.
- [ ] 서버 DB 마이그레이션 0004(`0004_google_signin.sql`)와 그 뒤 번호도 순서대로 실행
- [ ] 실제 기기: Google 계정으로 시작 → 무료 크레딧 → 앱 삭제·재설치 → 같은 계정으로 다시 시작하면 잔액이 돌아오는지, 크레딧 계정 삭제가 되는지
- [ ] 환불 절차 연습: Play Console 에서 환불한 뒤 서버 관리자 기능으로 해당 크레딧이 정리되는지(서버 README 환불 절차)
- [ ] Play Integrity: 서버 README 4-5절대로 설정한 뒤 이 버전을 배포하고, 그다음 서버 `INTEGRITY_MODE` 를 `grant` 로 바꾸기
- [ ] 크레딧 모드: 무료 크레딧 받기 → 탐색 → 라이선스 테스터로 500크레딧 구매 → 잔액 반영
- [ ] 앱을 나간 뒤 설계서가 끝까지 써지고 알림이 오는지(Android 13 이상에서 알림 권한 허용)
- [ ] 다른 앱에서 글·사진 공유 → Ember 홈에 채워지는지
- [ ] GitHub 토큰 연결 → 새 저장소·이슈 만들기
- [ ] 설정 → 파일로 내보내기 → 앱 삭제·재설치 → 가져오기
- [ ] 영어(기기 언어 English)·라이트 테마에서 글자 잘림 없는지
