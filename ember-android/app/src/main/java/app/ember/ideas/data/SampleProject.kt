package app.ember.ideas.data

import android.content.Context
import java.util.Locale

/**
 * 처음 설치했을 때 보관함에 넣어 두는 예시 프로젝트.
 * API 키 없이도 Ember 가 어떤 결과물을 만드는지 바로 볼 수 있다.
 */
object SampleProject {

    fun create(context: Context): Project {
        val ko = Locale.getDefault().language == "ko" ||
            context.resources.configuration.locales[0].language == "ko"
        return if (ko) korean() else english()
    }

    /** 앱 기획서 예시(기획자·PM용). 한국어 기기에서만 함께 넣는다. */
    fun koreanApp(): Project {
        val now = System.currentTimeMillis()
        val idea = Idea(
            "sa_1", "한 줄 회고", "퇴근길 1분, 오늘 한 일을 한 줄로 남기면 주간 성장 리포트를 만들어 주는 앱.", "생산성", listOf("Android", "iOS"), "회고·기록",
            "주니어 직장인과 취업 준비생", "한 줄만 써도 일주일이 정리되는 가벼움",
            listOf("하루 한 줄 회고(30초)", "주간 리포트 자동 생성", "키워드 성장 그래프", "알림 시간 맞춤"),
            "일기보다 짧고 업무 일지보다 개인적인 '한 줄' 단위", "구독 월 2,900원(리포트 고급 기능)", "소형", "1인 2개월", 2,
            "짧게 쓰는 습관 앱과 혼자 개발 규모를 원하셨어요.",
            listOf("Daylio — 기분 기록은 같지만 업무·성장 회고가 없어요", "Notion 템플릿 — 자유롭지만 매일 쓰기에는 무거워요"),
            listOf("2주 이후 이탈", "리포트 품질이 기대보다 낮을 위험"),
            "노션 폼으로 2주간 한 줄 회고를 받고 직접 리포트를 써서 10명에게 보내 봐요.",
        )
        return Project(
            id = "sample_ko_app", title = "한 줄 회고", kind = ProjectKind.APP, seed = "퇴근길에 하루 정리",
            createdAt = now - 172_800_000L, updatedAt = now - 7_200_000L, stage = ProjectStage.DOCUMENT,
            ideaBatches = listOf(IdeaBatch("sa", now - 170_000_000L, "", "", listOf(idea))),
            savedIdeaIds = listOf("sa_1"),
            design = DesignState(ideaId = "sa_1", depth = DocDepth.STANDARD, versions = listOf(DocVersion("va1", now - 7_200_000L, "", SAMPLE_APP_DOC_KO))),
            isSample = true,
        )
    }

    private fun q(title: String, sub: String, multi: Boolean, vararg opts: Pair<String, String>) = Question(
        title = title,
        subtitle = sub,
        multiSelect = multi,
        options = opts.mapIndexed { i, (label, emoji) -> QuestionOption("o${i + 1}", label, "", emoji) },
    )

    fun korean(): Project {
        val now = System.currentTimeMillis()
        val turns = listOf(
            Turn("종류", 10, "", q("무엇을 만들고 싶으세요?", "방향을 먼저 잡아 볼게요.", false, "게임" to "🎮", "앱" to "📱", "웹 서비스" to "🌐"), Answer(listOf("o1"))),
            Turn("플랫폼", 22, "사용자는 게임을 만들고 싶어 합니다.", q("주로 어디서 플레이하나요?", "조작과 세션 길이가 달라져요.", false, "모바일" to "📱", "PC" to "💻", "콘솔" to "🕹️"), Answer(listOf("o1"))),
            Turn("분위기", 38, "모바일 게임을 원하고 있습니다.", q("어떤 분위기가 끌리나요?", "아트와 사운드 방향을 정해요.", true, "아늑함" to "🕯️", "몽환적" to "🌙", "긴장감" to "⚡"), Answer(listOf("o1", "o2"))),
            Turn("핵심 경험", 55, "아늑하고 몽환적인 모바일 게임을 그리고 있습니다.", q("어떤 재미가 중심이면 좋을까요?", "핵심 루프의 뼈대가 됩니다.", false, "퍼즐" to "🧩", "수집·성장" to "🌱", "이야기" to "📖"), Answer(listOf("o1"), "짧게 끝나는 퍼즐")),
            Turn("규모", 72, "짧게 즐기는 아늑한 퍼즐 게임을 원합니다.", q("개발 규모는 어느 정도인가요?", "범위를 현실적으로 맞출게요.", false, "혼자, 3개월" to "🧑‍💻", "혼자, 6개월+" to "⏳", "소규모 팀" to "👥"), Answer(listOf("o1"))),
        )
        val ideas = listOf(
            Idea("s_1", "등불지기", "꺼져 가는 등대 마을에 빛을 이어 붙여 밤을 지키는 한 손 퍼즐 게임.", "퍼즐", listOf("Android", "iOS"), "빛 연결 퍼즐", "출퇴근길에 짧게 플레이하는 20~40대", "빛줄기를 꺾어 모든 등불을 동시에 밝히는 순간의 쾌감", listOf("거울·프리즘으로 빛 경로 만들기", "하루 한 장의 '오늘의 밤' 퍼즐", "밝힌 집마다 주민 이야기 한 줄", "실수 없는 클리어 시 별빛 보너스"), "빛이 이야기를 여는 열쇠라서 퍼즐을 풀수록 마을이 살아납니다.", "광고 없는 유료(3,900원) + 계절 퍼즐 팩", "소형", "1인 3개월", 2, "아늑함·몽환적 분위기와 짧은 퍼즐, 1인 3개월 규모를 모두 만족합니다."),
            Idea("s_2", "구름 우체국", "구름 위 우체부가 되어 편지를 바람길에 태워 보내는 경로 퍼즐.", "퍼즐", listOf("Android", "iOS"), "경로 퍼즐", "힐링 게임을 즐기는 사람", "바람의 방향을 바꿔 편지를 정확히 배달하는 손맛", listOf("바람 타일 회전", "편지 내용 수집", "주민 관계도"), "배달한 편지가 다음 퍼즐의 힌트가 됩니다.", "프리미엄 + 코스메틱", "소형", "1인 3~4개월", 2, "아늑한 분위기와 퍼즐 선호를 반영했습니다."),
            Idea("s_3", "잠든 정원사", "꿈속 정원을 하루 5분씩 가꾸며 식물 퍼즐을 푸는 게임.", "퍼즐·방치", listOf("Android"), "가드닝 퍼즐", "가벼운 루틴을 찾는 사람", "매일 바뀌는 정원 배치 최적화", listOf("식물 배치 퍼즐", "꿈 일지", "계절 이벤트"), "실제 수면 시간과 연동한 꿈 테마", "무료 + 광고 제거", "소형", "1인 3개월", 2, "몽환적 분위기와 짧은 세션을 우선했습니다."),
            Idea("s_4", "별자리 재봉사", "흩어진 별을 실로 꿰어 잃어버린 별자리를 복원하는 한붓그리기 퍼즐.", "퍼즐", listOf("Android", "iOS"), "한붓그리기", "퍼즐 마니아", "한 번에 이어지는 선의 완벽함", listOf("실 길이 제한", "별자리 신화 카드", "타임어택 모드"), "별자리 신화를 퍼즐 규칙으로 바꿨습니다.", "유료", "소형", "1인 2~3개월", 3, "퍼즐 중심과 몽환적 분위기를 반영했습니다."),
        )
        val doc = SAMPLE_DOC_KO
        return Project(
            id = "sample_ko",
            title = "등불지기",
            kind = ProjectKind.GAME,
            seed = "자기 전에 5분 하는 아늑한 퍼즐",
            createdAt = now - 86_400_000L,
            updatedAt = now - 3_600_000L,
            stage = ProjectStage.DOCUMENT,
            turns = turns,
            ideaBatches = listOf(IdeaBatch("s", now - 80_000_000L, "답변을 바탕으로 아늑하고 짧은 퍼즐 게임 네 가지를 골랐어요.", "", ideas)),
            savedIdeaIds = listOf("s_1"),
            design = DesignState(
                ideaId = "s_1",
                depth = DocDepth.STANDARD,
                turns = listOf(
                    Turn("핵심 루프", 40, "", q("한 판의 길이는 어느 정도가 좋을까요?", "", false, "1~2분" to "⏱️", "3~5분" to "☕", "10분+" to "🛋️"), Answer(listOf("o2"))),
                    Turn("엔진", 80, "한 판 3~5분의 짧은 퍼즐로 정했습니다.", q("어떤 엔진으로 만들까요?", "", false, "Godot" to "🤖", "Unity" to "🧊", "Flutter" to "🦋"), Answer(listOf("o1"))),
                ),
                readySummary = "- 한 판 3~5분\n- Godot 4, 세로 화면\n- 유료 단일 구매",
                versions = listOf(DocVersion("v1", now - 3_600_000L, "", doc)),
            ),
            isSample = true,
            usage = Usage(),
        )
    }

    fun english(): Project {
        val k = korean()
        val turns = listOf(
            Turn("Type", 15, "", q("What do you want to make?", "Let's set the direction first.", false, "Game" to "🎮", "App" to "📱", "Web service" to "🌐"), Answer(listOf("o1"))),
            Turn("Platform", 35, "You want to make a game.", q("Where will people play?", "This shapes controls and session length.", false, "Mobile" to "📱", "PC" to "💻", "Console" to "🕹️"), Answer(listOf("o1"))),
            Turn("Mood", 60, "You are picturing a mobile game.", q("Which mood draws you in?", "Sets the art and sound direction.", true, "Cozy" to "🕯️", "Dreamy" to "🌙", "Tense" to "⚡"), Answer(listOf("o1", "o2"))),
        )
        val idea = Idea("s_1", "Lamplighter", "A one-handed puzzle game where you link light across a fading lighthouse town to keep the night safe.", "Puzzle", listOf("Android", "iOS"), "Light-routing puzzle", "Commuters aged 20–40", "The rush of lighting every lamp at once", listOf("Bend light with mirrors and prisms", "One 'Tonight' puzzle per day", "A line of story per lit house", "Starlight bonus for flawless clears"), "Light unlocks the story, so the town comes alive as you solve.", "Premium ($2.99) + seasonal packs", "Small", "Solo, 3 months", 2, "Matches your cozy, dreamy mood, short sessions and solo scope.")
        return k.copy(
            id = "sample_en",
            title = "Lamplighter",
            seed = "A cozy 5-minute puzzle before bed",
            turns = turns,
            ideaBatches = listOf(IdeaBatch("s", k.createdAt, "Based on your answers, here are short, cozy puzzle ideas.", "", listOf(idea))),
            design = k.design!!.copy(turns = emptyList(), readySummary = "", versions = listOf(DocVersion("v1", k.updatedAt, "", SAMPLE_DOC_EN))),
        )
    }

    internal val SAMPLE_DOC_KO = """
# 등불지기

> 꺼져 가는 등대 마을에 빛을 이어 붙여 밤을 지키는, 자기 전 5분짜리 아늑한 빛 연결 퍼즐 게임입니다.

## 한눈에 보기

| 항목 | 내용 |
|---|---|
| 장르 | 빛 연결 퍼즐 |
| 플랫폼 | Android, iOS (세로 화면, 한 손 조작) |
| 대상 | 출퇴근길·자기 전에 짧게 즐기는 20~40대 |
| 플레이 시간 | 한 판 3~5분, 하루 15분 |
| 엔진 | Godot 4.3 (GDScript) |
| 개발 규모 | 1인, 3개월 |

## 핵심 재미와 게임 루프

- **30초 루프**: 거울을 돌려 빛줄기를 꺾고, 등불 하나가 켜지는 손맛을 느낍니다.
- **5분 루프**: 한 장의 밤 지도에서 모든 등불을 밝히면 마을 한 구역이 깨어나고 주민 이야기 한 줄이 열립니다.
- **1시간 루프(누적)**: 7개 구역을 밝히면 등대가 다시 돌아가고 다음 계절 지도가 열립니다.

## 조작과 핵심 메커닉

- 탭: 거울을 45도씩 회전합니다.
- 길게 누르기: 프리즘을 집어 다른 칸으로 옮깁니다.
- 빛은 거울에서 꺾이고, 프리즘에서 두 갈래로 나뉘며, 색 필터를 지나면 색이 바뀝니다.
- 같은 색 빛이 닿아야 해당 색 등불이 켜집니다.

## 콘텐츠 구성

| 계절 | 지도 수 | 새 요소 |
|---|---|---|
| 봄 | 20 | 거울, 기본 등불 |
| 여름 | 20 | 프리즘(분광) |
| 가을 | 20 | 색 필터 |
| 겨울 | 20 | 얼음 거울(한 번만 회전) |

## 진행·보상·밸런스 구조

- 이동 횟수 기준 별 1~3개를 줍니다. 최소 이동 +2 이내면 별 3개입니다.
- 별 40개마다 장식(등불 모양) 1개를 해금합니다.
- 막히면 힌트 3번(첫 거울 위치 공개)을 하루 무료로 줍니다.

## 화면 구성과 UI 흐름

- 타이틀 → 마을 지도(구역 선택) → 퍼즐 화면 → 클리어 연출과 주민 이야기 → 마을 지도로 복귀

## 아트·사운드 방향

- 남색 밤하늘과 호박색 불빛의 2색 대비, 32px 기준 픽셀아트입니다.
- 등불이 켜질 때 부드러운 오르골 음 하나를 재생합니다.

## 기술 설계

- `scenes/puzzle/Board.tscn`: 격자, 빛 경로 계산(`light_tracer.gd`)
- 지도 데이터는 `data/maps/*.tres` 리소스로 관리합니다.
- 저장은 `user://save.json`에 별 개수와 해금 상태만 기록합니다.

## 수익 모델

- 3,900원 단일 구매(광고 없음), 계절 퍼즐 팩 1,500원 (제안)

## 개발 로드맵

| 주차 | 산출물 |
|---|---|
| 1~3 | 빛 경로 계산·거울 회전 프로토타입 |
| 4~7 | 봄·여름 40개 지도, UI |
| 8~10 | 가을·겨울, 사운드, 이야기 |
| 11~12 | 폴리시, 스토어 출시 |

## 리스크와 대응

- 퍼즐 난이도 편차: 지도마다 최소 이동 수를 자동 계산하는 검증 도구를 먼저 만듭니다.
- 콘텐츠 부족: 지도 에디터를 2주차에 만들어 제작 속도를 확보합니다.

## 다음 단계

1. "Godot 4.3 로 격자 위 빛 경로를 계산하는 light_tracer.gd 를 만들어 줘. 거울·프리즘·색 필터를 지원해 줘."
2. "지도를 .tres 리소스로 저장하고 불러오는 지도 에디터 씬을 만들어 줘."
3. "봄 계절 지도 20개의 난이도 곡선을 표로 설계해 줘."
""".trimIndent()

    internal val SAMPLE_DOC_EN = """
# Lamplighter

> A cozy five-minute light-routing puzzle where you relight a fading lighthouse town before bed.

## At a glance

| Item | Detail |
|---|---|
| Genre | Light-routing puzzle |
| Platforms | Android, iOS (portrait, one hand) |
| Audience | Commuters and bedtime players aged 20–40 |
| Session | 3–5 minutes per map |
| Engine | Godot 4.3 (GDScript) |
| Scope | Solo, 3 months |

## Core loop

- **30 seconds**: rotate a mirror, bend the beam, watch a lamp come alive.
- **5 minutes**: light every lamp on a night map to wake a district and unlock a resident's story line.
- **Long term**: wake 7 districts to restart the lighthouse and open the next season.

## Content

| Season | Maps | New element |
|---|---|---|
| Spring | 20 | Mirrors |
| Summer | 20 | Prisms |
| Autumn | 20 | Color filters |
| Winter | 20 | Ice mirrors |

## Monetization

- $2.99 premium, no ads; seasonal packs $0.99 (suggested)

## Roadmap

| Weeks | Deliverable |
|---|---|
| 1–3 | Light tracer prototype |
| 4–7 | Spring and summer maps, UI |
| 8–10 | Autumn, winter, audio, story |
| 11–12 | Polish and store launch |

## Next steps

1. "Build light_tracer.gd for Godot 4.3 that traces beams across a grid with mirrors, prisms and color filters."
2. "Create a map editor scene that saves and loads maps as .tres resources."
3. "Design a difficulty curve table for the 20 spring maps."
""".trimIndent()

    internal val SAMPLE_APP_DOC_KO = """
# 한 줄 회고

> 퇴근길 1분, 오늘 한 일을 한 줄로 남기면 주간 성장 리포트를 만들어 주는 앱입니다.

## 한눈에 보기

| 항목 | 내용 |
|---|---|
| 카테고리 | 생산성 · 회고 |
| 플랫폼 | Android, iOS (Flutter) |
| 대상 | 입사 1~3년 차 직장인, 취업 준비생 |
| 핵심 가치 | 30초 기록으로 일주일 성장을 한눈에 |
| 개발 규모 | 1인, 8주 |

## 문제와 해결

- 문제: 회고가 중요하다는 건 알지만 일기나 업무 일지는 매일 쓰기에 무겁습니다.
- 해결: 하루 한 줄만 받고, 주말에 Claude API로 한 주를 요약한 리포트를 만들어 줍니다.

## 대상 사용자와 사용 시나리오

- 직장인으로서 퇴근길에 30초 안에 오늘을 기록하고 싶다, 그래야 습관이 끊기지 않는다.
- 취업 준비생으로서 한 주에 무엇을 해냈는지 보고 싶다, 그래야 면접에서 경험을 말할 수 있다.
- 사용자로서 기록이 쌓인 키워드를 보고 싶다, 그래야 내가 어디에 시간을 쓰는지 안다.

## 기능 명세

| 기능 | 우선순위 | 수용 기준 |
|---|---|---|
| 한 줄 기록 | 필수 | 앱 실행 후 2탭 안에 저장, 120자 제한 |
| 알림 | 필수 | 사용자가 정한 시각에 하루 1회 |
| 주간 리포트 | 필수 | 일요일 21시 생성, 기록 3개 이상일 때 |
| 키워드 그래프 | 권장 | 최근 4주 상위 키워드 5개 |
| 클라우드 백업 | 나중 | 로그인 시 자동 동기화 |

## 수익 모델과 성공 지표

- 무료: 기록·알림·기본 리포트 / 구독(월 2,900원): 키워드 그래프·월간 리포트 (제안)
- 지표: 7일 리텐션 40% 이상, 주당 평균 기록 4회 이상, 구독 전환 3% 이상

## 개발 로드맵

| 주차 | 산출물 |
|---|---|
| 1~2 | 기록·알림·로컬 저장 |
| 3~5 | 주간 리포트(Claude API), 그래프 |
| 6~8 | 구독 결제, 스토어 출시 |

## 열린 질문과 다음 단계

1. "Flutter로 한 줄 기록 화면과 로컬 저장(Hive)을 만들어 줘."
2. "일주일 기록을 받아 리포트를 만드는 Claude API 프롬프트를 설계해 줘."
3. "7일 리텐션을 측정할 이벤트 목록을 정리해 줘."
""".trimIndent()
}
