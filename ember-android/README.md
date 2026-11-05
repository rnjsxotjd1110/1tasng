# Ember — 아이디어 설계 스튜디오 (Android)

질문 카드에 답하면 Claude가 나에게 맞는 게임·앱 아이디어를 제안하고, 개발에 바로 쓸 설계서로 다듬어 Claude 앱(또는 claude.ai, Claude Code)으로 이어서 작업하게 해 주는 안드로이드 앱입니다. 서버 없이 휴대폰에서 내 Anthropic API 키로 Claude를 직접 호출합니다.

## 휴대폰에 설치하기

1. `release/Ember-1.1.0.apk` 를 휴대폰으로 받습니다.
2. 파일을 열면 "출처를 알 수 없는 앱 설치" 허용 화면이 나옵니다. 사용하는 앱(파일 관리자·브라우저 등)에 설치를 허용합니다.
3. 설치 후 Ember를 열고, 온보딩 다음 화면에서 Anthropic API 키(`sk-ant-…`)를 붙여 넣어 연결합니다.
   - 키 발급: console.anthropic.com → Settings → API Keys → Create Key (Billing에서 크레딧 충전 필요)
   - 키 없이도 홈의 "키 없이 체험해 보기"와 보관함의 예시 프로젝트로 흐름을 둘러볼 수 있습니다.

요구 사항: Android 8.0(API 26) 이상.

## 주요 기능

| 영역 | 내용 |
|---|---|
| 아이디어 탐색 | 분야 선택 → 객관식 질문 카드(단일/다중/직접 입력/건너뛰기/이전) → 아이디어 4개 |
| 아이디어 | 찜, 비교표, 상세(참고 작품·위험·검증 방법), 변형, 섞기, 질문 더 받기 |
| 설계 | 깊이 3단계(예상 비용·시간 표시), 설계 결정 질문 카드, 스트리밍 설계서 작성 |
| 설계서 | 목차, 버전 기록·복원, 수정 요청, Markdown 공유 |
| Claude로 이어가기 | 목적 4가지, 포함 내용 선택, 프롬프트 미리 보기, Claude 앱/claude.ai 열기, CLAUDE.md 내보내기 |
| 비용·신뢰 | 행동별 예상 비용, 누적·이번 달 사용량, 월 예산 한도(도달 시 요청 중단) |
| 기타 | 개발자 프로필, 모델 선택(Opus/Sonnet/Haiku 5.5), 한국어/영어, 다크/라이트, 체험 모드 |

## 빌드

```bash
# 요구: JDK 17+, Android SDK(platform 36, build-tools 36)
./gradlew :app:assembleDebug              # 디버그 APK
./gradlew :app:testDebugUnitTest          # 단위 테스트 + 스크린샷 테스트
./gradlew :app:recordRoborazziDebug       # 화면 캡처(app/build/shots)
./gradlew :app:assembleRelease            # 릴리스 APK
```

릴리스 서명은 저장소에 넣지 않습니다. 프로젝트 루트에 `keystore.properties`(storeFile, storePassword, keyAlias, keyPassword)를 두면 그 키로 서명하고, 없으면 디버그 키로 서명합니다.

## 구조

```
app/src/main/java/app/ember/ideas/
  ai/        Claude 규약(Protocol), SDK 클라이언트, 체험용 데모 AI, 비용 추정
  data/      모델, 프로젝트 저장소(JSON), 설정·암호화 키 저장, 프로젝트 엔진(흐름 관리), 예시 프로젝트
  handoff/   Claude 앱·claude.ai 열기, 프롬프트·CLAUDE.md 생성, 공유
  ui/        테마·컴포넌트·Markdown 렌더러·한국어 어절 줄바꿈·화면
app/src/test/  프로토콜·Markdown·엔진·실제 API 오류 경로 테스트, Roborazzi 스크린샷
docs/EVALUATION.md  처음 보는 평가 에이전트의 채점 기록(1차 65점 → 최종 77.25점)
docs/screenshots/   최종 빌드 화면 28장
```

Claude 모델: 기본 `claude-opus-5-5`(설정에서 Sonnet 5.5·Haiku 5.5 선택 가능). 질문 카드는 구조화 출력(JSON 스키마), 설계서는 스트리밍으로 받습니다.
