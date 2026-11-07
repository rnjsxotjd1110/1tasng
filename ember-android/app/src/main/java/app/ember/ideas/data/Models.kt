package app.ember.ideas.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 사용자가 처음에 고르는 관심 분야. ANY 는 "아직 모르겠어요". */
@Serializable
enum class ProjectKind { GAME, APP, WEB, ANY }

/** 프로젝트가 지금 어느 단계에 있는지. 화면 분기의 기준이 된다. */
@Serializable
enum class ProjectStage { INTERVIEW, IDEAS, DESIGN_INTERVIEW, DOCUMENT }

/** 설계서 깊이. 질문 수와 문서 분량을 함께 결정한다. */
@Serializable
enum class DocDepth(val designQuestions: Int) {
    BRIEF(3),
    STANDARD(6),
    BUILD_READY(9),
}

@Serializable
data class QuestionOption(
    val id: String,
    val label: String,
    val description: String = "",
    val emoji: String = "",
)

@Serializable
data class Question(
    val title: String,
    val subtitle: String = "",
    @SerialName("multi_select") val multiSelect: Boolean = false,
    val options: List<QuestionOption> = emptyList(),
    @SerialName("allow_custom") val allowCustom: Boolean = true,
    @SerialName("custom_hint") val customHint: String = "",
)

@Serializable
data class Answer(
    val selectedIds: List<String> = emptyList(),
    val customText: String = "",
    val skipped: Boolean = false,
) {
    fun isEmpty(): Boolean = !skipped && selectedIds.isEmpty() && customText.isBlank()
}

/** 인터뷰의 한 단계: Claude 가 낸 질문과 사용자의 답. */
@Serializable
data class Turn(
    val stage: String = "",
    val progress: Int = 0,
    val insight: String = "",
    val question: Question,
    val answer: Answer? = null,
    /** 이 질문이 나왔을 때의 남은 추가 질문 수(되돌리기에서 그대로 되살린다). */
    val extraLeft: Int = -1,
) {
    fun answerSummary(): String {
        val a = answer ?: return ""
        if (a.skipped) return ""
        val labels = question.options.filter { it.id in a.selectedIds }.map { it.label }
        return (labels + listOfNotNull(a.customText.trim().takeIf { it.isNotEmpty() })).joinToString(", ")
    }
}

@Serializable
data class Idea(
    val id: String,
    val title: String,
    val logline: String,
    val category: String = "",
    val platforms: List<String> = emptyList(),
    val genre: String = "",
    @SerialName("target_audience") val targetAudience: String = "",
    @SerialName("core_hook") val coreHook: String = "",
    @SerialName("key_features") val keyFeatures: List<String> = emptyList(),
    @SerialName("unique_point") val uniquePoint: String = "",
    val monetization: String = "",
    val scope: String = "",
    @SerialName("dev_time") val devTime: String = "",
    val difficulty: Int = 3,
    @SerialName("fit_reason") val fitReason: String = "",
    @SerialName("similar_works") val similarWorks: List<String> = emptyList(),
    val risks: List<String> = emptyList(),
    val validation: String = "",
    /** 웹 검색으로 확인한 참고 페이지. 검색 결과에 실제로 있던 주소만 남긴다. */
    val references: List<Reference> = emptyList(),
    /** 재미 점수(1~5). 0 이면 이전 버전에서 받은 아이디어라 점수가 없다. */
    @SerialName("fun_score") val funScore: Int = 0,
    /** 새로움 점수(1~5). 0 이면 점수 없음. */
    @SerialName("novelty_score") val noveltyScore: Int = 0,
)

@Serializable
data class Reference(val title: String = "", val url: String = "")

@Serializable
data class IdeaBatch(
    val id: String,
    val createdAt: Long,
    val intro: String = "",
    val label: String = "",
    val ideas: List<Idea> = emptyList(),
    /** '질문 더 받기'로 추가 답변을 반영해 받은 묶음. */
    val fromExtraQuestions: Boolean = false,
)

/** API 로 그대로 다시 보내는 대화 기록. assistant 는 Claude 가 돌려준 원문(JSON)을 보관한다. */
@Serializable
data class ChatMessage(
    val role: String,
    val text: String,
    /** 함께 보낼 참고 이미지(앱 저장소의 JPEG 절대 경로). 첫 메시지에만 붙는다. */
    val images: List<String> = emptyList(),
) {
    companion object {
        const val USER = "user"
        const val ASSISTANT = "assistant"
    }
}

@Serializable
data class DocVersion(
    val id: String,
    val createdAt: Long,
    val note: String,
    val markdown: String,
    val complete: Boolean = true,
)

@Serializable
data class DesignState(
    val ideaId: String,
    val depth: DocDepth = DocDepth.STANDARD,
    val turns: List<Turn> = emptyList(),
    val messages: List<ChatMessage> = emptyList(),
    val readySummary: String = "",
    val versions: List<DocVersion> = emptyList(),
) {
    val latest: DocVersion? get() = versions.lastOrNull()
}

@Serializable
data class Usage(
    val inputTokens: Long = 0,
    val outputTokens: Long = 0,
    val cacheReadTokens: Long = 0,
    val cacheWriteTokens: Long = 0,
    val costUsd: Double = 0.0,
    val requests: Int = 0,
) {
    operator fun plus(o: Usage) = Usage(
        inputTokens + o.inputTokens,
        outputTokens + o.outputTokens,
        cacheReadTokens + o.cacheReadTokens,
        cacheWriteTokens + o.cacheWriteTokens,
        costUsd + o.costUsd,
        requests + o.requests,
    )
}

@Serializable
data class Project(
    val id: String,
    val title: String,
    val kind: ProjectKind,
    val seed: String = "",
    val createdAt: Long,
    val updatedAt: Long,
    val favorite: Boolean = false,
    val stage: ProjectStage = ProjectStage.INTERVIEW,
    val turns: List<Turn> = emptyList(),
    val messages: List<ChatMessage> = emptyList(),
    val ideaBatches: List<IdeaBatch> = emptyList(),
    val savedIdeaIds: List<String> = emptyList(),
    val design: DesignState? = null,
    val usage: Usage = Usage(),
    val isSample: Boolean = false,
    val isDemo: Boolean = false,
    val titleEdited: Boolean = false,
    val note: String = "",
    /** 처음에 함께 보낸 참고 이미지(앱 저장소 경로). */
    val images: List<String> = emptyList(),
    /** '질문 더 받기' 중이면 지금 질문 뒤에 남은 추가 질문 수. 추가 질문 중이 아니면 -1. */
    val extraQuestionsLeft: Int = -1,
    /** 지금 설계 중이 아닌 다른 아이디어의 설계서. 다른 아이디어로 설계를 시작해도 이전 설계서를 잃지 않게 보관한다. */
    val otherDesigns: Map<String, DesignState> = emptyMap(),
    /** 거푸집으로 미리 정해 두어 묻지 않고 넘어간 답. */
    val presets: List<PresetAnswer> = emptyList(),
    /** 고른 거푸집 이름(없으면 빈 문자열). */
    val moldName: String = "",
    /** 질문을 얼마나 이어 갈지. */
    val depthMode: DepthMode = DepthMode.NORMAL,
    /** 원석함의 메모에서 시작했으면 그 메모 id. */
    val memoId: String? = null,
    /** 사용자가 지운 아이디어 제목. 같은 아이디어를 다시 제안하지 않게 기억해 둔다. */
    val discardedTitles: List<String> = emptyList(),
    /** 사용자가 적은 컨셉으로 질문 없이 바로 아이디어를 받은 프로젝트. */
    val conceptMode: Boolean = false,
) {
    /** 이 아이디어로 만든 설계서가 있으면 돌려준다(지금 설계 중인 것 포함). */
    fun designFor(ideaId: String): DesignState? =
        design?.takeIf { it.ideaId == ideaId && it.latest != null } ?: otherDesigns[ideaId]?.takeIf { it.latest != null }

    val inExtraQuestions: Boolean get() = extraQuestionsLeft >= 0

    val allIdeas: List<Idea> get() = ideaBatches.flatMap { it.ideas }
    fun idea(id: String): Idea? = allIdeas.firstOrNull { it.id == id }
    val selectedIdea: Idea? get() = design?.let { idea(it.ideaId) }
    val currentTurn: Turn? get() = turns.lastOrNull()?.takeIf { it.answer == null }
    val answeredCount: Int get() = turns.count { it.answer != null }
}

/** 사용자가 설정에 적어 두는 개발자 프로필. 매 인터뷰에 배경 정보로 들어간다. */
@Serializable
data class DevProfile(
    val experience: String = "",
    val tools: List<String> = emptyList(),
    val team: String = "",
    val notes: String = "",
) {
    fun isEmpty() = experience.isBlank() && tools.isEmpty() && team.isBlank() && notes.isBlank()
}
