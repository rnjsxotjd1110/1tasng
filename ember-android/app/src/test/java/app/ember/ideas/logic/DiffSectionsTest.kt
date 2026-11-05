package app.ember.ideas.logic

import app.ember.ideas.data.DiffLine
import app.ember.ideas.data.DocSections
import app.ember.ideas.data.TextDiff
import app.ember.ideas.handoff.GitHubClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DiffSectionsTest {
    private val doc = """
        # 등불지기

        > 소개

        ## 1. 한눈에 보기

        장르: 퍼즐

        ## 2. 핵심 루프

        - 30초 루프
        - 5분 루프

        ## 3. 수익 모델

        유료 3,900원
    """.trimIndent()

    @Test fun diffMarksOnlyChangedLines() {
        val new = doc.replace("- 5분 루프", "- 5분 루프: 지도 한 장").replace("유료 3,900원", "유료 4,900원")
        val lines = TextDiff.lines(doc, new)
        val (added, removed) = TextDiff.stats(lines)
        assertEquals(2, added)
        assertEquals(2, removed)
        assertTrue(lines.any { it is DiffLine.Skip })
        assertTrue(lines.contains(DiffLine.Added("- 5분 루프: 지도 한 장")))
        assertTrue(lines.contains(DiffLine.Removed("유료 3,900원")))
    }

    @Test fun identicalDocsHaveNoChanges() {
        val lines = TextDiff.lines(doc, doc)
        assertEquals(0 to 0, TextDiff.stats(lines))
    }

    @Test fun sectionGetAndReplace() {
        val sec = DocSections.get(doc, "2. 핵심 루프")!!
        assertTrue(sec.startsWith("## 2. 핵심 루프"))
        assertTrue(sec.endsWith("- 5분 루프"))
        val replaced = DocSections.replace(doc, "2. 핵심 루프", "## 2. 핵심 루프\n\n- 새 루프")
        assertTrue(replaced.contains("- 새 루프\n\n## 3. 수익 모델"))
        assertTrue(!replaced.contains("30초 루프"))
        assertTrue(replaced.contains("## 1. 한눈에 보기"))
        assertTrue(replaced.endsWith("유료 3,900원"))
        // 마지막 단락도 바꿀 수 있다.
        assertTrue(DocSections.replace(doc, "3. 수익 모델", "## 3. 수익 모델\n\n무료").endsWith("무료"))
        assertNull(DocSections.get(doc, "없는 단락"))
        // 화면에 붙는 번호가 원문과 달라도 같은 단락을 찾는다.
        assertEquals(sec, DocSections.get(doc, "핵심 루프"))
        assertEquals(DocSections.get("## 핵심 루프\n\n본문", "2. 핵심 루프"), "## 핵심 루프\n\n본문")
        assertEquals(doc, DocSections.replace(doc, "없는 단락", "x"))
    }

    @Test fun githubHelpers() {
        val secs = GitHubClient.sections(doc)
        assertEquals(listOf("한눈에 보기", "핵심 루프", "수익 모델"), secs.map { it.first })
        assertEquals("- 30초 루프\n- 5분 루프", secs[1].second)
        assertEquals("lamplighter-2", GitHubClient.repoNameFor("Lamplighter 2!", "abc"))
        assertEquals("ember-design-abcdef", GitHubClient.repoNameFor("등불지기", "ABCDEF123"))
    }
}
