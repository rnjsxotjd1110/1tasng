package app.ember.ideas.logic

import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.ClaudeAiService
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.Effort
import app.ember.ideas.ai.Protocol
import app.ember.ideas.ai.ReplyLanguage
import app.ember.ideas.ai.StreamRequest
import app.ember.ideas.ai.TurnRequest
import app.ember.ideas.data.ChatMessage
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 실제 api.anthropic.com 에 가짜 키로 요청해, SDK 요청 조립·전송·오류 분류 경로가 끝까지 동작하는지 확인한다.
 * (유효한 키가 없어도 401 이 돌아와야 정상이다.)
 */
class LiveApiTest {
    private val svc = ClaudeAiService { app.ember.ideas.ai.Endpoint("sk-ant-api03-invalid-key-for-ember-tests-0000000000000000") }
    private val msgs = listOf(ChatMessage(ChatMessage.USER, Protocol.startMessage(app.ember.ideas.data.ProjectKind.GAME, "", app.ember.ideas.data.DevProfile(), ReplyLanguage.KO)))

    @Test fun structuredTurnMapsUnauthorized() = runBlocking {
        val e = runCatching { svc.turn(ClaudeModel.OPUS, TurnRequest(Protocol.discoverySystem(ReplyLanguage.KO), msgs, Protocol.discoverySchema, Effort.LOW)) }.exceptionOrNull()
        assertEquals(AiError.InvalidKey, e)
    }

    @Test fun streamMapsUnauthorized() = runBlocking {
        val e = runCatching { svc.stream(ClaudeModel.SONNET, StreamRequest("s", msgs, Effort.HIGH)).collect {} }.exceptionOrNull()
        assertEquals(AiError.InvalidKey, e)
    }

    @Test fun validateMapsUnauthorized() = runBlocking {
        val e = runCatching { svc.validate("sk-ant-api03-invalid-key-for-ember-tests-0000000000000000", ClaudeModel.HAIKU) }.exceptionOrNull()
        assertEquals(AiError.InvalidKey, e)
    }
}
