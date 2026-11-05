package app.ember.ideas.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material3.MaterialTheme
import app.ember.ideas.ui.text.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.ember.ideas.ui.components.EmberBackground
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberColors
import kotlinx.coroutines.launch

@Composable
fun OnboardingScreen(onFinish: () -> Unit, initialPage: Int = 0) {
    val s = LocalStrings.current
    val c = Ember.colors
    val pager = rememberPagerState(initialPage) { 3 }
    val scope = rememberCoroutineScope()
    val pages = listOf(
        Triple(s.onb1Title, s.onb1Body, 0),
        Triple(s.onb2Title, s.onb2Body, 1),
        Triple(s.onb3Title, s.onb3Body, 2),
    )
    EmberBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Ember", style = MaterialTheme.typography.titleLarge, color = c.text, modifier = Modifier.padding(start = 12.dp).weight(1f))
                GhostButton(s.skip, onFinish, color = c.textMuted, modifier = Modifier.alpha(if (pager.currentPage < 2) 1f else 0f), enabled = pager.currentPage < 2)
            }
            HorizontalPager(pager, Modifier.weight(1f)) { page ->
                val (title, body, art) = pages[page]
                Column(Modifier.fillMaxSize().padding(horizontal = 28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    Canvas(Modifier.size(260.dp)) { drawArt(art, c) }
                    Spacer(Modifier.height(36.dp))
                    Text(title, style = MaterialTheme.typography.headlineLarge, color = c.text, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(14.dp))
                    Text(body, style = MaterialTheme.typography.bodyLarge, color = c.textMuted, textAlign = TextAlign.Center)
                }
            }
            Row(Modifier.fillMaxWidth().padding(vertical = 18.dp), horizontalArrangement = Arrangement.Center) {
                repeat(3) { i ->
                    val selected = pager.currentPage == i
                    val w by animateDpAsState(if (selected) 26.dp else 8.dp, label = "dot")
                    val col by animateColorAsState(if (selected) c.ember else c.surface3, label = "dotc")
                    Box(Modifier.padding(horizontal = 4.dp).height(8.dp).width(w).clip(CircleShape).background(col))
                }
            }
            PrimaryButton(
                text = if (pager.currentPage == 2) s.getStarted else s.next,
                onClick = { if (pager.currentPage == 2) onFinish() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) } },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                icon = if (pager.currentPage == 2) null else Icons.AutoMirrored.Rounded.ArrowForward,
            )
            Spacer(Modifier.height(20.dp))
        }
    }
}

/** 페이지별 일러스트: 질문 카드 → 아이디어 카드 → 설계서. 모두 벡터로 그려 어떤 해상도에서도 선명하다. */
private fun DrawScope.drawArt(kind: Int, c: EmberColors) {
    val w = size.width
    val h = size.height
    val grad = Brush.linearGradient(listOf(Color(0xFFFFB067), Color(0xFFFF6A3D), Color(0xFFEE3F5C)), Offset(0f, 0f), Offset(w, h))
    drawCircle(Brush.radialGradient(listOf(c.ember.copy(alpha = 0.22f), Color.Transparent)), radius = w * 0.5f)
    val r = CornerRadius(w * 0.06f)
    when (kind) {
        0 -> {
            // 질문 카드와 선택지
            drawRoundRect(c.surface2, Offset(w * 0.14f, h * 0.12f), Size(w * 0.72f, h * 0.76f), r)
            drawRoundRect(c.surface3, Offset(w * 0.22f, h * 0.2f), Size(w * 0.44f, h * 0.05f), CornerRadius(20f))
            drawRoundRect(c.surface3, Offset(w * 0.22f, h * 0.28f), Size(w * 0.30f, h * 0.035f), CornerRadius(20f))
            for (i in 0 until 3) {
                val y = h * (0.40f + i * 0.14f)
                val sel = i == 1
                drawRoundRect(if (sel) c.ember.copy(alpha = 0.18f) else c.surface, Offset(w * 0.22f, y), Size(w * 0.56f, h * 0.10f), CornerRadius(w * 0.03f))
                if (sel) drawRoundRect(grad, Offset(w * 0.22f, y), Size(w * 0.56f, h * 0.10f), CornerRadius(w * 0.03f), style = Stroke(4f))
                drawCircle(if (sel) c.ember else c.surface3, w * 0.025f, Offset(w * 0.29f, y + h * 0.05f))
                drawRoundRect(c.surface3, Offset(w * 0.35f, y + h * 0.035f), Size(w * (0.28f - i * 0.04f), h * 0.03f), CornerRadius(20f))
            }
        }
        1 -> {
            // 겹쳐진 아이디어 카드 세 장
            for (i in 2 downTo 0) {
                val off = i * w * 0.07f
                drawRoundRect(if (i == 0) c.surface else c.surface2, Offset(w * 0.16f + off, h * 0.18f - off * 0.6f), Size(w * 0.56f, h * 0.62f), r)
            }
            drawRoundRect(grad, Offset(w * 0.16f, h * 0.18f), Size(w * 0.56f, h * 0.62f), r, style = Stroke(5f))
            drawCircle(grad, w * 0.07f, Offset(w * 0.30f, h * 0.32f))
            drawRoundRect(c.surface3, Offset(w * 0.24f, h * 0.45f), Size(w * 0.40f, h * 0.045f), CornerRadius(20f))
            drawRoundRect(c.surface3, Offset(w * 0.24f, h * 0.53f), Size(w * 0.32f, h * 0.035f), CornerRadius(20f))
            drawRoundRect(c.surface3, Offset(w * 0.24f, h * 0.60f), Size(w * 0.36f, h * 0.035f), CornerRadius(20f))
            // 반짝임
            spark(Offset(w * 0.80f, h * 0.20f), w * 0.05f, c.gold)
            spark(Offset(w * 0.86f, h * 0.36f), w * 0.03f, c.ember)
        }
        else -> {
            // 설계서와 Claude 로 넘어가는 화살표
            drawRoundRect(c.surface2, Offset(w * 0.12f, h * 0.14f), Size(w * 0.50f, h * 0.72f), r)
            drawRoundRect(grad, Offset(w * 0.18f, h * 0.22f), Size(w * 0.26f, h * 0.04f), CornerRadius(20f))
            for (i in 0 until 6) {
                drawRoundRect(c.surface3, Offset(w * 0.18f, h * (0.32f + i * 0.08f)), Size(w * (0.38f - (i % 3) * 0.06f), h * 0.03f), CornerRadius(20f))
            }
            drawCircle(grad, w * 0.13f, Offset(w * 0.74f, h * 0.52f))
            val p = androidx.compose.ui.graphics.Path().apply {
                moveTo(w * 0.69f, h * 0.47f); lineTo(w * 0.79f, h * 0.52f); lineTo(w * 0.69f, h * 0.57f)
            }
            drawPath(p, Color.White, style = Stroke(w * 0.022f, cap = androidx.compose.ui.graphics.StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
        }
    }
}

private fun DrawScope.spark(center: Offset, r: Float, color: Color) {
    val p = androidx.compose.ui.graphics.Path().apply {
        moveTo(center.x, center.y - r)
        quadraticTo(center.x, center.y, center.x + r, center.y)
        quadraticTo(center.x, center.y, center.x, center.y + r)
        quadraticTo(center.x, center.y, center.x - r, center.y)
        quadraticTo(center.x, center.y, center.x, center.y - r)
        close()
    }
    drawPath(p, color)
}
