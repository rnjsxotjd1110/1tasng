# STARVEIL · 별장막의 미궁

주사위로 운명을 굴리는 모바일 로그라이크 RPG. 동료 소녀 3인과의 교감, 미니게임 4종, 방치형 야영지가 함께 있어요.

- 플랫폼: 안드로이드(WebView APK) · 모바일/데스크톱 브라우저
- 기술: 바닐라 JavaScript(ES 모듈) + esbuild 단일 HTML 번들, 모든 그림은 SVG 코드, 모든 소리는 WebAudio 합성
- 오프라인 동작, 저장은 기기 내 localStorage(백업 슬롯 + 저장 코드 내보내기)

## 실행·빌드

```bash
cd starveil
npm install              # esbuild, eslint (개발용)
npm run build            # dist/index.html (단일 파일, 브라우저로 바로 열 수 있음)
npm test                 # 정적 검사 + 헤드리스 테스트 9천여 개 (대사 규칙·데이터·맵·유물·원정 240회)
node tools/sim.mjs 200 none 0     # 밸런스 시뮬레이션 (판수, 성장 none|mid|max, 위상)
bash tools/apk.sh        # dist/STARVEIL.apk (Android SDK 필요: tools/apk.sh 상단 경로 참고)
node tools/qa.cjs title,start     # 폰 화면 스크린샷 QA (build/shots)
node tools/monkey.cjs 3           # 실제 화면을 눌러 원정을 끝까지 진행하는 UI 테스트
node tools/audio_check.cjs        # 효과음 음량·튐·길이 검사 (먼저 audio 번들 생성 필요, 파일 상단 참고)
```

APK 서명 키(`android/starveil.keystore`, 비밀번호 `starveil`)는 개인 설치·업데이트용이에요. 스토어에 올릴 때는 새 키를 만들어야 해요.

## 폴더

```
src/
  core/   rng, util(조사 함수 josa 포함), combat(전투 엔진·이벤트 로그), run(맵·노드·보상·상점), profile(저장·성장·동료·임무), bot(자동 전투 AI)
  data/   classes, skills(87), relics(51), enemies(41)+ACTS, events(20), potions(12), dice(12), meta(별자리 트리·달의 위상), achievements(46), gifts, minigames, companions, heroine_meta, heroines/(lyra·mio·seren 대본)
  art/    icons, heroines(표정 7 × 의상 4), monsters(26형), scenes(배경 7), dice, logo
  audio/  audio(효과음 29 + 생성형 배경음악 6)
  ui/     app(화면 전환·저장), dom(도우미), scr_title, scr_hub(야영지·원정 준비·별자리), scr_run(지도·노드), scr_combat, scr_heroine, vn(대화 상자), scr_mini(미니게임 4), scr_misc(설정·임무·업적·도감·상점)
tests/run.mjs        헤드리스 테스트
tools/               build, apk.sh, icons, sim, autopilot, qa, qa_states, monkey, audio_check
android/             매니페스트, MainActivity(WebView), 아이콘
docs/                DESIGN.md(설계), HEROINE_BRIEF.md(대사 규칙)
dist/                빌드 결과(index.html, STARVEIL.apk, 아이콘)
```

## 대사 규칙(모든 대사·서술에 적용, `npm test` 가 검사)

1. 모든 문장에 주어를 쓴다. 2. 문장을 '다'로 끝내지 않는다(해요체·반말). 3. 단어 하나 뒤에 쉼표를 찍지 않는다. 4. 뜻 모를 추상 표현을 쓰지 않는다. 5. 효과음은 음 끌기·노이즈·큰 소리를 쓰지 않는다.
