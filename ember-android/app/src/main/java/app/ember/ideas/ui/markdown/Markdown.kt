package app.ember.ideas.ui.markdown

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import app.ember.ideas.ui.text.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberColors

/** 설계서에 쓰는 만큼만 지원하는 가벼운 Markdown 블록 모델. */
sealed interface MdBlock {
    data class Heading(val level: Int, val text: String) : MdBlock
    data class Paragraph(val text: String) : MdBlock
    data class ListBlock(val ordered: Boolean, val items: List<ListItem>) : MdBlock
    data class Quote(val text: String) : MdBlock
    data class Code(val text: String) : MdBlock
    data class Table(val header: List<String>, val rows: List<List<String>>) : MdBlock
    data object Rule : MdBlock
}

data class ListItem(val depth: Int, val marker: String, val text: String)

object MarkdownParser {

    private val ordered = Regex("^(\\s*)(\\d+)[.)]\\s+(.*)$")
    private val bullet = Regex("^(\\s*)[-*+]\\s+(.*)$")
    private val tableSep = Regex("^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{2,}:?\\s*)*\\|?\\s*$")

    fun parse(markdown: String): List<MdBlock> {
        val lines = markdown.replace("\r\n", "\n").split("\n")
        val out = ArrayList<MdBlock>()
        var i = 0
        val para = StringBuilder()
        fun flushPara() {
            if (para.isNotBlank()) out += MdBlock.Paragraph(para.toString().trim())
            para.clear()
        }
        while (i < lines.size) {
            val line = lines[i]
            val trimmed = line.trim()
            when {
                trimmed.isEmpty() -> { flushPara(); i++ }
                trimmed.startsWith("```") -> {
                    flushPara()
                    val sb = StringBuilder()
                    i++
                    while (i < lines.size && !lines[i].trim().startsWith("```")) { sb.appendLine(lines[i]); i++ }
                    i++
                    out += MdBlock.Code(sb.toString().trimEnd())
                }
                trimmed.startsWith("#") && trimmed.dropWhile { it == '#' }.startsWith(" ") -> {
                    flushPara()
                    val level = trimmed.takeWhile { it == '#' }.length.coerceAtMost(4)
                    out += MdBlock.Heading(level, trimmed.drop(level).trim().trimEnd('#').trim())
                    i++
                }
                trimmed == "---" || trimmed == "***" || trimmed == "___" -> { flushPara(); out += MdBlock.Rule; i++ }
                trimmed.startsWith(">") -> {
                    flushPara()
                    val sb = StringBuilder()
                    while (i < lines.size && lines[i].trim().startsWith(">")) {
                        sb.appendLine(lines[i].trim().removePrefix(">").trim()); i++
                    }
                    out += MdBlock.Quote(sb.toString().trim())
                }
                trimmed.startsWith("|") && i + 1 < lines.size && tableSep.matches(lines[i + 1]) -> {
                    flushPara()
                    val header = splitRow(trimmed)
                    i += 2
                    val rows = ArrayList<List<String>>()
                    while (i < lines.size && lines[i].trim().startsWith("|")) {
                        val r = splitRow(lines[i].trim())
                        rows += List(header.size) { idx -> r.getOrElse(idx) { "" } }
                        i++
                    }
                    out += MdBlock.Table(header, rows)
                }
                bullet.matches(line) || ordered.matches(line) -> {
                    flushPara()
                    val isOrdered = ordered.matches(line)
                    val items = ArrayList<ListItem>()
                    while (i < lines.size) {
                        val l = lines[i]
                        val b = bullet.find(l)
                        val o = ordered.find(l)
                        when {
                            b != null && isOrdered && b.groupValues[1].isEmpty() -> break
                            o != null && !isOrdered && o.groupValues[1].isEmpty() -> break
                            b != null -> items += ListItem(b.groupValues[1].length / 2, "•", b.groupValues[2].trim())
                            o != null -> items += ListItem(o.groupValues[1].length / 2, o.groupValues[2] + ".", o.groupValues[3].trim())
                            l.isNotBlank() && l.startsWith("  ") && items.isNotEmpty() -> {
                                val last = items.removeAt(items.lastIndex)
                                items += last.copy(text = last.text + " " + l.trim())
                            }
                            else -> break
                        }
                        i++
                    }
                    out += MdBlock.ListBlock(isOrdered, items)
                }
                else -> {
                    if (para.isNotEmpty()) para.append(' ')
                    para.append(trimmed)
                    i++
                }
            }
        }
        flushPara()
        return out
    }

    private fun splitRow(row: String): List<String> =
        row.trim().removePrefix("|").removeSuffix("|").split("|").map { it.trim() }

    /** **굵게**, *기울임*, `코드`, [링크](url) 를 AnnotatedString 으로 바꾼다. */
    fun inline(text: String, c: EmberColors): AnnotatedString = buildAnnotatedString {
        var i = 0
        while (i < text.length) {
            when {
                text.startsWith("**", i) -> {
                    val end = text.indexOf("**", i + 2)
                    if (end > i + 2) {
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = c.text)) { append(inline(text.substring(i + 2, end), c)) }
                        i = end + 2
                    } else { append("**"); i += 2 }
                }
                text[i] == '`' -> {
                    val end = text.indexOf('`', i + 1)
                    if (end > i + 1) {
                        withStyle(SpanStyle(fontFamily = FontFamily.Monospace, fontSize = 0.86.em, background = c.surface3, color = c.text)) {
                            append(text.substring(i + 1, end))
                        }
                        i = end + 1
                    } else { append('`'); i++ }
                }
                (text[i] == '*' || text[i] == '_') && i + 1 < text.length && !text[i + 1].isWhitespace() &&
                    (i == 0 || !text[i - 1].isLetterOrDigit()) -> {
                    val ch = text[i]
                    val end = text.indexOf(ch, i + 1)
                    if (end > i + 1 && !text[end - 1].isWhitespace()) {
                        withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(text.substring(i + 1, end)) }
                        i = end + 1
                    } else { append(ch); i++ }
                }
                text[i] == '[' -> {
                    val close = text.indexOf("](", i)
                    val paren = if (close > 0) text.indexOf(')', close) else -1
                    if (close > i && paren > close) {
                        withStyle(SpanStyle(color = c.ember, fontWeight = FontWeight.Medium)) { append(text.substring(i + 1, close)) }
                        i = paren + 1
                    } else { append('['); i++ }
                }
                else -> { append(text[i]); i++ }
            }
        }
    }
}

@Composable
fun MarkdownBlockView(block: MdBlock, modifier: Modifier = Modifier) {
    val c = Ember.colors
    val t = MaterialTheme.typography
    when (block) {
        is MdBlock.Heading -> {
            val style = when (block.level) {
                1 -> t.headlineMedium
                2 -> t.titleLarge
                3 -> t.titleMedium
                else -> t.titleSmall
            }
            Column(modifier.fillMaxWidth().padding(top = if (block.level <= 2) 22.dp else 12.dp, bottom = 6.dp)) {
                if (block.level == 2) {
                    Box(Modifier.width(28.dp).height(3.dp).clip(CircleShape).background(c.emberGradient))
                    Spacer(Modifier.height(10.dp))
                }
                Text(MarkdownParser.inline(block.text, c), style = style, color = c.text)
            }
        }
        is MdBlock.Paragraph -> Text(
            MarkdownParser.inline(block.text, c),
            modifier.fillMaxWidth().padding(vertical = 5.dp),
            style = t.bodyLarge,
            color = c.text.copy(alpha = 0.92f),
        )
        is MdBlock.ListBlock -> Column(modifier.fillMaxWidth().padding(vertical = 4.dp)) {
            block.items.forEach { item ->
                Row(Modifier.padding(start = (item.depth * 16).dp, top = 3.dp, bottom = 3.dp)) {
                    if (item.marker == "•") {
                        Box(Modifier.padding(top = 10.dp, end = 10.dp).size(6.dp).clip(CircleShape).background(c.ember))
                    } else {
                        Text(item.marker, style = t.bodyLarge.copy(fontWeight = FontWeight.SemiBold), color = c.ember, modifier = Modifier.widthIn(min = 22.dp).padding(end = 6.dp))
                    }
                    Text(MarkdownParser.inline(item.text, c), style = t.bodyLarge, color = c.text.copy(alpha = 0.92f), modifier = Modifier.weight(1f))
                }
            }
        }
        is MdBlock.Quote -> Row(
            modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(c.emberSoft)
                .height(IntrinsicSize.Min),
        ) {
            Box(Modifier.width(4.dp).fillMaxHeight().background(c.emberGradient))
            Text(MarkdownParser.inline(block.text, c), style = t.bodyLarge.copy(fontWeight = FontWeight.Medium), color = c.text, modifier = Modifier.padding(14.dp))
        }
        is MdBlock.Code -> SelectionContainer(modifier.fillMaxWidth().padding(vertical = 8.dp)) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(c.surface2)
                    .horizontalScroll(rememberScrollState())
                    .padding(14.dp),
            ) {
                Text(block.text, style = t.bodySmall.copy(fontFamily = FontFamily.Monospace), color = c.text)
            }
        }
        is MdBlock.Table -> TableView(block, modifier)
        MdBlock.Rule -> Box(modifier.fillMaxWidth().padding(vertical = 14.dp).height(1.dp).background(c.outline))
    }
}

@Composable
private fun TableView(table: MdBlock.Table, modifier: Modifier) {
    val c = Ember.colors
    val t = MaterialTheme.typography
    val cols = table.header.size.coerceAtLeast(1)
    // 2열 표는 화면 폭에 맞추고, 3열 이상은 가로 스크롤한다.
    val fit = cols <= 2
    val colWidth = if (cols >= 4) 150.dp else 170.dp
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
            .clip(shape)
            .border(1.dp, c.outline, shape)
            .then(if (fit) Modifier else Modifier.horizontalScroll(rememberScrollState())),
    ) {
        Column {
            Row(Modifier.background(c.surface2).height(IntrinsicSize.Min)) {
                table.header.forEachIndexed { i, h ->
                    Cell(h, header = true, modifier = if (fit) Modifier.weight(if (i == 0) 0.3f else 0.7f) else Modifier.width(if (i == 0) 112.dp else colWidth))
                }
            }
            table.rows.forEachIndexed { r, row ->
                Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline))
                Row(Modifier.background(if (r % 2 == 1) c.surface2.copy(alpha = 0.4f) else c.surface).height(IntrinsicSize.Min), verticalAlignment = Alignment.Top) {
                    row.forEachIndexed { i, cell ->
                        Cell(cell, header = false, first = i == 0, modifier = if (fit) Modifier.weight(if (i == 0) 0.3f else 0.7f) else Modifier.width(if (i == 0) 112.dp else colWidth))
                    }
                }
            }
        }
    }
}

@Composable
private fun Cell(text: String, header: Boolean, modifier: Modifier, first: Boolean = false) {
    val c = Ember.colors
    val t = MaterialTheme.typography
    Text(
        MarkdownParser.inline(text, c),
        modifier.fillMaxHeight().padding(horizontal = 12.dp, vertical = 10.dp),
        style = if (header) t.labelMedium.copy(fontWeight = FontWeight.Bold) else t.bodySmall.copy(fontWeight = if (first) FontWeight.SemiBold else FontWeight.Normal),
        color = if (header) c.textMuted else c.text,
    )
}
