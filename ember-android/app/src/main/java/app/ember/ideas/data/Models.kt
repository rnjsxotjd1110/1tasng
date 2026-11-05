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
)

@Serializable
data class IdeaBatch(
    val id: String,
    val createdAt: Long,
    val intro: String = "",
    val label: String = "",
    val ideas: List<Idea> = emptyList(),
)

/** API 로 그대로 다시 보내는 대화 기록. assistant 는 Claude 가 돌려준 원문(JSON)을 보관한다. */
@Serializable
data class ChatMessage(val role: String, val text: String) {
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
) {
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
