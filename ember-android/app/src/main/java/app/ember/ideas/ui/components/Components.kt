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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
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
import androidx.compose.ui.graphics.lerp
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
import app.ember.ideas.ui.theme.EmberShape
import kotlinx.coroutines.delay

// ------------------------------------------------------------------ 배경

/** 모든 화면의 바탕. 장식 없이 단색으로 두어 글과 선택지가 먼저 보이게 한다. */
@Composable
fun EmberBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    val c = Ember.colors
    Box(modifier.fillMaxSize().background(c.bg), content = content)
}

// ------------------------------------------------------------------ 버튼

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
    val pressed by source.collectIsPressedAsState()
    // 누르면 살짝 어두워진다. 크기는 바꾸지 않는다.
    val fill by animateColorAsState(
        when {
            !active && !loading -> c.surface3
            pressed -> lerp(c.ember, Color.Black, 0.18f)
            else -> c.ember
        },
        tween(120), label = "primary",
    )
    val ink = if (active || loading) c.onEmber else c.textFaint
    Box(
        modifier
            .heightIn(min = height)
            .clip(EmberShape.control)
            .background(fill)
            .clickable(source, null, enabled = active, role = Role.Button) {
                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onClick()
            }
            .padding(horizontal = 24.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(loading, transitionSpec = { fadeIn(tween(150)) togetherWith fadeOut(tween(150)) }, label = "btn") { isLoading ->
            if (isLoading) {
                CircularProgressIndicator(Modifier.size(22.dp), color = ink, strokeWidth = 2.5.dp)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                    // 버튼 글자가 동작을 말하므로 '앞으로' 화살표는 붙이지 않는다.
                    if (icon != null && icon != Icons.AutoMirrored.Rounded.ArrowForward) {
                        Icon(icon, null, tint = ink, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(
                        text,
                        style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                        color = ink,
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
    val pressed by source.collectIsPressedAsState()
    val fill by animateColorAsState(if (pressed) c.surface3 else c.surface2, tween(120), label = "secondary")
    Row(
        modifier
            .heightIn(min = height)
            .clip(EmberShape.control)
            .background(fill)
            .border(1.dp, c.outline, EmberShape.control)
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
            .clip(EmberShape.chip)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .heightIn(min = 48.dp)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null && icon != Icons.AutoMirrored.Rounded.ArrowForward) {
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
            .clip(if (filled) EmberShape.control else CircleShape)
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
                .clip(EmberShape.chip)
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
            .clip(EmberShape.chip)
            .background(bg)
            .border(1.dp, border, EmberShape.chip)
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
            .clip(EmberShape.tag)
            .background(if (strong) tint.copy(alpha = 0.16f) else c.surface2)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        style = MaterialTheme.typography.labelSmall,
        color = if (strong) (if (c.isDark) tint else androidx.compose.ui.graphics.lerp(tint, Color.Black, 0.3f)) else c.textMuted,
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
    val shape = EmberShape.panel
    val source = remember { MutableInteractionSource() }
    Box(
        modifier
            .clip(shape)
            .background(c.surface)
            .then(
                when {
                    highlight -> Modifier.border(BorderStroke(1.5.dp, c.ember), shape)
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
fun EmberProgress(progress: Float, modifier: Modifier = Modifier, height: Dp = 4.dp) {
    val c = Ember.colors
    val p by animateFloatAsState(progress.coerceIn(0f, 1f), tween(600, easing = FastOutSlowInEasing), label = "progress")
    Box(
        modifier
            .fillMaxWidth()
            .height(height)
            .clip(EmberShape.bar)
            .background(c.surface3),
    ) {
        Box(
            Modifier
                .fillMaxWidth(p.coerceAtLeast(0.02f))
                .height(height)
                .background(c.ember),
        )
    }
}

/**
 * 생각 중 표시. 문서의 줄이 한 줄씩 채워지는 모양으로, Ember 가 '설계서를 쓰는 앱'이라는 것을 보여 준다.
 * 문구는 몇 초마다 바뀐다.
 */
@Composable
fun ThinkingIndicator(lines: List<String>, modifier: Modifier = Modifier, title: String? = null) {
    val c = Ember.colors
    val t = rememberInfiniteTransition(label = "think")
    // 0~4: 세 줄을 차례로 채우고 잠깐 멈춘 뒤 다시 시작한다.
    val phase by t.animateFloat(0f, 4f, infiniteRepeatable(tween(2400, easing = LinearEasing)), label = "phase")
    var index by remember { mutableIntStateOf(0) }
    LaunchedEffect(lines) {
        while (lines.size > 1) {
            delay(2600)
            index = (index + 1) % lines.size
        }
    }
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.width(132.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
            listOf(1f, 0.82f, 0.56f).forEachIndexed { i, w ->
                val fill = (phase - i).coerceIn(0f, 1f)
                Box(Modifier.fillMaxWidth(w).height(6.dp).clip(EmberShape.bar).background(c.surface3)) {
                    Box(Modifier.fillMaxWidth(fill).fillMaxHeight().background(if (i == 0) c.ember else c.ember.copy(alpha = 0.7f)))
                }
            }
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
    showRetry: Boolean = true,
    compact: Boolean = false,
) {
    val c = Ember.colors
    val s = LocalStrings.current
    val keyProblem = error is AiError.InvalidKey || error is AiError.NoKey || error is AiError.OutOfCredits
    val icon = when (error) {
        is AiError.Offline -> Icons.Rounded.CloudOff
        is AiError.InvalidKey, is AiError.NoKey, is AiError.OutOfCredits -> Icons.Rounded.Key
        else -> Icons.Rounded.ErrorOutline
    }
    EmberCard(modifier.fillMaxWidth().border(1.dp, c.danger.copy(alpha = 0.45f), EmberShape.panel), highlight = false, border = false) {
        Column {
            Row(verticalAlignment = Alignment.Top) {
                Icon(icon, null, tint = c.danger, modifier = Modifier.padding(top = 1.dp).size(20.dp))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(s.errorTitle(error), style = MaterialTheme.typography.titleSmall, color = c.text)
                    Spacer(Modifier.height(2.dp))
                    Text(s.errorBody(error), style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                    if (error !is AiError.InvalidKey && error !is AiError.NoKey && error !is AiError.Refused && error !is AiError.OutOfCredits) {
                        Spacer(Modifier.height(4.dp))
                        Text(s.errorSafeNote, style = MaterialTheme.typography.labelSmall, color = c.textFaint)
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Column {
                if (keyProblem) {
                    PrimaryButton(if (error is AiError.OutOfCredits) s.topUp else s.fixKey, onFixKey, Modifier.fillMaxWidth(), icon = Icons.Rounded.Key, height = 48.dp)
                } else if (showRetry) {
                    PrimaryButton(s.retry, onRetry, Modifier.fillMaxWidth(), icon = Icons.Rounded.Refresh, height = 48.dp)
                }
                if (onDismiss != null) {
                    if (compact) {
                        Spacer(Modifier.height(4.dp))
                        SecondaryButton(dismissLabel ?: s.close, onDismiss, Modifier.fillMaxWidth(), height = 44.dp)
                    } else GhostButton(dismissLabel ?: s.close, onDismiss, color = c.textMuted, modifier = Modifier.offset(x = (-14).dp))
                }
            }
        }
    }
}

@Composable
fun EmptyState(icon: ImageVector, title: String, body: String, modifier: Modifier = Modifier, action: (@Composable () -> Unit)? = null) {
    val c = Ember.colors
    Column(modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, tint = c.textFaint, modifier = Modifier.size(36.dp))
        Spacer(Modifier.height(16.dp))
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
    // 다중 선택은 체크 상자, 단일 선택은 라디오 원(안드로이드 관례).
    val shape = if (multi) EmberShape.tag else CircleShape
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
fun Modifier.topFade(color: Color, height: Dp = 16.dp): Modifier = this.drawBehind {
    val h = height.toPx()
    drawRect(
        Brush.verticalGradient(listOf(color.copy(alpha = 0f), color), startY = -h, endY = 0f),
        topLeft = Offset(0f, -h),
        size = androidx.compose.ui.geometry.Size(size.width, h),
    )
    drawRect(color)
}


/** 밑줄로 선택을 표시하는 탭. 두세 개의 보기를 나눌 때 쓴다. */
@Composable
fun UnderlineTab(text: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Ember.colors
    Column(
        modifier.clickable(role = Role.Tab, onClick = onClick).semantics { stateDescription = if (selected) "✓" else "" },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text, style = MaterialTheme.typography.titleSmall, color = if (selected) c.text else c.textMuted, modifier = Modifier.padding(vertical = 14.dp), maxLines = 1)
        Box(Modifier.fillMaxWidth(0.6f).height(2.dp).background(if (selected) c.ember else Color.Transparent))
    }
}
