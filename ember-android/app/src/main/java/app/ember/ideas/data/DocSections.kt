package app.ember.ideas.data

/** 설계서를 '## ' 단락 단위로 꺼내고 바꾼다. 섹션 하나만 고칠 때 쓴다. */
object DocSections {
    private fun headingOf(line: String) = line.trimEnd().takeIf { it.startsWith("## ") }?.removePrefix("## ")?.trim()

    /** 화면에는 단락 번호("1. ")가 붙을 수 있으므로 번호를 떼고 비교한다. */
    private fun norm(h: String) = h.trim().replace(Regex("^\\d+[.)]\\s*"), "")

    /** [heading] 단락의 줄 범위(제목 줄 포함, 다음 '## ' 직전까지). */
    fun range(markdown: String, heading: String): IntRange? {
        val lines = markdown.lines()
        val start = lines.indexOfFirst { l -> headingOf(l)?.let { norm(it) == norm(heading) } == true }
        if (start < 0) return null
        var end = start + 1
        while (end < lines.size && headingOf(lines[end]) == null) end++
        return start until end
    }

    fun get(markdown: String, heading: String): String? =
        range(markdown, heading)?.let { r -> markdown.lines().subList(r.first, r.last + 1).joinToString("\n").trimEnd() }

    /** 단락을 [section] 으로 바꾼다. 단락 뒤의 빈 줄 하나는 유지한다. */
    fun replace(markdown: String, heading: String, section: String): String {
        val r = range(markdown, heading) ?: return markdown
        val lines = markdown.lines()
        val before = lines.subList(0, r.first)
        val after = lines.subList(r.last + 1, lines.size)
        val body = section.trimEnd().lines() + if (after.isNotEmpty()) listOf("") else emptyList()
        return (before + body + after).joinToString("\n")
    }
}
