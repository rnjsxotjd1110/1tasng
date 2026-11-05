package app.ember.ideas.data

/** 줄 단위 차이. 같은 줄이 길게 이어지면 [Skip] 으로 접는다. */
sealed interface DiffLine {
    data class Same(val text: String) : DiffLine
    data class Added(val text: String) : DiffLine
    data class Removed(val text: String) : DiffLine
    data class Skip(val count: Int) : DiffLine
}

object TextDiff {
    private const val MAX_LINES = 3000

    /** 두 설계서를 줄 단위(LCS)로 비교한다. 바뀐 곳 앞뒤로 [context] 줄만 남기고 나머지는 접는다. */
    fun lines(old: String, new: String, context: Int = 2): List<DiffLine> {
        val a = old.lines().take(MAX_LINES)
        val b = new.lines().take(MAX_LINES)
        // 앞뒤의 같은 부분은 LCS 표에서 빼서 계산량을 줄인다.
        var start = 0
        while (start < a.size && start < b.size && a[start] == b[start]) start++
        var endA = a.size
        var endB = b.size
        while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) { endA--; endB-- }
        val midA = a.subList(start, endA)
        val midB = b.subList(start, endB)
        val n = midA.size
        val m = midB.size
        val lcs = Array(n + 1) { IntArray(m + 1) }
        for (i in n - 1 downTo 0) for (j in m - 1 downTo 0) {
            lcs[i][j] = if (midA[i] == midB[j]) lcs[i + 1][j + 1] + 1 else maxOf(lcs[i + 1][j], lcs[i][j + 1])
        }
        val raw = ArrayList<DiffLine>()
        a.subList(0, start).forEach { raw += DiffLine.Same(it) }
        var i = 0
        var j = 0
        while (i < n || j < m) {
            when {
                i < n && j < m && midA[i] == midB[j] -> { raw += DiffLine.Same(midA[i]); i++; j++ }
                // 지운 줄을 먼저, 새 줄을 뒤에 둔다(읽는 순서가 '전 → 후' 가 되게).
                i < n && (j == m || lcs[i + 1][j] >= lcs[i][j + 1]) -> { raw += DiffLine.Removed(midA[i]); i++ }
                else -> { raw += DiffLine.Added(midB[j]); j++ }
            }
        }
        a.subList(endA, a.size).forEach { raw += DiffLine.Same(it) }
        return fold(raw, context)
    }

    private fun fold(raw: List<DiffLine>, context: Int): List<DiffLine> {
        val keep = BooleanArray(raw.size)
        raw.forEachIndexed { idx, l ->
            if (l !is DiffLine.Same) for (k in (idx - context).coerceAtLeast(0)..(idx + context).coerceAtMost(raw.lastIndex)) keep[k] = true
        }
        val out = ArrayList<DiffLine>()
        var skipped = 0
        raw.forEachIndexed { idx, l ->
            if (keep[idx]) {
                if (skipped > 0) { out += DiffLine.Skip(skipped); skipped = 0 }
                out += l
            } else skipped++
        }
        if (skipped > 0) out += DiffLine.Skip(skipped)
        return out
    }

    fun stats(lines: List<DiffLine>): Pair<Int, Int> = lines.count { it is DiffLine.Added } to lines.count { it is DiffLine.Removed }
}
