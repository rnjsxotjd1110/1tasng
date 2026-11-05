package app.ember.ideas.logic

import app.ember.ideas.FakeAi
import app.ember.ideas.ai.PartialJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PartialJsonTest {
    private val full = FakeAi.question("어떤 \\\"분위기\\\"에 끌리나요?\\n둘째 줄", options = listOf("아늑한" to "", "몽환적인" to "", "긴장감" to ""))

    @Test fun everyPrefixIsSafe() {
        val finalQ = PartialJson.question(full)!!
        var lastTitle = ""
        for (n in 0..full.length) {
            val prefix = full.take(n)
            val pq = PartialJson.question(prefix) // 어느 위치에서 끊겨도 예외 없이 null 이나 값을 돌려준다.
            if (pq != null) {
                assertTrue("제목은 최종 제목의 앞부분이어야 해요: ${pq.title}", finalQ.title.startsWith(pq.title))
                assertTrue("제목이 줄어들면 안 돼요", pq.title.length >= lastTitle.length)
                lastTitle = pq.title
                pq.options.forEachIndexed { i, (label, _) -> assertTrue(finalQ.options[i].first.startsWith(label)) }
            }
        }
        assertEquals("어떤 \"분위기\"에 끌리나요?\n둘째 줄", finalQ.title)
        assertEquals(3, finalQ.options.size)
    }

    @Test fun titleAppearsBeforeOptions() {
        val cut = full.indexOf("\"subtitle\"")
        val pq = PartialJson.question(full.take(cut))
        assertNotNull(pq)
        assertTrue(pq!!.options.isEmpty())
    }

    @Test fun ideasAreNotQuestions() {
        assertNull(PartialJson.question(FakeAi.ideas("하나", "둘")))
        assertNull(PartialJson.question(""))
        assertNull(PartialJson.question("not json"))
    }

    @Test fun closesNumbersAndLiterals() {
        assertEquals("""{"a":1}""", PartialJson.close("""{"a":1"""))
        assertEquals("""{"a":true}""", PartialJson.close("""{"a":true"""))
        assertEquals("""{}""", PartialJson.close("""{"a":tr"""))
        assertEquals("""{"a":[1,2]}""", PartialJson.close("""{"a":[1,2,"""))
        assertEquals("""{"a":"x"}""", PartialJson.close("""{"a":"x", "b"""))
        assertEquals("{\"a\":\"x\"}", PartialJson.close("{\"a\":\"x\\"))
    }
}
