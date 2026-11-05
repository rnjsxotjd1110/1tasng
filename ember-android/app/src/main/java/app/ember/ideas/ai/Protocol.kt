package app.ember.ideas.ai

import app.ember.ideas.data.Answer
import app.ember.ideas.data.DevProfile
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
            ideas = reply.ideas.mapIndexed { i, idea ->
                idea.copy(
                    id = idea.id.ifBlank { "idea${i + 1}" },
                    difficulty = idea.difficulty.coerceIn(1, 5),
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
            put("items", obj("id" to str(), "label" to str(), "description" to str(), "emoji" to str()))
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
        "fit_reason" to str(),
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

## 질문 설계
- 질문은 한 번에 하나만 합니다. 이미 답을 알 수 있는 내용은 다시 묻지 않습니다.
- 선택지는 4~6개를 주며 서로 겹치지 않게 구체적으로 씁니다. label 은 짧게(최대 18자), description 은 한 줄 설명(최대 40자)입니다.
- emoji 에는 선택지를 상징하는 이모지 1개를 넣습니다.
- 여러 개를 고르는 것이 자연스러운 질문(장르 취향, 영감을 받은 작품, 기능 등)은 multi_select 를 true 로 합니다.
- allow_custom 은 대부분 true 로 두고, custom_hint 에 직접 입력 예시를 적습니다.
- subtitle 에는 이 질문을 왜 하는지 한 문장으로 적습니다.
- 다루어야 할 영역(상황에 맞게 순서와 생략을 조절): 만들 것의 종류(게임/앱/웹), 플랫폼(모바일/PC/웹/콘솔), 대상 사용자, 장르·카테고리, 분위기·테마, 핵심 경험, 개발 규모(혼자/팀, 기간), 사용 기술·엔진, 수익 방식, 영감을 준 작품, 피하고 싶은 것.
- 보통 6~9개의 질문 뒤에 아이디어를 제안합니다. 사용자가 아이디어를 요청하면 즉시 제안합니다.
- 사용자가 질문을 건너뛰면 그 영역은 당신이 합리적으로 판단합니다.

## 아이디어 품질
- 기존 작품을 그대로 베끼지 않은 독창적인 아이디어를 냅니다. 각 아이디어는 서로 확실히 달라야 합니다.
- title 은 기억에 남는 가제, logline 은 한 문장 소개입니다.
- core_hook 은 사용자가 계속하게 만드는 핵심 재미/가치, unique_point 는 비슷한 작품과의 차별점입니다.
- key_features 는 3~5개의 구체적인 기능입니다.
- scope 는 "소형", "중형", "대형" 중 하나(영어 응답이면 Small/Medium/Large), dev_time 은 사용자 상황 기준 예상 개발 기간, difficulty 는 1~5 정수입니다.
- fit_reason 은 사용자의 어떤 답 때문에 이 아이디어를 골랐는지 설명합니다.
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

## 질문 설계
- 이 아이디어를 구현할 때 실제로 갈리는 결정만 묻습니다(예: 핵심 루프의 형태, 조작 방식, 아트 스타일, 엔진·프레임워크, 화면 구성, 저장/계정 방식, 진행·보상 구조, 수익 모델, 첫 버전 범위).
- 선택지는 3~5개, label 은 짧게, description 은 그 선택의 장단점을 한 줄로 씁니다. emoji 1개를 넣습니다.
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
- 기능 명세는 우선순위(필수/권장/나중)를 표로 정리합니다. 표는 GitHub Markdown 표 문법을 씁니다.
- 숫자(시간, 개수, 가격, 기간)를 가능한 한 구체적으로 적습니다. 모호한 형용사만으로 설명하지 않습니다.
- 마지막 섹션 "다음 단계"에는 Claude 에게 바로 맡길 수 있는 첫 작업 3개를 구체적인 요청 문장으로 적습니다.
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
  3. 대상 사용자와 사용 시나리오
  4. 기능 명세 (우선순위 표 포함)
  5. 화면 구성과 사용자 흐름
  6. 데이터 모델 (주요 엔티티와 필드)
  7. 기술 설계 (아키텍처, 스택, 외부 API, 저장·동기화, 보안)
  8. UI·브랜드 방향
  9. 수익 모델
  10. 개발 로드맵 (마일스톤별 산출물)
  11. 리스크와 대응
  12. 다음 단계
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

    fun startMessage(kind: ProjectKind, seed: String, profile: DevProfile, lang: ReplyLanguage): String = buildString {
        appendLine("[시작] 새 아이디어 탐색을 시작합니다.")
        appendLine("관심 분야: ${kindLabel(kind, lang)}")
        appendLine("떠오른 생각: ${seed.trim().ifEmpty { "(없음)" }}")
        appendLine(profileBlock(profile))
        append("첫 질문을 해 주세요.")
    }

    fun answerMessage(question: Question, answer: Answer): String {
        if (answer.skipped) return "[건너뜀] \"${question.title}\" 질문은 건너뛰겠습니다. 이 부분은 알아서 판단해 주세요."
        val labels = question.options.filter { it.id in answer.selectedIds }.map { it.label }
        return buildString {
            appendLine("[답변] ${question.title}")
            if (labels.isNotEmpty()) appendLine("선택: ${labels.joinToString(", ")}")
            if (answer.customText.isNotBlank()) appendLine("직접 입력: ${answer.customText.trim()}")
        }.trimEnd()
    }

    const val REQUEST_IDEAS_NOW = "[요청] 지금까지의 답변을 바탕으로 아이디어 4개를 바로 제안해 주세요."
    const val REQUEST_MORE_IDEAS = "[요청] 앞에서 제안한 아이디어와 겹치지 않는 새로운 아이디어 4개를 제안해 주세요."
    const val REQUEST_MORE_QUESTIONS = "[요청] 아이디어를 더 정확하게 맞추고 싶습니다. 아직 묻지 않은 중요한 질문을 이어서 해 주세요."
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

    fun interviewBrief(turns: List<Turn>): String = turns
        .filter { it.answer != null && !it.answer.skipped }
        .joinToString("\n") { "- ${it.question.title} → ${it.answerSummary()}" }
        .ifEmpty { "- (답변 없음)" }

    fun designStartMessage(project: Project, idea: Idea, profile: DevProfile, lang: ReplyLanguage): String = buildString {
        appendLine("[설계 시작] 아래 아이디어를 개발 가능한 설계로 다듬고 싶습니다.")
        appendLine("관심 분야: ${kindLabel(project.kind, lang)}")
        appendLine()
        appendLine("## 고른 아이디어")
        appendLine(ideaBrief(idea))
        appendLine()
        appendLine("## 아이디어 탐색 때의 답변")
        appendLine(interviewBrief(project.turns))
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
        appendLine(interviewBrief(project.turns))
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
