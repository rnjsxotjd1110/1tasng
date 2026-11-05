package app.ember.ideas.logic

import app.ember.ideas.FakeAi
import app.ember.ideas.MockHttp
import app.ember.ideas.MockHttp.Res
import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.ClaudeAiService
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.Effort
import app.ember.ideas.ai.Endpoint
import app.ember.ideas.ai.Protocol
import app.ember.ideas.ai.TurnRequest
import app.ember.ideas.data.ChatMessage
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonPrimitive
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** 실제 Anthropic SDK 가 만드는 요청을 가짜 서버로 받아, 중계 서버·웹 검색·이미지·스트리밍 처리를 확인한다. */
class ClaudeRequestTest {
    private val mock = MockHttp()
    private val ai = ClaudeAiService { Endpoint("tok_device", mock.url) }

    @After fun tearDown() = mock.close()

    private fun message(content: String, stop: String, searches: Int = 0) = """
        {"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5-5","content":[$content],
         "stop_reason":"$stop","stop_sequence":null,
         "usage":{"input_tokens":100,"output_tokens":20,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,
                  "server_tool_use":{"web_search_requests":$searches}}}
    """.trimIndent()

    private fun request(webSearch: Boolean = false, messages: List<ChatMessage> = listOf(ChatMessage(ChatMessage.USER, "시작"))) =
        TurnRequest(Protocol.discoverySystem(app.ember.ideas.ai.ReplyLanguage.KO), messages, Protocol.discoverySchema, Effort.MEDIUM, webSearch = webSearch)

    @Test fun webSearchWithPauseTurnAndSources() = runBlocking {
        val search = """{"type":"server_tool_use","id":"srvtoolu_1","name":"web_search","input":{"query":"subway puzzle game"}},
            {"type":"web_search_tool_result","tool_use_id":"srvtoolu_1","content":[{"type":"web_search_result","url":"https://example.com/mini-metro","title":"Mini Metro","encrypted_content":"abc","page_age":null}]}"""
        val ideas = FakeAi.ideas("지하철 정원사")
        mock.on(
            "POST /v1/messages",
            Res(200, message(search, "pause_turn", searches = 1)),
            Res(200, message("""{"type":"text","text":"검색해 볼게요."},$search,{"type":"text","text":${JsonPrimitive(ideas)}}""", "end_turn", searches = 1)),
        )
        val r = ai.turn(ClaudeModel.OPUS, request(webSearch = true))
        assertEquals(ideas, r.text) // 도구 결과 앞의 안내 글은 빼고 JSON 만 남긴다.
        assertEquals(listOf("https://example.com/mini-metro"), r.sources.map { it.url })
        assertEquals("Mini Metro", r.sources.first().title)
        val bodies = mock.requests.filter { it.path.startsWith("/v1/messages") }
        assertEquals(2, bodies.size)
        assertTrue(bodies[0].body.contains("web_search_20260209"))
        assertTrue(bodies[0].body.contains("\"max_uses\":3"))
        // pause_turn 이면 받은 내용을 그대로 붙여 다시 보낸다.
        assertTrue(bodies[1].body.contains("srvtoolu_1"))
        assertEquals("tok_device", bodies[0].headers["x-api-key"])
        assertEquals(null, bodies[0].headers["authorization"])
        // 웹 검색 2회 비용($0.02)이 사용량에 들어간다.
        assertTrue(r.usage.costUsd > 0.02 && r.usage.costUsd < 0.03)
        assertEquals(2, r.usage.requests)
    }

    @Test fun realApiKeyUsesXApiKeyHeader() = runBlocking {
        val direct = ClaudeAiService { Endpoint("sk-ant-api03-test-key-000000000000000000000000000000", mock.url) }
        mock.on("POST /v1/messages", Res(200, message("""{"type":"text","text":${JsonPrimitive(FakeAi.question("질문"))}}""", "end_turn")))
        direct.turn(ClaudeModel.OPUS, request())
        val h = mock.last("/v1/messages").headers
        assertEquals("sk-ant-api03-test-key-000000000000000000000000000000", h["x-api-key"] ?: error("authorization=" + h["authorization"]))
        // Bearer 를 함께 보내면 API 가 OAuth 로 해석하므로 없어야 한다.
        assertEquals(null, h["authorization"])
        assertTrue(h["anthropic-beta"].orEmpty().contains("oauth").not())
    }

    @Test fun noToolWithoutSearch() = runBlocking {
        mock.on("POST /v1/messages", Res(200, message("""{"type":"text","text":${JsonPrimitive(FakeAi.question("질문"))}}""", "end_turn")))
        ai.turn(ClaudeModel.OPUS, request())
        assertTrue(!mock.last("/v1/messages").body.contains("web_search_2026"))
    }

    @Test fun imagesGoBeforeText() = runBlocking {
        val img = java.io.File.createTempFile("ember", ".jpg").apply { writeBytes(byteArrayOf(1, 2, 3, 4)) }
        mock.on("POST /v1/messages", Res(200, message("""{"type":"text","text":${JsonPrimitive(FakeAi.question("질문"))}}""", "end_turn")))
        ai.turn(ClaudeModel.OPUS, request(messages = listOf(ChatMessage(ChatMessage.USER, "시작", listOf(img.absolutePath, "/missing.jpg")))))
        val body = mock.last("/v1/messages").body
        assertTrue(body.contains("\"type\":\"image\""))
        assertTrue(body.contains("image/jpeg"))
        assertTrue(body.contains(java.util.Base64.getEncoder().encodeToString(byteArrayOf(1, 2, 3, 4))))
        assertTrue(body.indexOf("\"type\":\"image\"") < body.indexOf("시작"))
        img.delete()
        Unit
    }

    @Test fun relay402IsOutOfCredits() = runBlocking {
        mock.on("POST /v1/messages", Res(402, """{"type":"error","error":{"type":"insufficient_credits","message":"Ember 크레딧이 부족합니다"}}"""))
        try {
            ai.turn(ClaudeModel.OPUS, request())
            fail()
        } catch (e: AiError) {
            assertEquals(AiError.OutOfCredits, e)
        }
    }

    @Test fun streamingQuestionDeliversText() = runBlocking {
        val full = FakeAi.question("어떤 분위기에 끌리나요?")
        val sse = buildString {
            fun ev(name: String, data: String) { append("event: $name\ndata: $data\n\n") }
            ev("message_start", """{"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5-5","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":50,"output_tokens":1}}}""")
            ev("content_block_start", """{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}""")
            full.chunked(17).forEach { ev("content_block_delta", """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":${JsonPrimitive(it)}}}""") }
            ev("content_block_stop", """{"type":"content_block_stop","index":0}""")
            ev("message_delta", """{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":300}}""")
            ev("message_stop", """{"type":"message_stop"}""")
        }
        mock.on("POST /v1/messages", Res(200, sse, "text/event-stream"))
        val seen = mutableListOf<String>()
        val r = ai.turnStreaming(ClaudeModel.OPUS, request()) { seen += it }
        assertEquals(full, r.text)
        assertEquals(full, seen.last())
        assertTrue(mock.last("/v1/messages").body.contains("\"stream\":true"))
        assertEquals(300L, r.usage.outputTokens)
        assertEquals("어떤 분위기에 끌리나요?", app.ember.ideas.ai.PartialJson.question(seen.last())!!.title)
    }
}
