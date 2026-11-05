package app.ember.ideas.ai

import app.ember.ideas.data.ChatMessage
import app.ember.ideas.data.Usage
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.JsonObject

/** 앱에서 고를 수 있는 Claude 모델. 가격은 100만 토큰당 USD. */
enum class ClaudeModel(
    val id: String,
    val inputPrice: Double,
    val outputPrice: Double,
    val cacheReadPrice: Double,
    val supportsFallback: Boolean,
) {
    OPUS("claude-opus-5-5", 4.0, 20.0, 0.20, true),
    SONNET("claude-sonnet-5-5", 2.0, 10.0, 0.20, true),
    HAIKU("claude-haiku-5-5", 0.10, 0.50, 0.01, false);

    fun cost(input: Long, output: Long, cacheRead: Long, cacheWrite: Long): Double =
        (input * inputPrice + output * outputPrice + cacheRead * cacheReadPrice + cacheWrite * inputPrice * 1.25) / 1_000_000.0

    companion object {
        fun fromId(id: String?): ClaudeModel = entries.firstOrNull { it.id == id } ?: OPUS
    }
}

/** 작업 종류별 생각 깊이. 질문은 빠르게, 설계서는 깊게. */
enum class Effort { LOW, MEDIUM, HIGH, XHIGH }

data class TurnRequest(
    val system: String,
    val messages: List<ChatMessage>,
    val schema: JsonObject,
    val effort: Effort,
    val maxTokens: Long = 16_000,
    /** 웹 검색 도구를 함께 준다(아이디어를 낼 가능성이 높을 때만). */
    val webSearch: Boolean = false,
)

/** [sources] 는 웹 검색 결과에 실제로 나온 페이지들이다. */
data class TurnResult(val text: String, val usage: Usage, val sources: List<app.ember.ideas.data.Reference> = emptyList())

/** 웹 검색 1회 요금(USD). */
const val WEB_SEARCH_USD = 0.01

data class StreamRequest(
    val system: String,
    val messages: List<ChatMessage>,
    val effort: Effort,
    val maxTokens: Long = 64_000,
)

sealed interface StreamEvent {
    data class Delta(val text: String) : StreamEvent
    data class Done(val usage: Usage, val truncated: Boolean) : StreamEvent
}

/** 사용자에게 보여줄 수 있도록 분류한 오류. */
sealed class AiError(message: String) : Exception(message) {
    data object NoKey : AiError("no_key") { private fun readResolve(): Any = NoKey }
    data object InvalidKey : AiError("invalid_key") { private fun readResolve(): Any = InvalidKey }
    data object NoCredit : AiError("no_credit") { private fun readResolve(): Any = NoCredit }
    data object RateLimited : AiError("rate_limited") { private fun readResolve(): Any = RateLimited }
    data object Overloaded : AiError("overloaded") { private fun readResolve(): Any = Overloaded }
    data object Offline : AiError("offline") { private fun readResolve(): Any = Offline }
    data object Refused : AiError("refused") { private fun readResolve(): Any = Refused }
    data object BadResponse : AiError("bad_response") { private fun readResolve(): Any = BadResponse }
    data object ModelUnavailable : AiError("model_unavailable") { private fun readResolve(): Any = ModelUnavailable }
    data object OverBudget : AiError("over_budget") { private fun readResolve(): Any = OverBudget }
    /** 앞에서 받은 아이디어와 같은 것만 돌아왔다. */
    data object DuplicateIdeas : AiError("duplicate_ideas") { private fun readResolve(): Any = DuplicateIdeas }
    /** Ember 크레딧이 바닥났다(중계 서버 402). */
    data object OutOfCredits : AiError("out_of_credits") { private fun readResolve(): Any = OutOfCredits }
    class Other(val detail: String) : AiError(detail)
}

interface AiService {
    /** 구조화 출력(JSON) 한 번 요청. */
    suspend fun turn(model: ClaudeModel, request: TurnRequest): TurnResult

    /**
     * [turn] 과 같지만 글이 오는 대로 [onText] 에 지금까지의 글 전체를 넘긴다(질문 카드를 미리 그리려고).
     * 스트리밍을 못 하는 구현은 기본값처럼 한 번에 받는다.
     */
    suspend fun turnStreaming(model: ClaudeModel, request: TurnRequest, onText: (String) -> Unit): TurnResult = turn(model, request)

    /** 긴 Markdown 생성용 스트리밍. */
    fun stream(model: ClaudeModel, request: StreamRequest): Flow<StreamEvent>

    /** 키가 유효하고 모델을 쓸 수 있는지 확인. */
    suspend fun validate(apiKey: String, model: ClaudeModel)
}
