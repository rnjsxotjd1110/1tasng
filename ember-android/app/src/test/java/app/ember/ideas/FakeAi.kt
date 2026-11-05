package app.ember.ideas

import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.AiService
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.StreamEvent
import app.ember.ideas.ai.StreamRequest
import app.ember.ideas.ai.TurnRequest
import app.ember.ideas.ai.TurnResult
import app.ember.ideas.data.Usage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/** 테스트·스크린샷용 가짜 Claude. 응답을 순서대로 꺼내 쓰고, 보낸 요청을 기록한다. */
class FakeAi : AiService {
    val turnReplies = ArrayDeque<Result<String>>()
    var docMarkdown: String = "# 제목\n\n> 소개\n\n## 한눈에 보기\n\n본문"
    var docError: AiError? = null
    val turnRequests = mutableListOf<TurnRequest>()
    val streamRequests = mutableListOf<StreamRequest>()
    /** 설정하면 요청이 이 값이 완료될 때까지 멈춘다(로딩 화면 캡처용). */
    var gate: CompletableDeferred<Unit>? = null
    var validateError: AiError? = null
    /** 게이트가 있을 때 멈추기 전에 먼저 보낼 조각 수(스트리밍 중 화면 캡처용). */
    var streamBeforeGate = 0

    override suspend fun turn(model: ClaudeModel, request: TurnRequest): TurnResult {
        turnRequests += request
        gate?.await()
        val r = turnReplies.removeFirstOrNull() ?: Result.failure(AiError.BadResponse)
        return TurnResult(r.getOrThrow(), Usage(1000, 500, 0, 0, 0.014, 1))
    }

    override fun stream(model: ClaudeModel, request: StreamRequest): Flow<StreamEvent> = flow {
        streamRequests += request
        val chunks = docMarkdown.chunked(40)
        val head = if (gate != null) chunks.take(streamBeforeGate) else emptyList()
        head.forEach { emit(StreamEvent.Delta(it)) }
        gate?.await()
        docError?.let { throw it }
        chunks.drop(head.size).forEach { emit(StreamEvent.Delta(it)) }
        emit(StreamEvent.Done(Usage(2000, 4000, 0, 0, 0.088, 1), truncated = false))
    }

    override suspend fun validate(apiKey: String, model: ClaudeModel) {
        validateError?.let { throw it }
    }

    companion object {
        fun question(title: String, stage: String = "플랫폼", progress: Int = 20, insight: String = "", multi: Boolean = false, options: List<Pair<String, String>> = listOf("모바일" to "📱", "PC" to "💻", "웹" to "🌐", "콘솔" to "🕹️")): String {
            val opts = options.mapIndexed { i, (l, e) -> """{"id":"o${i + 1}","label":"$l","description":"$l 설명","emoji":"$e"}""" }.joinToString(",")
            return """{"kind":"question","stage":"$stage","progress":$progress,"insight":"$insight","question":{"title":"$title","subtitle":"이유","multi_select":$multi,"options":[$opts],"allow_custom":true,"custom_hint":"직접"},"ideas_intro":"","ideas":[]}"""
        }

        fun ideas(vararg titles: String): String {
            val list = titles.mapIndexed { i, t ->
                """{"id":"i${i + 1}","title":"$t","logline":"$t 한 줄 소개","category":"퍼즐","platforms":["Android"],"genre":"퍼즐","target_audience":"모두","core_hook":"재미","key_features":["기능1","기능2","기능3"],"unique_point":"차별","monetization":"유료","scope":"소형","dev_time":"3개월","difficulty":${(i % 5) + 1},"fit_reason":"이유"}"""
            }.joinToString(",")
            return """{"kind":"ideas","stage":"아이디어","progress":100,"insight":"","question":{"title":"","subtitle":"","multi_select":false,"options":[],"allow_custom":false,"custom_hint":""},"ideas_intro":"골랐어요","ideas":[$list]}"""
        }

        fun ready(summary: String = "- 엔진: Godot") =
            """{"kind":"ready","stage":"완료","progress":100,"insight":"","question":{"title":"","subtitle":"","multi_select":false,"options":[],"allow_custom":false,"custom_hint":""},"ready_summary":"$summary"}"""
    }
}
