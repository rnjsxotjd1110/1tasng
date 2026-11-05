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
import app.ember.ideas.ui.components.Tag
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.Icon
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.border
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
                    Box(Modifier.size(width = 300.dp, height = 280.dp), contentAlignment = Alignment.Center) {
                        Canvas(Modifier.size(280.dp)) { drawCircle(Brush.radialGradient(listOf(c.ember.copy(alpha = 0.20f), Color.Transparent)), radius = size.width * 0.5f) }
                        OnboardingMock(art)
                    }
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


/** 온보딩 그림: 실제 화면 요소를 축소해 보여 준다. */
@Composable
private fun OnboardingMock(page: Int) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ko = s.isKorean
    val t = MaterialTheme.typography
    @Composable
    fun card(modifier: Modifier = Modifier, content: @Composable () -> Unit) = Box(
        modifier.clip(RoundedCornerShape(20.dp)).background(c.surface).border(1.dp, c.outline, RoundedCornerShape(20.dp)).padding(14.dp),
    ) { content() }
    when (page) {
        0 -> card(Modifier.width(260.dp)) {
            Column {
                Text(if (ko) "어떤 분위기에 끌리나요?" else "Which mood draws you in?", style = t.titleSmall, color = c.text)
                Spacer(Modifier.height(10.dp))
                listOf(if (ko) "아늑하고 따뜻한" else "Cozy", if (ko) "몽환적인" else "Dreamy", if (ko) "긴장감 넘치는" else "Tense").forEachIndexed { i, label ->
                    val sel = i == 1
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 4.dp).clip(RoundedCornerShape(12.dp))
                            .background(if (sel) c.emberSoft else c.surface2)
                            .border(if (sel) 1.5.dp else 0.dp, if (sel) c.ember else Color.Transparent, RoundedCornerShape(12.dp))
                            .padding(horizontal = 10.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.size(22.dp).clip(RoundedCornerShape(7.dp)).background(if (sel) c.ember else c.surface3), contentAlignment = Alignment.Center) {
                            Text(('A' + i).toString(), style = t.labelSmall, color = if (sel) c.onEmber else c.textMuted)
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(label, style = t.labelMedium, color = c.text)
                    }
                }
            }
        }
        1 -> Box {
            card(Modifier.width(240.dp).offset(x = 22.dp, y = (-18).dp).alpha(0.55f)) {
                Column { Text(if (ko) "우산 대여소" else "Umbrella Stand", style = t.titleSmall, color = c.text); Spacer(Modifier.height(36.dp)) }
            }
            card(Modifier.width(250.dp).offset(y = 14.dp)) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(if (ko) "지하철 정원사" else "Subway Gardener", style = t.titleMedium, color = c.text, modifier = Modifier.weight(1f))
                        Icon(Icons.Rounded.Favorite, null, tint = c.emberDeep, modifier = Modifier.size(18.dp))
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(if (ko) "정거장마다 씨앗을 심어 노선도를 꽃길로 바꾸는 퍼즐" else "Plant a seed per stop and turn the map into flowers", style = t.bodySmall, color = c.textMuted, maxLines = 2)
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Tag(if (ko) "소형" else "Small"); Tag(if (ko) "1인 3개월" else "Solo, 3 mo"); Tag(s.difficulty(2), color = c.success, strong = true)
                    }
                }
            }
        }
        else -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
            card(Modifier.width(250.dp)) {
                Column {
                    Box(Modifier.width(26.dp).height(3.dp).clip(CircleShape).background(c.emberGradient))
                    Spacer(Modifier.height(6.dp))
                    Text(if (ko) "2. 핵심 재미와 루프" else "2. Core loop", style = t.titleSmall, color = c.text)
                    Spacer(Modifier.height(6.dp))
                    listOf(if (ko) "30초: 씨앗을 놓고 꽃을 피워요" else "30s: place a seed, watch it bloom", if (ko) "5분: 노선 하나를 꽃길로" else "5m: fill a whole line").forEach {
                        Row(Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(5.dp).clip(CircleShape).background(c.ember)); Spacer(Modifier.width(8.dp))
                            Text(it, style = t.bodySmall, color = c.textMuted)
                        }
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(
                Modifier.clip(CircleShape).background(c.buttonGradient).padding(horizontal = 18.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.AutoMirrored.Rounded.Send, null, tint = Color.White, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text(s.continueInClaude, style = t.labelLarge, color = Color.White)
            }
        }
    }
}
