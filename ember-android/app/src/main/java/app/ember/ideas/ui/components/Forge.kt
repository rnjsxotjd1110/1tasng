package app.ember.ideas.ui.components

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import app.ember.ideas.data.OpKind
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape
import kotlinx.coroutines.launch

// ------------------------------------------------------------------ 대장간 아이콘

/** 시안의 선 아이콘을 그대로 옮긴 벡터. 24 격자, 선 굵기 1.8. */
object ForgeIcons {
    private fun line(name: String, vararg paths: String, width: Float = 1.8f): ImageVector {
        val b = ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f)
        paths.forEach { d ->
            b.addPath(
                PathParser().parsePathString(d).toNodes(),
                stroke = SolidColor(Color.Black),
                strokeLineWidth = width,
                strokeLineCap = StrokeCap.Round,
                strokeLineJoin = StrokeJoin.Round,
            )
        }
        return b.build()
    }

    val Ore = line("ore", "M7 4h7l5 6-7 10L5 10z", "M5 10h14", "M12 20 9.5 10 12 4")
    val OreSimple = line("ore2", "M7 4h7l5 6-7 10L5 10z", "M5 10h14")
    val Furnace = line("furnace", "M12 3c2 3.5 6 5.5 6 10.5A6 6 0 0 1 6 13.5c0-3 1.5-4.5 3-6 0 2 1 3.5 2.3 3.8C10.7 8.4 11 5.5 12 3z")
    val Blueprint = line("blueprint", "M5.5 3h13A1.5 1.5 0 0 1 20 4.5v15a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 19.5v-15A1.5 1.5 0 0 1 5.5 3z", "M8 8h8M8 12h8M8 16h5")
    val Anvil = line("anvil", "M4 10h12l4-3v6l-4-3", "M7 10v4h6v-4M6 20h8l-2-6H8z")
    val Monitor = line("monitor", "M4.5 4h15A1.5 1.5 0 0 1 21 5.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 14.5v-9A1.5 1.5 0 0 1 4.5 4z", "M8 20h8M12 16v4")
    val Game = line("game", "M6 7h12a4 4 0 0 1 4 4v3a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4v-3a4 4 0 0 1 4-4z", "M7 11v3M5.5 12.5h3M15.5 12h.01M18 13.5h.01")
    val Phone = line("phone", "M8.5 2h7A2.5 2.5 0 0 1 18 4.5v15a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 6 19.5v-15A2.5 2.5 0 0 1 8.5 2z", "M11 18h2")
    val Globe = line("globe", "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z", "M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18")
    val Unknown = line("unknown", "M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17.5h.01", "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z")
    val Mic = line("mic", "M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z", "M6 11a6 6 0 0 0 12 0M12 17v4")
    val Image = line("image", "M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z", "M8.5 10a1.5 1.5 0 1 0 0-3a1.5 1.5 0 1 0 0 3z", "M20 15l-5-5L5 20")
    val Pin = line("pin", "M9 4h6l-1 5 3 3H7l3-3z", "M12 12v8")
    val Mold = line("mold", "M4 6h16v12H4z", "M8 6v12M4 12h4")
    val Send = line("send", "M4 12l16-8-6 16-2-7z", "M12 13l8-9")
}

// ------------------------------------------------------------------ 움직임

/** 기기의 '애니메이션 삭제'(움직임 줄이기)가 켜져 있으면 색 변화만 남긴다. */
@Composable
fun reduceMotion(): Boolean {
    val ctx = LocalContext.current
    return remember {
        runCatching { Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }.getOrDefault(false)
    }
}

// ------------------------------------------------------------------ 열기 막대

/** 프로젝트가 대장간의 어느 단계에 있는지: 원석 → 가열 → 단조 → 도면. */
data class Heat(
    /** 다 찬 칸 수(0~4). */
    val full: Int,
    /** 다음 칸이 찬 정도(0~1). */
    val partial: Float,
    /** 도면이 완성되어 마지막 칸이 강철색으로 식었는지. */
    val tempered: Boolean,
) {
    /** 지금 진행 중인 칸(0~3). */
    val current: Int get() = full.coerceAtMost(3)

    companion object {
        fun of(p: Project, op: OpKind? = null): Heat = when (p.stage) {
            ProjectStage.INTERVIEW -> Heat(1, (p.turns.lastOrNull()?.progress ?: 0) / 100f, false)
            ProjectStage.IDEAS -> Heat(2, 0f, false)
            ProjectStage.DESIGN_INTERVIEW -> Heat(2, (p.design?.turns?.lastOrNull()?.progress ?: 0) / 100f, false)
            ProjectStage.DOCUMENT -> {
                val v = p.design?.latest
                when {
                    op == OpKind.WRITING || op == OpKind.REVISING -> Heat(3, 0.5f, false)
                    v != null && v.complete -> Heat(4, 0f, true)
                    else -> Heat(3, 0.6f, false)
                }
            }
        }
    }
}

/**
 * 네 칸짜리 열기 막대. 칸이 0.7초 동안 차오르고, [flowing] 이면 지금 칸에 쇳물 무늬가 흐른다.
 * [labels] 를 주면 칸 아래에 단계 이름을 적는다.
 */
@Composable
fun HeatGauge(
    heat: Heat,
    modifier: Modifier = Modifier,
    barHeight: androidx.compose.ui.unit.Dp = 4.dp,
    flowing: Boolean = false,
    labels: List<String>? = null,
    currentLabel: String? = null,
) {
    val c = Ember.colors
    val still = reduceMotion()
    val colors = listOf(c.ember, c.heat, c.gold, if (heat.tempered) c.steel else c.gold)
    val fill by animateFloatAsState(heat.full + heat.partial, tween(if (still) 0 else 700), label = "heat")
    val flow = if (flowing && !still) {
        val t = rememberInfiniteTransition(label = "flow")
        t.animateFloat(0f, 1f, infiniteRepeatable(tween(1100, easing = LinearEasing), RepeatMode.Restart), label = "flowT").value
    } else -1f
    Column(modifier) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            for (i in 0 until 4) {
                val f = (fill - i).coerceIn(0f, 1f)
                Canvas(Modifier.weight(1f).height(barHeight)) {
                    drawRect(c.surface3)
                    if (f > 0f) drawRect(colors[i], size = Size(size.width * f, size.height))
                    // 지금 칸에서 흐르는 쇳물 무늬(정수 픽셀 단위로 끊어 움직인다).
                    if (flow >= 0f && i == heat.current && !heat.tempered) {
                        val w = size.width * 0.18f
                        val x = kotlin.math.floor((size.width + w) * flow - w)
                        drawRect(c.gold.copy(alpha = 0.85f), topLeft = Offset(x.coerceAtLeast(0f), 0f), size = Size(w.coerceAtMost(size.width - x.coerceAtLeast(0f)), size.height))
                    }
                }
            }
        }
        if (labels != null) {
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                labels.forEachIndexed { i, l ->
                    val isCur = i == heat.current && !heat.tempered
                    val done = heat.tempered && i == 3
                    Text(
                        if (isCur && currentLabel != null) currentLabel else l,
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = if (isCur || done) FontWeight.SemiBold else FontWeight.Medium),
                        color = when {
                            done -> c.steel
                            isCur -> c.text
                            i < heat.full -> c.textMuted
                            else -> c.textFaint
                        },
                        modifier = Modifier.weight(1f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

// ------------------------------------------------------------------ 단조판

/** 답한 질문이 식어서 쌓인 얇은 판. 거푸집에서 온 답은 쇳물색, 직접 답한 것은 불씨색 막대. */
@Composable
fun Plate(label: String, text: String, fromMold: Boolean, modifier: Modifier = Modifier, fill: Color? = null, onClick: (() -> Unit)? = null) {
    val c = Ember.colors
    val accent = if (fromMold) c.gold else c.ember
    Row(
        modifier
            .fillMaxWidth()
            .background(fill ?: c.surface)
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier)
            .heightIn(min = 30.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.width(3.dp).height(30.dp).background(accent))
        Spacer(Modifier.width(10.dp))
        Text(label, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = accent)
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.labelMedium, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f).padding(end = 10.dp))
    }
}

// ------------------------------------------------------------------ 점수 막대

/** 1~5 점을 다섯 칸 막대로 보여 준다. */
@Composable
fun ScoreBar(label: String, value: Int, color: Color, modifier: Modifier = Modifier) {
    val c = Ember.colors
    Column(modifier.semantics(mergeDescendants = true) { contentDescription = "$label $value/5" }) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            for (i in 1..5) Box(Modifier.weight(1f).height(3.dp).background(if (i <= value) color else c.surface3))
        }
    }
}

// ------------------------------------------------------------------ 두드리기 버튼

/**
 * 답을 보내는 주 버튼. 누르면 3px 눌렸다 돌아오고(0.24초, 4프레임) 불티 4개가 튄다.
 * 움직임 줄이기가 켜져 있으면 색만 바뀐다.
 */
@Composable
fun StrikeButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, height: androidx.compose.ui.unit.Dp = 54.dp) {
    val c = Ember.colors
    val haptic = LocalHapticFeedback.current
    val still = reduceMotion()
    val scope = rememberCoroutineScope()
    val press = remember { Animatable(0f) }
    val spark = remember { Animatable(1f) }
    var sparkSeed by remember { mutableIntStateOf(0) }
    val source = remember { MutableInteractionSource() }
    Box(modifier.heightIn(min = height)) {
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(min = height)
                .offset { IntOffset(0, (press.value * 3).toInt().dp.roundToPx()) }
                .clip(EmberShape.control)
                .background(if (enabled) c.ember else c.surface3)
                .clickable(source, null, enabled = enabled, role = Role.Button) {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    if (!still) {
                        sparkSeed++
                        scope.launch {
                            // 4프레임으로 끊어 눌렀다 돌아온다: 0 → 1 → 1 → 0.
                            for (v in listOf(1f, 1f, 0.34f, 0f)) { press.snapTo(v); kotlinx.coroutines.delay(60) }
                        }
                        scope.launch { spark.snapTo(0f); spark.animateTo(1f, tween(360, easing = LinearEasing)) }
                    }
                    onClick()
                }
                .padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text, style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold), color = if (enabled) c.onEmber else c.textFaint, maxLines = 1)
        }
        if (spark.value < 1f) {
            val p = spark.value
            val seed = sparkSeed
            Canvas(Modifier.matchParentSize()) {
                val cx = size.width / 2
                val top = 0f
                for (k in 0 until 4) {
                    val dx = listOf(-34f, -12f, 14f, 36f)[(k + seed) % 4] * density
                    val rise = (10f + 6f * k) * density * p
                    val x = kotlin.math.floor(cx + dx * p)
                    val y = kotlin.math.floor(top - rise)
                    drawRect(if (k % 2 == 0) c.gold else c.heat, topLeft = Offset(x, y), size = Size(3f * density, 3f * density), alpha = 1f - p)
                }
            }
        }
    }
}

// ------------------------------------------------------------------ 큰 선택 타일

/** 화로의 '무엇을 만들까요' 타일. 선택되면 불씨색 테두리와 옅은 바탕. */
@Composable
fun ForgeTile(label: String, icon: ImageVector, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val c = Ember.colors
    val haptic = LocalHapticFeedback.current
    Column(
        modifier
            .clip(EmberShape.control)
            .background(if (selected) c.emberSoft else c.surface)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.ember else c.outline, EmberShape.control)
            .clickable(role = Role.RadioButton) {
                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onClick()
            }
            .heightIn(min = 72.dp)
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        androidx.compose.material3.Icon(icon, null, tint = if (selected) c.ember else c.textMuted, modifier = Modifier.width(22.dp).height(22.dp))
        Spacer(Modifier.height(8.dp))
        Text(label, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = if (selected) c.text else c.textMuted, maxLines = 1)
    }
}
