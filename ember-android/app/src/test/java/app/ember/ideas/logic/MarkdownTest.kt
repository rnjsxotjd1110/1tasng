package app.ember.ideas.logic

import app.ember.ideas.ui.markdown.MarkdownParser
import app.ember.ideas.ui.markdown.MdBlock
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MarkdownTest {
    @Test fun parsesCommonBlocks() {
        val md = """
            # 제목
            > 인용 문장
            ## 섹션
            첫 줄
            이어지는 줄

            - 하나
            - 둘
              이어짐
            1. 첫째
            2. 둘째

            | 항목 | 값 |
            |---|---|
            | 장르 | 퍼즐 |
            | 엔진 | Godot |

            ```
            code()
            ```
            ---
        """.trimIndent()
        val b = MarkdownParser.parse(md)
        assertEquals(MdBlock.Heading(1, "제목"), b[0])
        assertTrue(b[1] is MdBlock.Quote)
        assertEquals(MdBlock.Heading(2, "섹션"), b[2])
        assertEquals(MdBlock.Paragraph("첫 줄 이어지는 줄"), b[3])
        val list = b[4] as MdBlock.ListBlock
        assertEquals("둘 이어짐", list.items[1].text)
        val ordered = b[5] as MdBlock.ListBlock
        assertTrue(ordered.ordered)
        val table = b[6] as MdBlock.Table
        assertEquals(listOf("항목", "값"), table.header)
        assertEquals(2, table.rows.size)
        assertTrue(b[7] is MdBlock.Code)
        assertEquals(MdBlock.Rule, b[8])
    }

    @Test fun ragged_table_rows_are_padded() {
        val t = MarkdownParser.parse("| a | b | c |\n|---|---|---|\n| 1 |\n")[0] as MdBlock.Table
        assertEquals(listOf("1", "", ""), t.rows[0])
    }

    @Test fun partialStreamingDoesNotCrash() {
        val md = "# 제목\n## 섹\n| a | b |\n|--"
        val b = MarkdownParser.parse(md)
        assertTrue(b.isNotEmpty())
    }
}
