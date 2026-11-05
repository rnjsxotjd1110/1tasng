package app.ember.ideas.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CloudOff
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.minimumInteractiveComponentSize
import app.ember.ideas.ui.text.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.ember.ideas.ai.AiError
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import kotlinx.coroutines.delay

// ------------------------------------------------------------------ 배경

/** 화면 상단에 은은한 불빛이 번지는 기본 배경. */
@Composable
fun EmberBackground(modifier: Modifier = Modifier, glow: Boolean = true, content: @Composable BoxScope.() -> Unit) {
    val c = Ember.colors
    Box(
        modifier
            .fillMaxSize()
            .background(c.bg)
            .drawBehind {
                if (glow) {
                    drawCircle(
                        Brush.radialGradient(
                            listOf(c.ember.copy(alpha = if (c.isDark) 0.16f else 0.10f), Color.Transparent),
                            center = Offset(size.width * 0.85f, -size.width * 0.05f),
                            radius = size.width * 0.9f,
                        ),
                        radius = size.width * 0.9f,
                        center = Offset(size.width * 0.85f, -size.width * 0.05f),
                    )
                }
            },
        content = content,
    )
}

// ------------------------------------------------------------------ 버튼

@Composable
private fun pressScale(source: MutableInteractionSource): Float {
    val pressed by source.collectIsPressedAsState()
    return animateFloatAsState(if (pressed) 0.97f else 1f, tween(120), label = "press").value
}

@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    icon: ImageVector? = null,
    height: Dp = 56.dp,
) {
    val c = Ember.colors
    val haptic = LocalHapticFeedback.current
    val source = remember { MutableInteractionSource() }
    val active = enabled && !loading
    Box(
        modifier
            .scale(pressScale(source))
            .heightIn(min = height)
            .clip(CircleShape)
            .background(if (active || loading) c.buttonGradient else Brush.linearGradient(listOf(c.surface3, c.surface3)))
            .clickable(source, null, enabled = active, role = Role.Button) {
                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onClick()
            }
            .padding(horizontal = 24.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(loading, transitionSpec = { fadeIn(tween(150)) togetherWith fadeOut(tween(150)) }, label = "btn") { isLoading ->
            if (isLoading) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.5.dp)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                    if (icon != null) {
                        Icon(icon, null, tint = if (active) Color.White else c.textFaint, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(
                        text,
                        style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                        color = if (active) Color.White else c.textFaint,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
fun SecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    height: Dp = 52.dp,
) {
    val c = Ember.colors
    val source = remember { MutableInteractionSource() }
    Row(
        modifier
            .scale(pressScale(source))
            .heightIn(min = height)
            .clip(CircleShape)
            .background(c.surface2)
            .border(1.dp, c.outline, CircleShape)
            .clickable(source, null, enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = if (enabled) c.text else c.textFaint, modifier = Modifier.size(19.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(text, style = MaterialTheme.typography.labelLarge, color = if (enabled) c.text else c.textFaint, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** 텍스트만 있는 조용한 버튼. 보조 동작에 쓴다. */
@Composable
fun GhostButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, color: Color? = null, enabled: Boolean = true) {
    val c = Ember.colors
    val tint = if (!enabled) c.textFaint else color ?: c.ember
    Row(
        modifier
            .clip(CircleShape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .heightIn(min = 48.dp)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
        }
        Text(text, style = MaterialTheme.typography.labelLarge, color = tint, maxLines = 1)
    }
}

@Composable
fun IconCircleButton(icon: ImageVector, contentDescription: String, onClick: () -> Unit, modifier: Modifier = Modifier, tint: Color? = null, filled: Boolean = true) {
    val c = Ember.colors
    Box(
        modifier
            .size(44.dp)
            .clip(CircleShape)
            .then(if (filled) Modifier.background(c.surface2) else Modifier)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = tint ?: c.text, modifier = Modifier.size(22.dp))
    }
}

// ------------------------------------------------------------------ 상단 바

@Composable
fun EmberTopBar(
    title: String,
    onBack: (() -> Unit)?,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    onTitleClick: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    val c = Ember.colors
    val s = LocalStrings.current
    Row(
        modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            IconCircleButton(Icons.AutoMirrored.Rounded.ArrowBack, s.back, onBack, filled = false)
            Spacer(Modifier.width(4.dp))
        } else Spacer(Modifier.width(8.dp))
        Column(
            Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .then(if (onTitleClick != null) Modifier.clickable(onClick = onTitleClick) else Modifier)
                .padding(horizontal = 4.dp, vertical = 2.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (!subtitle.isNullOrBlank()) {
                Text(subtitle, style = MaterialTheme.typography.labelMedium, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, content = actions)
    }
}

// ------------------------------------------------------------------ 칩·태그

@Composable
fun EmberChip(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leading: String? = null,
    icon: ImageVector? = null,
) {
    val c = Ember.colors
    val bg by animateColorAsState(if (selected) c.emberSoft else c.surface, tween(160), label = "chipbg")
    val border by animateColorAsState(if (selected) c.ember else c.outline, tween(160), label = "chipborder")
    Row(
        modifier
            .minimumInteractiveComponentSize()
            .heightIn(min = 40.dp)
            .clip(CircleShape)
            .background(bg)
            .border(1.dp, border, CircleShape)
            .clickable(role = Role.Checkbox, onClick = onClick)
            .semantics { stateDescription = if (selected) "✓" else "" }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (selected) {
            Icon(Icons.Rounded.Check, null, tint = c.ember, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
        } else if (icon != null) {
            Icon(icon, null, tint = c.textMuted, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
        }
        if (leading != null && !selected) {
            Text(leading, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.width(6.dp))
        }
        Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) c.text else c.textMuted, maxLines = 1)
    }
}

@Composable
fun Tag(text: String, modifier: Modifier = Modifier, color: Color? = null, strong: Boolean = false) {
    val c = Ember.colors
    val tint = color ?: c.textMuted
    Text(
        text,
        modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (strong) tint.copy(alpha = 0.16f) else c.surface2)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        style = MaterialTheme.typography.labelSmall,
        color = if (strong) tint else c.textMuted,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

// ------------------------------------------------------------------ 카드

@Composable
fun EmberCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    padding: PaddingValues = PaddingValues(18.dp),
    border: Boolean = true,
    highlight: Boolean = false,
    content: @Composable () -> Unit,
) {
    val c = Ember.colors
    val shape = RoundedCornerShape(22.dp)
    val source = remember { MutableInteractionSource() }
    Box(
        modifier
            .then(if (onClick != null) Modifier.scale(pressScale(source)) else Modifier)
            .clip(shape)
            .background(c.surface)
            .then(
                when {
                    highlight -> Modifier.border(BorderStroke(1.5.dp, c.emberGradient), shape)
                    border -> Modifier.border(1.dp, c.outline, shape)
                    else -> Modifier
                },
            )
            .then(if (onClick != null) Modifier.clickable(source, null, role = Role.Button, onClick = onClick) else Modifier)
            .padding(padding),
    ) { content() }
}

// ------------------------------------------------------------------ 진행 표시

@Composable
fun EmberProgress(progress: Float, modifier: Modifier = Modifier, height: Dp = 6.dp) {
    val c = Ember.colors
    val p by animateFloatAsState(progress.coerceIn(0f, 1f), tween(600, easing = FastOutSlowInEasing), label = "progress")
    Box(
        modifier
            .fillMaxWidth()
            .height(height)
            .clip(CircleShape)
            .background(c.surface3),
    ) {
        Box(
            Modifier
                .fillMaxWidth(p.coerceAtLeast(0.02f))
                .height(height)
                .clip(CircleShape)
                .background(c.emberGradient),
        )
    }
}

/** 불씨가 숨 쉬는 듯한 생각 중 표시. 문구는 몇 초마다 바뀐다. */
@Composable
fun ThinkingIndicator(lines: List<String>, modifier: Modifier = Modifier, title: String? = null) {
    val c = Ember.colors
    val t = rememberInfiniteTransition(label = "think")
    val rot by t.animateFloat(0f, 360f, infiniteRepeatable(tween(1600, easing = LinearEasing)), label = "rot")
    val pulse by t.animateFloat(0.86f, 1f, infiniteRepeatable(tween(1100, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "pulse")
    var index by remember { mutableIntStateOf(0) }
    LaunchedEffect(lines) {
        while (lines.size > 1) {
            delay(2600)
            index = (index + 1) % lines.size
        }
    }
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(84.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(84.dp)) {
                rotate(rot) {
                    drawArc(
                        brush = Brush.sweepGradient(listOf(Color.Transparent, c.ember, c.gold)),
                        startAngle = 0f, sweepAngle = 300f, useCenter = false,
                        style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round),
                    )
                }
            }
            Box(
                Modifier
                    .size(40.dp)
                    .scale(pulse)
                    .clip(CircleShape)
                    .background(c.emberGradient),
            )
        }
        Spacer(Modifier.height(20.dp))
        if (title != null) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = c.text, textAlign = TextAlign.Center)
            Spacer(Modifier.height(6.dp))
        }
        AnimatedContent(lines.getOrNull(index) ?: "", transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) }, label = "line") { line ->
            Text(line, style = MaterialTheme.typography.bodyMedium, color = c.textMuted, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 300.dp))
        }
    }
}

// ------------------------------------------------------------------ 오류·빈 상태

@Composable
fun ErrorPanel(
    error: AiError,
    onRetry: () -> Unit,
    onFixKey: () -> Unit,
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null,
    dismissLabel: String? = null,
) {
    val c = Ember.colors
    val s = LocalStrings.current
    val keyProblem = error is AiError.InvalidKey || error is AiError.NoKey
    val icon = when (error) {
        is AiError.Offline -> Icons.Rounded.CloudOff
        is AiError.InvalidKey, is AiError.NoKey -> Icons.Rounded.Key
        else -> Icons.Rounded.ErrorOutline
    }
    EmberCard(modifier.fillMaxWidth(), highlight = false) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(40.dp).clip(CircleShape).background(c.danger.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
                    Icon(icon, null, tint = c.danger, modifier = Modifier.size(22.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(s.errorTitle(error), style = MaterialTheme.typography.titleSmall, color = c.text)
                    Spacer(Modifier.height(2.dp))
                    Text(s.errorBody(error), style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                    if (error !is AiError.InvalidKey && error !is AiError.NoKey && error !is AiError.Refused) {
                        Spacer(Modifier.height(4.dp))
                        Text(s.errorSafeNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                if (keyProblem) {
                    PrimaryButton(s.fixKey, onFixKey, Modifier.weight(1f), icon = Icons.Rounded.Key, height = 48.dp)
                } else {
                    PrimaryButton(s.retry, onRetry, Modifier.weight(1f), icon = Icons.Rounded.Refresh, height = 48.dp)
                }
                if (onDismiss != null) GhostButton(dismissLabel ?: s.close, onDismiss, color = c.textMuted)
            }
        }
    }
}

@Composable
fun EmptyState(icon: ImageVector, title: String, body: String, modifier: Modifier = Modifier, action: (@Composable () -> Unit)? = null) {
    val c = Ember.colors
    Column(modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(72.dp).clip(CircleShape).background(c.emberSoft), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = c.ember, modifier = Modifier.size(34.dp))
        }
        Spacer(Modifier.height(18.dp))
        Text(title, style = MaterialTheme.typography.titleLarge, color = c.text, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(body, style = MaterialTheme.typography.bodyMedium, color = c.textMuted, textAlign = TextAlign.Center)
        if (action != null) {
            Spacer(Modifier.height(22.dp))
            action()
        }
    }
}

@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier, trailing: (@Composable () -> Unit)? = null) {
    val c = Ember.colors
    Row(modifier.fillMaxWidth().heightIn(min = 36.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = MaterialTheme.typography.titleSmall, color = c.textMuted, modifier = Modifier.weight(1f))
        trailing?.invoke()
    }
}

/** 선택 표시용 작은 체크 원. 단일 선택은 점, 다중 선택은 체크. */
@Composable
fun SelectMark(selected: Boolean, multi: Boolean, modifier: Modifier = Modifier) {
    val c = Ember.colors
    val shape = if (multi) RoundedCornerShape(7.dp) else CircleShape
    Box(
        modifier
            .size(24.dp)
            .clip(shape)
            .then(if (selected) Modifier.background(c.ember) else Modifier.border(1.5.dp, c.control, shape)),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedVisibility(selected, enter = scaleIn(tween(140)) + fadeIn(), exit = scaleOut(tween(100)) + fadeOut()) {
            Icon(Icons.Rounded.Check, null, tint = c.onEmber, modifier = Modifier.size(16.dp))
        }
    }
}


/** 하단 고정 영역 위로 내용이 부드럽게 사라지게 하는 페이드. 레이아웃 크기에는 영향을 주지 않는다. */
fun Modifier.topFade(color: Color, height: Dp = 28.dp): Modifier = this.drawBehind {
    val h = height.toPx()
    drawRect(
        Brush.verticalGradient(listOf(color.copy(alpha = 0f), color), startY = -h, endY = 0f),
        topLeft = Offset(0f, -h),
        size = androidx.compose.ui.geometry.Size(size.width, h),
    )
    drawRect(color)
}
