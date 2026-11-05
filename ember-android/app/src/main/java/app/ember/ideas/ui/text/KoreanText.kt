package app.ember.ideas.ui.text

import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit

/**
 * 한국어 어절 단위 줄바꿈(CSS 의 word-break: keep-all).
 * 한글 음절과 맞닿은 글자 사이에 WORD JOINER(U+2060)를 넣어 단어 중간에서 줄이 바뀌지 않게 한다.
 * 공백·이모지·대리 쌍에는 넣지 않아 그림 문자가 깨지지 않는다.
 */
object KoreanLineBreak {
    private const val WJ = '⁠'

    private fun isHangul(c: Char) = c in '가'..'힣' || c in 'ㄱ'..'ㆎ'

    private fun joinable(c: Char) = !c.isWhitespace() && !c.isSurrogate() && c != '‍' && c !in '︀'..'️' &&
        c != '/' && c != '·' && c != '→' && c != '—' && c != WJ

    private fun needsJoin(a: Char, b: Char) = joinable(a) && joinable(b) && (isHangul(a) || isHangul(b))

    fun keepAll(s: String): String {
        if (s.none(::isHangul)) return s
        val sb = StringBuilder(s.length + s.length / 2)
        for (i in s.indices) {
            if (i > 0 && needsJoin(s[i - 1], s[i])) sb.append(WJ)
            sb.append(s[i])
        }
        return sb.toString()
    }

    /** 스타일 구간을 유지한 채 같은 처리를 한다. */
    fun keepAll(a: AnnotatedString): AnnotatedString {
        val s = a.text
        if (s.none(::isHangul)) return a
        val map = IntArray(s.length + 1)
        val sb = StringBuilder(s.length + s.length / 2)
        for (i in s.indices) {
            if (i > 0 && needsJoin(s[i - 1], s[i])) sb.append(WJ)
            map[i] = sb.length
            sb.append(s[i])
        }
        map[s.length] = sb.length
        val b = AnnotatedString.Builder(sb.toString())
        a.spanStyles.forEach { b.addStyle(it.item, map[it.start], map[it.end]) }
        a.paragraphStyles.forEach { b.addStyle(it.item, map[it.start], map[it.end]) }
        return b.toAnnotatedString()
    }
}

/** 앱 전체에서 쓰는 Text. material3 Text 와 같은 모양이며 한국어 어절 줄바꿈을 적용한다. */
@Composable
fun Text(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    fontSize: TextUnit = TextUnit.Unspecified,
    textAlign: TextAlign? = null,
    overflow: TextOverflow = TextOverflow.Clip,
    maxLines: Int = Int.MAX_VALUE,
    minLines: Int = 1,
    onTextLayout: ((TextLayoutResult) -> Unit)? = null,
    style: TextStyle = LocalTextStyle.current,
) {
    androidx.compose.material3.Text(
        text = KoreanLineBreak.keepAll(text),
        modifier = modifier,
        color = color,
        fontSize = fontSize,
        textAlign = textAlign,
        overflow = overflow,
        maxLines = maxLines,
        minLines = minLines,
        onTextLayout = onTextLayout,
        style = style,
    )
}

@Composable
fun Text(
    text: AnnotatedString,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    textAlign: TextAlign? = null,
    overflow: TextOverflow = TextOverflow.Clip,
    maxLines: Int = Int.MAX_VALUE,
    style: TextStyle = LocalTextStyle.current,
) {
    androidx.compose.material3.Text(
        text = KoreanLineBreak.keepAll(text),
        modifier = modifier,
        color = color,
        textAlign = textAlign,
        overflow = overflow,
        maxLines = maxLines,
        style = style,
    )
}
