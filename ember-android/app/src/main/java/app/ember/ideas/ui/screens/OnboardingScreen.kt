package app.ember.ideas.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.IntrinsicSize
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
                        OnboardingMock(art)
                    }
                    Spacer(Modifier.height(36.dp))
                    Text(title, style = MaterialTheme.typography.headlineLarge, color = c.text, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(14.dp))
                    Text(body, style = MaterialTheme.typography.bodyLarge, color = c.textMuted, textAlign = TextAlign.Center)
                }
            }
            Row(Modifier.fillMaxWidth().padding(vertical = 18.dp), horizontalArrangement = Arrangement.Center) {
                // 세 단계를 같은 길이의 막대로 보여 주고, 지나온 단계까지 채운다.
                repeat(3) { i ->
                    val col by animateColorAsState(if (i <= pager.currentPage) c.ember else c.surface3, label = "stepc")
                    Box(Modifier.padding(horizontal = 3.dp).height(3.dp).width(28.dp).background(col))
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

/** 온보딩 그림: 실제 화면 요소를 축소해 보여 준다. */
@Composable
private fun OnboardingMock(page: Int) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ko = s.isKorean
    val t = MaterialTheme.typography
    @Composable
    fun card(modifier: Modifier = Modifier, content: @Composable () -> Unit) = Box(
        modifier.clip(RoundedCornerShape(8.dp)).background(c.surface).border(1.dp, c.outline, RoundedCornerShape(8.dp)).padding(14.dp),
    ) { content() }
    when (page) {
        0 -> card(Modifier.width(260.dp)) {
            Column {
                Text(if (ko) "어떤 분위기에 끌리나요?" else "Which mood draws you in?", style = t.titleSmall, color = c.text)
                Spacer(Modifier.height(10.dp))
                listOf(if (ko) "아늑하고 따뜻한" else "Cozy", if (ko) "몽환적인" else "Dreamy", if (ko) "긴장감 넘치는" else "Tense").forEachIndexed { i, label ->
                    val sel = i == 1
                    val shape = RoundedCornerShape(8.dp)
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 4.dp).clip(shape)
                            .background(if (sel) c.emberSoft else c.surface)
                            .border(if (sel) 1.5.dp else 1.dp, if (sel) c.ember else c.outline, shape)
                            .height(IntrinsicSize.Min),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(('A' + i).toString(), style = t.titleSmall, color = if (sel) c.ember else c.textFaint, textAlign = TextAlign.Center, modifier = Modifier.width(34.dp))
                        Box(Modifier.width(1.dp).fillMaxHeight().background(if (sel) c.ember.copy(alpha = 0.5f) else c.outline))
                        Text(label, style = t.labelMedium, color = c.text, modifier = Modifier.padding(horizontal = 10.dp, vertical = 9.dp))
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
                        Icon(Icons.Rounded.Favorite, null, tint = c.ember, modifier = Modifier.size(18.dp))
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
                    Box(Modifier.width(26.dp).height(3.dp).background(c.ember))
                    Spacer(Modifier.height(6.dp))
                    Text(if (ko) "2. 핵심 재미와 루프" else "2. Core loop", style = t.titleSmall, color = c.text)
                    Spacer(Modifier.height(6.dp))
                    listOf(if (ko) "30초: 씨앗을 놓고 꽃을 피워요" else "30s: place a seed, watch it bloom", if (ko) "5분: 노선 하나를 꽃길로" else "5m: fill a whole line").forEach {
                        Row(Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(width = 6.dp, height = 2.dp).background(c.ember)); Spacer(Modifier.width(8.dp))
                            Text(it, style = t.bodySmall, color = c.textMuted)
                        }
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(
                Modifier.clip(RoundedCornerShape(8.dp)).background(c.surface2).border(1.dp, c.outline, RoundedCornerShape(8.dp)).padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.AutoMirrored.Rounded.Send, null, tint = c.ember, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(8.dp))
                Text(s.continueInClaude, style = t.labelMedium, color = c.textMuted)
            }
        }
    }
}
