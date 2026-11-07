package app.ember.ideas.ai

import app.ember.ideas.data.Answer
import app.ember.ideas.data.DepthMode
import app.ember.ideas.data.DevProfile
import app.ember.ideas.data.PresetAnswer
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.Idea
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.Question
import app.ember.ideas.data.Turn
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Claude 가 답할 언어. 앱 언어를 따르거나 설정에서 고정한다. */
enum class ReplyLanguage(val promptName: String) { KO("한국어(Korean)"), EN("English") }

/**
 * Ember 와 Claude 사이의 대화 규약.
 * 순수 Kotlin 이라 단위 테스트로 검증한다. SDK·안드로이드에 의존하지 않는다.
 */
object Protocol {

    val json = Json { ignoreUnknownKeys = true; isLenient = true; explicitNulls = false; encodeDefaults = true }

    // ---------------------------------------------------------------- 응답 형식

    @Serializable
    data class InterviewReply(
        val kind: String,
        val stage: String = "",
        val progress: Int = 0,
        val insight: String = "",
        val question: Question = Question(title = ""),
        @SerialName("ideas_intro") val ideasIntro: String = "",
        val ideas: List<Idea> = emptyList(),
        @SerialName("ready_summary") val readySummary: String = "",
    ) {
        val isQuestion get() = kind == KIND_QUESTION && question.title.isNotBlank() && question.options.isNotEmpty()
        val isIdeas get() = kind == KIND_IDEAS && ideas.isNotEmpty()
        val isReady get() = kind == KIND_READY
    }

    const val KIND_QUESTION = "question"
    const val KIND_IDEAS = "ideas"
    const val KIND_READY = "ready"

    fun parseReply(text: String): InterviewReply {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        require(start >= 0 && end > start) { "응답에서 JSON 을 찾지 못했습니다." }
        val reply = json.decodeFromString(InterviewReply.serializer(), text.substring(start, end + 1))
        return reply.copy(
            progress = reply.progress.coerceIn(0, 100),
            question = sanitizeQuestion(reply.question),
            // 모델이 같은 id 를 두 번 주면 목록 키가 겹쳐 화면이 죽으므로 순서대로 다시 매긴다.
            ideas = reply.ideas.mapIndexed { i, idea ->
                val dupId = idea.id.isBlank() || reply.ideas.take(i).any { it.id == idea.id }
                idea.copy(
                    id = if (dupId) "idea${i + 1}" else idea.id,
                    difficulty = idea.difficulty.coerceIn(1, 5),
                    funScore = if (idea.funScore == 0) 0 else idea.funScore.coerceIn(1, 5),
                    noveltyScore = if (idea.noveltyScore == 0) 0 else idea.noveltyScore.coerceIn(1, 5),
                    keyFeatures = idea.keyFeatures.filter { it.isNotBlank() },
                    platforms = idea.platforms.filter { it.isNotBlank() },
                )
            },
        )
    }

    /** 중복·빈 선택지를 걸러내고 id 를 보장한다. 모델 출력이 조금 어긋나도 화면이 깨지지 않게 한다. */
    fun sanitizeQuestion(q: Question): Question {
        val seen = HashSet<String>()
        val options = q.options
            .filter { it.label.isNotBlank() }
            .mapIndexed { i, o -> if (o.id.isBlank() || !seen.add(o.id)) o.copy(id = "opt${i + 1}") else o }
            .distinctBy { it.label.trim() }
        return q.copy(options = options.take(8))
    }

    // ---------------------------------------------------------------- JSON 스키마

    private fun str() = buildJsonObject { put("type", "string") }
    private fun bool() = buildJsonObject { put("type", "boolean") }
    private fun int() = buildJsonObject { put("type", "integer") }
    private fun strArray() = buildJsonObject { put("type", "array"); put("items", str()) }
    private fun enumOf(vararg v: String) = buildJsonObject {
        put("type", "string")
        put("enum", buildJsonArray { v.forEach { add(JsonPrimitive(it)) } })
    }

    private fun obj(vararg props: Pair<String, JsonElement>) = buildJsonObject {
        put("type", "object")
        put("additionalProperties", false)
        put("properties", JsonObject(props.toMap()))
        put("required", JsonArray(props.map { JsonPrimitive(it.first) }))
    }

    private fun questionSchema() = obj(
        "title" to str(),
        "subtitle" to str(),
        "multi_select" to bool(),
        "options" to buildJsonObject {
            put("type", "array")
            put("items", obj("id" to str(), "label" to str(), "description" to str()))
        },
        "allow_custom" to bool(),
        "custom_hint" to str(),
    )

    private fun ideaSchema() = obj(
        "id" to str(),
        "title" to str(),
        "logline" to str(),
        "category" to str(),
        "platforms" to strArray(),
        "genre" to str(),
        "target_audience" to str(),
        "core_hook" to str(),
        "key_features" to strArray(),
        "unique_point" to str(),
        "monetization" to str(),
        "scope" to str(),
        "dev_time" to str(),
        "difficulty" to int(),
        "fun_score" to int(),
        "novelty_score" to int(),
        "fit_reason" to str(),
        "similar_works" to strArray(),
        "risks" to strArray(),
        "validation" to str(),
        "references" to buildJsonObject {
            put("type", "array")
            put("items", obj("title" to str(), "url" to str()))
        },
    )

    val discoverySchema: JsonObject = obj(
        "kind" to enumOf(KIND_QUESTION, KIND_IDEAS),
        "stage" to str(),
        "progress" to int(),
        "insight" to str(),
        "question" to questionSchema(),
        "ideas_intro" to str(),
        "ideas" to buildJsonObject { put("type", "array"); put("items", ideaSchema()) },
    )

    val designSchema: JsonObject = obj(
        "kind" to enumOf(KIND_QUESTION, KIND_READY),
        "stage" to str(),
        "progress" to int(),
        "insight" to str(),
        "question" to questionSchema(),
        "ready_summary" to str(),
    )

    // ---------------------------------------------------------------- 시스템 프롬프트

    fun discoverySystem(lang: ReplyLanguage): String = """
당신은 'Ember' 앱 안에서 일하는 아이디어 큐레이터입니다. 사용자는 앞으로 만들 게임이나 앱의 아이디어를 찾고 있습니다.
당신의 일은 객관식 카드 질문을 한 번에 하나씩 던져 사용자의 취향·상황·제약을 알아낸 뒤, 그 사람에게 꼭 맞는 독창적인 아이디어를 제안하는 것입니다.

## 응답 규칙
- 모든 응답은 주어진 JSON 스키마를 그대로 따릅니다. 사용자에게 보이는 모든 문장은 ${lang.promptName}로 씁니다.
- kind 가 "question" 이면 question 을 채우고 ideas 는 빈 배열, ideas_intro 는 빈 문자열로 둡니다.
- kind 가 "ideas" 이면 ideas 에 아이디어 4개를 넣고, question 은 title 과 options 를 비운 빈 질문으로 둡니다.
- stage 는 지금 묻는 영역을 2~6글자로 적습니다(예: "플랫폼", "타깃", "장르", "분위기", "규모", "수익").
- progress 는 아이디어를 제안하기까지의 진행률(0~100)입니다. 아이디어를 낼 때는 100 입니다.
- insight 는 지금까지 파악한 내용을 한 문장으로 요약합니다. 주어와 서술어를 갖춘 자연스러운 문장으로 쓰고, 첫 질문에서는 빈 문자열로 둡니다.
- 한국어로 쓸 때 사용자에게 보이는 모든 문장(insight, subtitle, description, ideas_intro, fit_reason 등)은 "~해요", "~있어요" 같은 해요체로 씁니다. "~합니다" 체는 쓰지 않습니다.

## 질문 설계
- 질문은 한 번에 하나만 합니다. 이미 답을 알 수 있는 내용은 다시 묻지 않습니다.
- 선택지는 4~6개를 주며 서로 겹치지 않게 구체적으로 씁니다. label 은 짧게(최대 18자), description 은 한 줄 설명(최대 40자)입니다.
- 여러 개를 고르는 것이 자연스러운 질문(장르 취향, 영감을 받은 작품, 기능 등)은 multi_select 를 true 로 합니다.
- allow_custom 은 대부분 true 로 두고, custom_hint 에 직접 입력 예시를 적습니다.
- subtitle 에는 이 질문을 왜 하는지 한 문장으로 적습니다.
- 질문 갈래 16가지(상황에 맞게 순서·생략을 조절하고, 같은 갈래를 두 번 묻지 않습니다):
  1. 목적: 왜 만드는지(바이브 코딩으로 빠르게 완성, 개인 개발·취미, 포트폴리오, 출시해서 수익, 게임잼, 공부)
  2. 만드는 방식: 코드를 누가 쓰는지(AI 에게 전부 맡김, AI 와 함께, 직접, 팀)와 쓰려는 AI 도구
  3. 플랫폼(모바일/PC/웹/콘솔)과 만들 것의 종류(게임/앱/웹)
  4. 장르·카테고리
  5. 테마와 세계: 소재, 배경, 세계관
  6. 분위기(아늑함, 긴장감, 쓸쓸함 등)
  7. 핵심 동사: 사용자가 가장 많이 반복할 행동(잇기, 쌓기, 피하기, 기록하기 등)
  8. 느끼게 할 감정: 끝났을 때 남길 감정
  9. 대상 사용자와 사용·플레이 상황(출퇴근, 잠들기 전, 친구와 함께 등)
  10. 닮고 싶은 작품과 그 작품에서 좋았던 점
  11. 피하고 싶은 것
  12. 시간과 예산: 개발 기간, 한 번 하는 시간(30초, 10분, 1시간), 쓸 수 있는 돈
  13. 배울 기술: 이번에 익히고 싶은 엔진·언어·기법
  14. 함께 만들기: 혼자 하는지, 함께 하는지(협동, 경쟁, 비동기 공유)와 개발 팀 구성
  15. 공개할 곳: 스토어, itch.io, 웹 링크, 친구에게만 등(수익 방식은 사용자가 꺼낼 때만 여기서 함께 묻습니다)
  16. 접근성: 한 손 조작, 색약, 짧은 집중 시간, 소리 없이도 할 수 있는지
- 목적과 만드는 방식은 질문의 결을 바꿉니다. 바이브 코딩이면 AI 가 한 번에 만들기 쉬운 범위·구조를 묻고, 개인 개발이면 오래 다듬을 재미와 배우고 싶은 기술을, 출시가 목적이면 대상과 차별점을 더 깊게 묻습니다.
- 질문 형식을 섞어 지루하지 않게 합니다: 둘 중 하나 고르기, 장면을 상상하게 하는 질문("이 게임을 처음 켠 10초 동안 무엇이 보이면 좋을까요?"), 기존 작품 비교, 하지 않을 것 고르기.
- 질문은 아이디어의 내용(장르, 핵심 경험, 소재·세계관, 분위기, 조작·주요 기능, 대상)을 바꾸는 영역을 먼저 묻습니다. 수익 방식·판매·마케팅·출시 계획처럼 컨셉과 거리가 먼 사업 질문은 사용자가 먼저 꺼내지 않는 한 묻지 않거나 맨 마지막에 하나만 묻습니다.
- 질문 수는 시작 메시지의 "질문 길이"를 따릅니다. 사용자가 아이디어를 요청하면 즉시 제안합니다.
- 시작 메시지에 "미리 정한 답"이 있으면 그 갈래는 이미 답을 받은 것으로 보고 묻지 않습니다. 첫 insight 에 미리 정한 답을 한 문장으로 반영합니다.
- 사용자가 "[요청][추가 질문]" 으로 질문을 더 원하면, 요청한 개수의 질문을 모두 마칠 때까지 아이디어를 내지 않습니다. 답변 끝에 "(추가 질문 n개 남음)" 이 붙어 있으면 아이디어 대신 다음 질문을 합니다.
- 사용자가 질문을 건너뛰면 그 영역은 당신이 합리적으로 판단합니다.

## 아이디어 품질
- 기존 작품을 그대로 베끼지 않은 독창적인 아이디어를 냅니다. 각 아이디어는 서로 확실히 달라야 합니다.
- 이 대화에서 이미 제안한 아이디어를 다시 내지 않습니다. 제목만 바꾸거나 같은 핵심 재미·같은 장르 조합을 되풀이하는 것도 같은 아이디어로 봅니다. 새로 받은 답이 있으면 그 답이 아이디어를 어떻게 바꿨는지 fit_reason 에 드러냅니다.
- title 은 기억에 남는 가제, logline 은 한 문장 소개입니다.
- core_hook 은 사용자가 계속하게 만드는 핵심 재미/가치, unique_point 는 비슷한 작품과의 차별점입니다.
- key_features 는 3~5개의 구체적인 기능입니다.
- scope 는 "소형", "중형", "대형" 중 하나(영어 응답이면 Small/Medium/Large), dev_time 은 사용자 상황 기준 예상 개발 기간, difficulty 는 1~5 정수입니다.
- fit_reason 은 사용자의 어떤 답 때문에 이 아이디어를 골랐는지 설명합니다.
- similar_works 에는 참고할 만한 실제 작품이나 서비스 2~3개를 "이름 — 무엇이 비슷하고 무엇이 다른지" 형식으로 적습니다. 확실하지 않은 작품은 지어내지 않습니다.
- web_search 도구가 있으면 아이디어를 낼 때에만 최대 3번 써서 similar_works 의 작품이 실제로 있는지, 비슷한 게임·앱이 이미 있는지 확인합니다. 질문할 때는 검색하지 않습니다.
- references 에는 검색으로 확인한 페이지의 제목과 URL 을 아이디어마다 0~3개 넣습니다. 검색 결과에 나온 URL 만 그대로 쓰고, 검색하지 않았으면 빈 배열로 둡니다.
- 사용자가 참고 이미지를 보냈다면 그림의 분위기·화면 구성·소재를 질문과 아이디어에 반영하고, insight 에 이미지에서 읽은 점을 한 번 언급합니다.
- fun_score 는 대상 사용자가 느낄 재미·가치의 크기, novelty_score 는 비슷한 작품과 비교한 새로움입니다. 둘 다 1~5 정수로 냉정하게 매기고, 네 아이디어에 모두 같은 점수를 주지 않습니다.
- risks 에는 이 아이디어의 가장 큰 위험 2개를 짧게 적고, validation 에는 1~2주 안에 아이디어를 검증할 수 있는 가장 싼 방법을 한 문장으로 적습니다.
- 사용자의 개발 경험과 규모에 맞게 실현 가능한 범위로 제안합니다.
""".trimIndent()

    fun designSystem(lang: ReplyLanguage, depth: DocDepth): String = """
당신은 'Ember' 앱의 수석 기획자입니다. 사용자가 고른 아이디어를 실제로 개발에 착수할 수 있는 설계로 다듬기 위해, 설계에 필요한 결정을 객관식 카드 질문으로 하나씩 받습니다.

## 응답 규칙
- 모든 응답은 주어진 JSON 스키마를 그대로 따릅니다. 사용자에게 보이는 모든 문장은 ${lang.promptName}로 씁니다.
- kind 가 "question" 이면 question 을 채우고 ready_summary 는 빈 문자열로 둡니다.
- 필요한 결정을 모두 받았으면 kind 를 "ready" 로 하고, ready_summary 에 확정된 결정 사항을 글머리표 목록으로 정리합니다. 이때 question 은 title 과 options 를 비운 빈 질문으로 둡니다.
- 질문은 약 ${depth.designQuestions}개 이내로 합니다. 사용자가 바로 설계서를 원하면 즉시 "ready" 로 답합니다.
- stage 는 지금 정하는 영역을 2~6글자로 적습니다(예: "핵심 루프", "아트", "기술", "화면", "진행", "수익", "MVP").
- progress 는 설계 결정의 진행률(0~100), insight 는 지금까지 정해진 방향을 한 문장으로 요약합니다(주어와 서술어를 갖춘 문장).
- 한국어로 쓸 때 사용자에게 보이는 문장은 모두 해요체("~해요", "~정했어요")로 씁니다.

## 질문 설계
- 이 아이디어를 구현할 때 실제로 갈리는 결정만 묻습니다(예: 핵심 루프의 형태, 조작 방식, 아트 스타일, 엔진·프레임워크, 화면 구성, 저장/계정 방식, 진행·보상 구조, 수익 모델, 첫 버전 범위).
- 선택지는 3~5개, label 은 짧게, description 은 그 선택의 장단점을 한 줄로 씁니다.
- 추천하는 선택지가 있으면 description 앞에 "${if (lang == ReplyLanguage.KO) "추천" else "Recommended"} · " 을 붙입니다(하나만). 사용자의 개발 경험·도구에 맞춰 추천합니다.
""".trimIndent()

    fun documentSystem(lang: ReplyLanguage, kind: ProjectKind, depth: DocDepth): String {
        val isGame = kind == ProjectKind.GAME
        val sections = if (isGame) GAME_SECTIONS else APP_SECTIONS
        val length = when (depth) {
            DocDepth.BRIEF -> "핵심만 담은 2~3쪽 분량(각 섹션 3~6줄)"
            DocDepth.STANDARD -> "충분히 구체적인 5~8쪽 분량"
            DocDepth.BUILD_READY -> "개발자가 추가 질문 없이 바로 착수할 수 있을 만큼 완전한 10쪽 이상 분량(수치·목록·표를 적극 사용)"
        }
        return """
당신은 'Ember' 앱의 수석 기획자입니다. 사용자와 함께 정한 내용을 바탕으로 ${if (isGame) "게임" else "앱/서비스"} 설계서를 Markdown 으로 작성합니다.

## 작성 규칙
- ${lang.promptName}로 씁니다. 분량은 $length 입니다.
- 첫 줄은 "# " 로 시작하는 제목(가제)입니다. 그 아래 한 줄 소개를 인용문("> ")으로 씁니다.
- 아래 섹션을 "## " 제목으로 순서대로 씁니다. 필요하면 "### " 하위 제목을 씁니다.
$sections
- 결정되지 않은 부분은 합리적인 기본안을 정해 쓰고, 해당 문장 끝에 "(제안)" 이라고 표시합니다.
- 기능 명세는 우선순위(필수/권장/나중)를 표로 정리합니다.
- 기술 설계에는 폴더 구조(코드 블록), 핵심 모듈·클래스와 책임, 저장 데이터 형식, 외부 의존성을 구체적으로 적습니다. 표는 GitHub Markdown 표 문법을 씁니다.
- 숫자(시간, 개수, 가격, 기간)를 가능한 한 구체적으로 적습니다. 모호한 형용사만으로 설명하지 않습니다.
- 마지막 섹션 "다음 단계"에는 Claude 에게 바로 맡길 수 있는 첫 작업 3개를 구체적인 요청 문장으로 적습니다.
- 개발자 프로필의 경험이 적거나 입력되지 않았으면, 전문 용어(파일 형식, 엔진 개념, 아키텍처 용어)가 처음 나올 때 괄호 안에 쉬운 설명을 한 줄로 붙입니다.
- 서론이나 맺음말 없이 설계서 본문만 출력합니다.
""".trimIndent()
    }

    private val GAME_SECTIONS = """
  1. 한눈에 보기 (장르, 플랫폼, 대상, 플레이 시간, 엔진, 개발 규모를 표로)
  2. 핵심 재미와 게임 루프 (30초/5분/1시간 루프)
  3. 조작과 핵심 메커닉
  4. 콘텐츠 구성 (스테이지/레벨/아이템/적 등 수치 포함)
  5. 진행·보상·밸런스 구조
  6. 화면 구성과 UI 흐름
  7. 아트·사운드 방향
  8. 기술 설계 (엔진, 폴더 구조, 주요 시스템/클래스, 저장 방식)
  9. 수익 모델
  10. 개발 로드맵 (마일스톤별 산출물)
  11. 리스크와 대응
  12. 다음 단계
""".trimEnd()

    private val APP_SECTIONS = """
  1. 한눈에 보기 (카테고리, 플랫폼, 대상, 핵심 가치, 기술 스택, 개발 규모를 표로)
  2. 문제와 해결 (사용자가 겪는 문제, 이 앱의 해결 방식)
  3. 대상 사용자와 사용 시나리오 (사용자 스토리 "~로서 ~하고 싶다, 그래야 ~" 형식 5개 이상)
  4. 기능 명세 (우선순위 표, 기능별 수용 기준 포함)
  5. 화면 구성과 사용자 흐름
  6. 데이터 모델 (주요 엔티티와 필드)
  7. 기술 설계 (아키텍처, 스택, 외부 API, 저장·동기화, 보안)
  8. UI·브랜드 방향
  9. 수익 모델과 성공 지표 (출시 후 측정할 핵심 지표 3개와 목표치)
  10. 개발 로드맵 (마일스톤별 산출물, MVP 범위와 범위 밖)
  11. 리스크와 대응
  12. 열린 질문과 다음 단계
""".trimEnd()

    // ---------------------------------------------------------------- 사용자 메시지

    fun kindLabel(kind: ProjectKind, lang: ReplyLanguage): String = when (lang) {
        ReplyLanguage.KO -> when (kind) {
            ProjectKind.GAME -> "게임"
            ProjectKind.APP -> "앱"
            ProjectKind.WEB -> "웹 서비스"
            ProjectKind.ANY -> "아직 정하지 않음(게임/앱/웹 모두 가능)"
        }
        ReplyLanguage.EN -> when (kind) {
            ProjectKind.GAME -> "Game"
            ProjectKind.APP -> "App"
            ProjectKind.WEB -> "Web service"
            ProjectKind.ANY -> "Undecided (game, app or web)"
        }
    }

    fun profileBlock(profile: DevProfile): String {
        if (profile.isEmpty()) return "개발자 프로필: (입력되지 않음)"
        return buildString {
            appendLine("개발자 프로필:")
            if (profile.experience.isNotBlank()) appendLine("- 개발 경험: ${profile.experience}")
            if (profile.tools.isNotEmpty()) appendLine("- 사용 가능한 도구/엔진: ${profile.tools.joinToString(", ")}")
            if (profile.team.isNotBlank()) appendLine("- 팀 구성: ${profile.team}")
            if (profile.notes.isNotBlank()) appendLine("- 기타: ${profile.notes}")
        }.trimEnd()
    }

    fun depthLine(depth: DepthMode): String = when (depth) {
        DepthMode.SHORT -> "질문 길이: 짧게. 가장 중요한 질문 ${depth.questions}개 안팎만 하고 아이디어를 제안해 주세요."
        DepthMode.NORMAL -> "질문 길이: 보통. 질문 ${depth.questions}개 안팎 뒤에 아이디어를 제안해 주세요."
        DepthMode.LONG -> "질문 길이: 길게. 사용자가 아이디어를 요청할 때까지 질문 갈래를 넓고 깊게 이어 가 주세요. 갈래를 다 다루면 앞의 답을 더 구체적으로 파고드는 질문을 합니다. progress 는 90 을 넘기지 마세요."
    }

    fun presetBlock(presets: List<PresetAnswer>): String =
        if (presets.isEmpty()) "" else "미리 정한 답(이 갈래는 다시 묻지 마세요):\n" + presets.joinToString("\n") { "- ${it.category}: ${it.value}" }

    fun startMessage(
        kind: ProjectKind,
        seed: String,
        profile: DevProfile,
        lang: ReplyLanguage,
        imageCount: Int = 0,
        presets: List<PresetAnswer> = emptyList(),
        depth: DepthMode = DepthMode.NORMAL,
    ): String = buildString {
        appendLine("[시작] 새 아이디어 탐색을 시작합니다.")
        appendLine("관심 분야: ${kindLabel(kind, lang)}")
        appendLine("떠오른 생각: ${seed.trim().ifEmpty { "(없음)" }}")
        if (imageCount > 0) appendLine("참고 이미지: ${imageCount}장을 함께 보냅니다. 분위기·화면 구성·소재를 참고해 주세요.")
        if (presets.isNotEmpty()) appendLine(presetBlock(presets))
        appendLine(depthLine(depth))
        appendLine(profileBlock(profile))
        append("첫 질문을 해 주세요.")
    }

    /** 화면에 보이는 선택지 기호(A, B, C …). */
    fun optionLetter(index: Int): String = ('A' + index).toString()

    fun answerMessage(question: Question, answer: Answer): String {
        if (answer.skipped) return "[건너뜀] \"${question.title}\" 질문은 건너뛰겠습니다. 이 부분은 알아서 판단해 주세요."
        val picked = question.options.withIndex().filter { it.value.id in answer.selectedIds }
        return buildString {
            appendLine("[답변] ${question.title}")
            if (picked.isNotEmpty()) appendLine("선택: ${picked.joinToString(", ") { "${optionLetter(it.index)}) ${it.value.label}" }}")
            if (picked.size > 1 && !question.multiSelect) appendLine("(하나만 고르는 질문이었지만 여러 개를 함께 골랐어요. 고른 것을 모두 반영해 주세요.)")
            if (answer.customText.isNotBlank()) {
                appendLine("직접 입력: ${answer.customText.trim()}")
                // 직접 입력에서 "B처럼", "b+e" 같이 기호로 가리킬 수 있으므로 기호와 선택지를 함께 알려 준다.
                appendLine("(화면의 선택지 기호: " + question.options.withIndex().joinToString(", ") { "${optionLetter(it.index)}) ${it.value.label}" } + ")")
            }
        }.trimEnd()
    }

    /**
     * 직접 입력이 선택지 기호만으로 되어 있으면(예: "b+e", "A, C", "b와 e", "2 4") 그 선택지들의 순번을 돌려준다.
     * 기호가 아닌 글이 섞여 있거나 없는 기호를 가리키면 null(글 그대로 보낸다).
     */
    fun lettersIn(text: String, optionCount: Int): List<Int>? {
        val t = text.trim()
        if (t.isEmpty() || optionCount <= 0) return null
        val tokens = t.split(Regex("[\\s+,/&·.]+|와|과|랑|하고|그리고|and|AND|And"))
            .map { it.trim().removeSuffix(")").removePrefix("(") }
            .filter { it.isNotEmpty() }
        if (tokens.isEmpty()) return null
        val idx = tokens.map { tok ->
            when {
                tok.length == 1 && tok[0].uppercaseChar() in 'A'..'Z' -> tok[0].uppercaseChar() - 'A'
                tok.toIntOrNull() != null -> tok.toInt() - 1
                else -> return null
            }
        }
        if (idx.any { it !in 0 until optionCount }) return null
        return idx.distinct()
    }

    /** 사용자가 적은 컨셉을 지키며 질문 없이 아이디어를 받는다. */
    const val REQUEST_CONCEPT_IDEAS = "[요청][컨셉] 위 '떠오른 생각'은 사용자가 직접 적은 컨셉이에요. 질문 없이 이 컨셉으로 아이디어 4개를 바로 제안해 주세요. " +
        "컨셉에 적힌 것(장르, 소재, 분위기, 플랫폼, 핵심 재미, 조작, 대상 등)은 바꾸지 말고 그대로 지켜 주세요. " +
        "컨셉에서 정하지 않은 부분만 아이디어마다 서로 다르게 정해서 네 가지 다른 방향으로 구체화해 주세요. " +
        "ideas_intro 에는 컨셉에서 무엇을 지켰고 아이디어마다 무엇을 다르게 정했는지 한 문장으로 적고, fit_reason 에는 컨셉의 어느 부분을 어떻게 살렸는지 적어 주세요."
    const val REQUEST_QUICK_IDEAS = "[요청] 질문 없이 지금 알려 준 정보만으로 아이디어 4개를 바로 제안해 주세요. 정보가 부족한 부분은 다양하게 가정해서 서로 다른 방향의 아이디어를 내 주세요."
    const val REQUEST_IDEAS_NOW = "[요청] 지금까지의 답변을 바탕으로 아이디어 4개를 바로 제안해 주세요."
    /** '질문 더 받기'로 한 번에 더 묻는 질문 수. */
    const val EXTRA_QUESTIONS = 3
    const val TAG_MORE_QUESTIONS = "[요청][추가 질문]"
    const val TAG_FRESH_IDEAS = "[요청][새 아이디어]"
    const val TAG_DUPLICATE = "[요청][중복]"

    fun moreIdeasMessage(previousTitles: List<String>): String =
        "[요청] 앞에서 제안한 아이디어와 겹치지 않는 새로운 아이디어 4개를 제안해 주세요." + avoidLine(previousTitles)

    /** 아이디어를 본 뒤 질문을 더 받는다. 컨셉을 좁히는 질문만, 정해진 개수만큼. */
    fun moreQuestionsMessage(askedTitles: List<String>, previousTitles: List<String>): String = buildString {
        append("$TAG_MORE_QUESTIONS 아이디어를 내 취향에 더 정확히 맞추고 싶어요. ")
        append("아이디어의 컨셉 자체를 바꾸는 질문을 ${EXTRA_QUESTIONS}개, 한 번에 하나씩 이어서 해 주세요. 지금은 첫 번째 질문만 보내 주세요. ")
        append("핵심 플레이·사용 경험, 소재와 세계관, 분위기, 조작이나 주요 기능, 영감을 준 작품, 피하고 싶은 요소처럼 아이디어 내용이 달라지는 영역에서 고르고, ")
        append("수익·판매·마케팅·출시 계획처럼 컨셉과 거리가 먼 질문은 하지 마세요. 앞에서 낸 아이디어 중 사용자가 무엇을 더 원하는지 가려낼 수 있는 질문이면 더 좋아요.")
        if (askedTitles.isNotEmpty()) append("\n이미 한 질문(다시 묻지 마세요): " + askedTitles.joinToString(" / "))
        append(avoidLine(previousTitles))
    }

    /** 추가 질문을 마쳤거나 중간에 그만둘 때 보내는 새 아이디어 요청. */
    fun freshIdeasMessage(previousTitles: List<String>): String =
        "$TAG_FRESH_IDEAS 방금 추가로 답한 내용을 꼭 반영해서 아이디어 4개를 새로 제안해 주세요. 추가 답변이 아이디어를 어떻게 바꿨는지 ideas_intro 에 한 문장으로 적어 주세요." + avoidLine(previousTitles)

    /** 받은 아이디어가 앞에서 낸 것과 겹칠 때 한 번 더 요청한다. */
    fun duplicateMessage(duplicates: List<String>, previousTitles: List<String>): String =
        "$TAG_DUPLICATE 방금 낸 아이디어 중 ${duplicates.joinToString(", ") { "\"$it\"" }} 는 앞에서 이미 제안한 아이디어와 같아요. 이전 아이디어와 제목·핵심 재미·장르 조합이 모두 다른 새 아이디어 4개를 다시 제안해 주세요." + avoidLine(previousTitles)

    private fun avoidLine(titles: List<String>): String =
        if (titles.isEmpty()) "" else "\n이미 제안한 아이디어(다시 내지 마세요): " + titles.joinToString(", ")

    /** 추가 질문 중 답변 끝에 붙여 아이디어 대신 다음 질문을 하게 한다. */
    fun remainingNote(left: Int): String = "\n(추가 질문 ${left}개 남음: 아이디어 대신 다음 질문을 해 주세요.)"

    const val REQUEST_MORE_IDEAS = "[요청] 앞에서 제안한 아이디어와 겹치지 않는 새로운 아이디어 4개를 제안해 주세요."
    const val REQUEST_MORE_QUESTIONS = "$TAG_MORE_QUESTIONS 아이디어를 내 취향에 더 정확히 맞추고 싶어요. 컨셉을 바꾸는 질문을 이어서 해 주세요."
    const val REQUEST_READY_NOW = "[요청] 질문은 충분합니다. 지금까지 정한 내용으로 ready 를 보내 주세요. 정하지 않은 부분은 추천안으로 정리해 주세요."

    fun variationMessage(idea: Idea, direction: String): String =
        "[요청] \"${idea.title}\" 아이디어를 바탕으로 다음 방향을 반영한 변형 아이디어 4개를 제안해 주세요: ${direction.trim()}"

    fun combineMessage(a: Idea, b: Idea): String =
        "[요청] \"${a.title}\" 와 \"${b.title}\" 의 장점을 섞은 새로운 아이디어 4개를 제안해 주세요."

    fun ideaBrief(idea: Idea): String = buildString {
        appendLine("### ${idea.title}")
        appendLine(idea.logline)
        if (idea.category.isNotBlank() || idea.genre.isNotBlank()) appendLine("- 분류: ${listOf(idea.category, idea.genre).filter { it.isNotBlank() }.joinToString(" / ")}")
        if (idea.platforms.isNotEmpty()) appendLine("- 플랫폼: ${idea.platforms.joinToString(", ")}")
        if (idea.targetAudience.isNotBlank()) appendLine("- 대상: ${idea.targetAudience}")
        if (idea.coreHook.isNotBlank()) appendLine("- 핵심 재미/가치: ${idea.coreHook}")
        if (idea.keyFeatures.isNotEmpty()) appendLine("- 주요 기능: ${idea.keyFeatures.joinToString("; ")}")
        if (idea.uniquePoint.isNotBlank()) appendLine("- 차별점: ${idea.uniquePoint}")
        if (idea.monetization.isNotBlank()) appendLine("- 수익: ${idea.monetization}")
        if (idea.scope.isNotBlank() || idea.devTime.isNotBlank()) appendLine("- 규모: ${idea.scope} · ${idea.devTime} · 난이도 ${idea.difficulty}/5")
    }.trimEnd()

    fun interviewBrief(turns: List<Turn>, presets: List<PresetAnswer> = emptyList()): String =
        (presets.map { "- ${it.category} → ${it.value}" } + turns
            .filter { it.answer != null && !it.answer.skipped }
            .map { "- ${it.question.title} → ${it.answerSummary()}" })
            .joinToString("\n")
            .ifEmpty { "- (답변 없음)" }

    fun designStartMessage(project: Project, idea: Idea, profile: DevProfile, lang: ReplyLanguage): String = buildString {
        appendLine("[설계 시작] 아래 아이디어를 개발 가능한 설계로 다듬고 싶습니다.")
        appendLine("관심 분야: ${kindLabel(project.kind, lang)}")
        appendLine()
        appendLine("## 고른 아이디어")
        appendLine(ideaBrief(idea))
        appendLine()
        appendLine("## 아이디어 탐색 때의 답변")
        appendLine(interviewBrief(project.turns, project.presets))
        appendLine()
        appendLine(profileBlock(profile))
        append("설계에 필요한 첫 질문을 해 주세요.")
    }

    fun documentRequest(project: Project, idea: Idea, profile: DevProfile, lang: ReplyLanguage): String = buildString {
        val d = project.design
        appendLine("아래 내용으로 설계서를 작성해 주세요.")
        appendLine("관심 분야: ${kindLabel(project.kind, lang)}")
        appendLine()
        appendLine("## 고른 아이디어")
        appendLine(ideaBrief(idea))
        appendLine()
        appendLine("## 아이디어 탐색 때의 답변")
        appendLine(interviewBrief(project.turns, project.presets))
        if (d != null && d.turns.any { it.answer != null }) {
            appendLine()
            appendLine("## 설계 질문에 대한 결정")
            appendLine(interviewBrief(d.turns))
        }
        if (d != null && d.readySummary.isNotBlank()) {
            appendLine()
            appendLine("## 확정된 결정 요약")
            appendLine(d.readySummary)
        }
        appendLine()
        append(profileBlock(profile))
    }

    fun revisionRequest(instruction: String): String =
        "[수정 요청] 위 설계서를 다음 요청에 맞게 고쳐서 설계서 전체를 다시 출력해 주세요. 요청과 관계없는 부분은 그대로 유지합니다.\n요청: ${instruction.trim()}"

    /** 작성 중 화면에서 미리 보여 줄 섹션 계획(제목만). */
    fun plannedSections(kind: ProjectKind, korean: Boolean): List<String> {
        if (korean) {
            val src = if (kind == ProjectKind.GAME) GAME_SECTIONS else APP_SECTIONS
            return src.lines().map { it.trim() }.filter { it.firstOrNull()?.isDigit() == true }
                .map { it.substringAfter(". ").substringBefore(" (").trim() }
        }
        return if (kind == ProjectKind.GAME) listOf("At a glance", "Core fun & game loop", "Controls & mechanics", "Content", "Progression & balance", "Screens & UI flow", "Art & sound", "Technical design", "Monetization", "Roadmap", "Risks", "Open questions & next steps")
        else listOf("At a glance", "Problem & solution", "Users & scenarios", "Feature spec", "Screens & flows", "Data model", "Technical design", "UI & brand", "Monetization & metrics", "Roadmap", "Risks", "Open questions & next steps")
    }

    // ---------------------------------------------------------------- Markdown 유틸

    /** 설계서 Markdown 에서 "## " 섹션 제목을 순서대로 뽑는다(목차용). */
    fun sectionTitles(markdown: String): List<String> = markdown.lineSequence()
        .filter { it.startsWith("## ") }
        .map { it.removePrefix("## ").trim() }
        .toList()

    fun documentTitle(markdown: String): String? = markdown.lineSequence()
        .firstOrNull { it.startsWith("# ") }
        ?.removePrefix("# ")?.trim()?.takeIf { it.isNotEmpty() }
}
