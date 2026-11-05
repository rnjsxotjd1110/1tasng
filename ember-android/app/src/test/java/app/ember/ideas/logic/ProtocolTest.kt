package app.ember.ideas.logic

import app.ember.ideas.FakeAi
import app.ember.ideas.ai.Protocol
import app.ember.ideas.ai.toPlain
import app.ember.ideas.data.Answer
import app.ember.ideas.data.Question
import app.ember.ideas.data.QuestionOption
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProtocolTest {

    @Test fun parsesQuestion() {
        val r = Protocol.parseReply(FakeAi.question("어디서 하나요?", multi = true))
        assertTrue(r.isQuestion)
        assertEquals(4, r.question.options.size)
        assertTrue(r.question.multiSelect)
    }

    @Test fun parsesIdeasAndClampsDifficulty() {
        val raw = FakeAi.ideas("A", "B").replace("\"difficulty\":1", "\"difficulty\":9")
        val r = Protocol.parseReply(raw)
        assertTrue(r.isIdeas)
        assertEquals(5, r.ideas[0].difficulty)
    }

    @Test fun toleratesSurroundingText() {
        val r = Protocol.parseReply("앞말 " + FakeAi.ready() + " 뒷말")
        assertTrue(r.isReady)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsNonJson() { Protocol.parseReply("죄송합니다") }

    @Test fun questionWithoutOptionsIsNotQuestion() {
        val r = Protocol.parseReply(FakeAi.question("빈 질문", options = emptyList()))
        assertFalse(r.isQuestion)
    }

    @Test fun sanitizeFixesDuplicateIdsAndBlankLabels() {
        val q = Question("t", options = listOf(QuestionOption("a", "하나"), QuestionOption("a", "둘"), QuestionOption("", " "), QuestionOption("c", "하나")))
        val s = Protocol.sanitizeQuestion(q)
        assertEquals(listOf("하나", "둘"), s.options.map { it.label })
        assertEquals(2, s.options.map { it.id }.toSet().size)
    }

    /** 구조화 출력 규칙: 모든 객체는 additionalProperties=false 이고 required 가 모든 속성을 포함해야 한다. */
    @Test fun schemasAreStrict() {
        fun check(o: JsonObject) {
            if (o["type"]?.jsonPrimitive?.content == "object") {
                assertEquals(JsonPrimitive(false), o["additionalProperties"])
                val props = o["properties"]!!.jsonObject.keys
                val req = o["required"]!!.jsonArray.map { it.jsonPrimitive.content }.toSet()
                assertEquals(props, req)
                o["properties"]!!.jsonObject.values.forEach { check(it.jsonObject) }
            }
            o["items"]?.let { check(it.jsonObject) }
        }
        check(Protocol.discoverySchema)
        check(Protocol.designSchema)
    }

    @Test fun schemaConvertsToPlainMap() {
        val plain = Protocol.discoverySchema.toPlain() as Map<*, *>
        assertEquals("object", plain["type"])
        assertEquals(false, plain["additionalProperties"])
        assertTrue((plain["required"] as List<*>).contains("ideas"))
    }

    @Test fun answerMessageIncludesLabelsAndCustom() {
        val q = Question("플랫폼", options = listOf(QuestionOption("o1", "모바일"), QuestionOption("o2", "PC")))
        val m = Protocol.answerMessage(q, Answer(listOf("o2"), "스팀덱도"))
        assertTrue(m.contains("PC"))
        assertTrue(m.contains("스팀덱도"))
        assertFalse(m.contains("모바일"))
        assertTrue(Protocol.answerMessage(q, Answer(skipped = true)).startsWith("[건너뜀]"))
    }

    @Test fun documentHelpers() {
        val md = "# 등불지기\n> 소개\n## 하나\n본문\n## 둘\n"
        assertEquals("등불지기", Protocol.documentTitle(md))
        assertEquals(listOf("하나", "둘"), Protocol.sectionTitles(md))
    }

    @Test fun designSchemaHasNoIdeas() {
        val props = Protocol.designSchema["properties"]!!.jsonObject
        assertFalse(props.containsKey("ideas"))
        assertEquals(JsonArray(listOf(JsonPrimitive("question"), JsonPrimitive("ready"))), props["kind"]!!.jsonObject["enum"])
    }

    @org.junit.Test fun duplicateIdeaIdsAreRenumbered() {
        val json = app.ember.ideas.FakeAi.ideas("A", "B", "C").replace("\"id\":\"i2\"", "\"id\":\"i1\"").replace("\"id\":\"i3\"", "\"id\":\"\"")
        val ids = app.ember.ideas.ai.Protocol.parseReply(json).ideas.map { it.id }
        org.junit.Assert.assertEquals(listOf("i1", "idea2", "idea3"), ids)
    }
}
