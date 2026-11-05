package app.ember.ideas.ai

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** 스트리밍 중에 미리 보여 줄 질문. 선택지는 받은 만큼만 들어 있다. */
data class PartialQuestion(
    val stage: String,
    val insight: String,
    val title: String,
    val subtitle: String,
    val options: List<Pair<String, String>>,
)

/**
 * 아직 다 오지 않은 JSON 을 닫아서 읽는다. 열린 문자열·배열·객체를 닫고,
 * 값이 없는 키나 끝의 쉼표처럼 읽을 수 없는 꼬리는 잘라 낸다.
 */
object PartialJson {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    fun close(text: String): String? {
        val start = text.indexOf('{')
        if (start < 0) return null
        val stack = ArrayDeque<Char>()
        var inString = false
        var escape = false
        for (i in start until text.length) {
            val ch = text[i]
            if (inString) {
                when {
                    escape -> escape = false
                    ch == '\\' -> escape = true
                    ch == '"' -> inString = false
                }
                continue
            }
            when (ch) {
                '"' -> inString = true
                '{', '[' -> stack.addLast(ch)
                '}', ']' -> stack.removeLastOrNull()
            }
        }
        val sb = StringBuilder(text.substring(start))
        if (inString) {
            // 이스케이프 중간에서 끊겼으면 그 역슬래시를 지우고 문자열을 닫는다.
            if (escape) sb.setLength(sb.length - 1)
            sb.append('"')
        }
        val closers = stack.reversed().joinToString("") { if (it == '{') "}" else "]" }
        val top = stack.lastOrNull()
        // 꼬리를 정리한다: 공백, 끝의 쉼표·콜론, 값 없는 키, 덜 온 true/false/null/숫자.
        repeat(4) {
            while (sb.isNotEmpty() && sb.last().isWhitespace()) sb.setLength(sb.length - 1)
            if (sb.endsWith(",") || sb.endsWith(":")) { sb.setLength(sb.length - 1); return@repeat }
            val literal = LITERAL_TAIL.find(sb)
            if (literal != null && literal.groupValues[1].isNotEmpty()) { sb.setLength(literal.range.first + 1); return@repeat }
            if (top == '{') {
                // 객체 안에서 ':' 없이 끝난 문자열은 키다.
                val key = KEY_TAIL.find(sb)
                if (key != null) { sb.setLength(key.range.first + 1); return@repeat }
            }
        }
        if (sb.endsWith(",")) sb.setLength(sb.length - 1)
        return sb.toString() + closers
    }

    // 덜 온 리터럴: t, tr, tru, f.., n.., 그리고 끝이 '.', 'e', '-' 인 숫자.
    private val LITERAL_TAIL = Regex("""[,:\[]\s*(t|tr|tru|f|fa|fal|fals|n|nu|nul|-|-?[0-9]+\.|-?[0-9.]+[eE][+-]?)$""")
    private val KEY_TAIL = Regex("""([{,])\s*"(?:[^"\\]|\\.)*"$""")

    fun parse(text: String): JsonObject? = close(text)?.let { runCatching { json.parseToJsonElement(it).jsonObject }.getOrNull() }

    /** 질문 응답이면 지금까지 받은 질문을 꺼낸다. 아이디어 응답이거나 제목이 아직 없으면 null. */
    fun question(text: String): PartialQuestion? {
        val o = parse(text) ?: return null
        val kind = o.str("kind")
        if (kind != null && kind != Protocol.KIND_QUESTION) return null
        val q = o["question"]?.let { runCatching { it.jsonObject }.getOrNull() } ?: return null
        val title = q.str("title").orEmpty()
        if (title.isBlank()) return null
        val options = runCatching { q["options"]?.jsonArray }.getOrNull().orEmpty().mapNotNull { e ->
            val opt = runCatching { e.jsonObject }.getOrNull() ?: return@mapNotNull null
            val label = opt.str("label").orEmpty()
            if (label.isBlank()) null else label to opt.str("description").orEmpty()
        }
        return PartialQuestion(o.str("stage").orEmpty(), o.str("insight").orEmpty(), title, q.str("subtitle").orEmpty(), options)
    }

    private fun JsonObject.str(key: String): String? = (this[key] as? JsonElement)?.let { runCatching { it.jsonPrimitive.content }.getOrNull() }
}
