package app.ember.ideas.ui.screens.project

import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.IntrinsicSize
import app.ember.ideas.ui.theme.EmberShape
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import app.ember.ideas.ui.text.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.material.icons.automirrored.rounded.List
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.animation.core.animateFloat
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.foundation.layout.offset
import kotlinx.coroutines.launch
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.ai.AiError
import app.ember.ideas.data.Answer
import app.ember.ideas.data.QuestionOption
import app.ember.ideas.data.Turn
import app.ember.ideas.ui.components.EmberProgress
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.ErrorPanel
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.IconCircleButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SelectMark
import app.ember.ideas.ui.components.Tag
import app.ember.ideas.ui.components.ThinkingIndicator
import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember

/**
 * 객관식 카드 질문 흐름. 아이디어 인터뷰와 설계 인터뷰가 함께 쓴다.
 * 선택 상태는 질문마다 새로 만들고, 되돌아간 경우에는 이전 답을 미리 채운다.
 */
@Composable
fun QuestionFlow(
    turns: List<Turn>,
    busy: Boolean,
    error: AiError?,
    thinkingTitle: String,
    thinkingLines: List<String>,
    finishLabel: String,
    canFinish: Boolean,
    draft: Answer?,
    onSubmit: (Answer) -> Unit,
    onUndo: () -> Unit,
    onFinish: () -> Unit,
    onRetry: () -> Unit,
    onFixKey: () -> Unit,
    onShowHistory: () -> Unit,
    expectedTotal: Int = 8,
    onStop: (() -> Unit)? = null,
    onLeave: (() -> Unit)? = null,
    partial: app.ember.ideas.ai.PartialQuestion? = null,
    /** 지금 질문에서 '이전'으로 돌아갈 수 있는지(요청으로 시작된 질문은 못 돌아간다). */
    canUndoCurrent: Boolean = true,
    /** 기본 "질문 n / 약 m" 대신 쓸 진행 문구. 인자는 답을 보내는 중인지. */
    counter: ((Boolean) -> String)? = null,
    /** 열기 막대(대장간 진행 단계). 없으면 얇은 진행 막대를 쓴다. */
    heat: app.ember.ideas.ui.components.Heat? = null,
    heatLabels: List<String>? = null,
    /** 지금 칸의 이름(예: "가열 62%"). */
    heatCurrentLabel: String? = null,
    /** 앞에서 두드려 쌓인 답(거푸집에서 온 답 포함). */
    plates: List<PlateItem> = emptyList(),
    strikeLabel: String = "",
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val current = turns.lastOrNull()?.takeIf { it.answer == null }
    val answered = turns.count { it.answer != null }
    val index = turns.size
    var lastSubmitted by remember { mutableStateOf<String?>(null) }
    // 요청이 실패했을 때 고른 답을 그대로 되살리기 위해 마지막 답을 기억한다.
    var pendingAnswer by remember { mutableStateOf<Answer?>(null) }
    // 새 질문이 나타나거나 작업이 끝나면 '내 답변' 표시와 실패 시 되살릴 답을 비운다.
    androidx.compose.runtime.LaunchedEffect(current?.question?.title, turns.size, busy) {
        if (!busy) lastSubmitted = null
        if (current != null && error == null) pendingAnswer = null
    }
    val submit: (Answer) -> Unit = { a ->
        pendingAnswer = a
        lastSubmitted = current?.let { t ->
            if (a.skipped) s.skipped else t.copy(answer = a).answerSummary().ifBlank { null }
        }
        onSubmit(a)
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        // 진행 표시줄
        Column(Modifier.padding(horizontal = 20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 48.dp)) {
                val stage = current?.stage ?: turns.lastOrNull()?.stage ?: ""
                if (stage.isNotBlank()) {
                    Tag(stage, color = c.ember, strong = true)
                    Spacer(Modifier.width(8.dp))
                }
                // 답을 보내는 즉시 카운터와 진행 막대를 한 칸 올린다.
                val sending = busy && lastSubmitted != null
                val shownIndex = if (sending) index + 1 else index
                Text(counter?.invoke(sending) ?: s.questionOf(shownIndex.coerceAtLeast(1), expectedTotal), style = MaterialTheme.typography.labelMedium, color = c.textMuted, modifier = Modifier.weight(1f))
                if (canFinish && !busy && current != null && error == null) {
                    Row(
                        Modifier.clip(EmberShape.chip).border(1.dp, c.ember.copy(alpha = 0.5f), EmberShape.chip).clickable(onClick = onFinish).heightIn(min = 36.dp).padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(finishLabel, style = MaterialTheme.typography.labelMedium, color = c.ember)
                    }
                }
            }
            val base = current?.progress ?: turns.lastOrNull()?.progress ?: 3
            val shown = (if (busy && lastSubmitted != null) (base + 100 / expectedTotal).coerceAtMost(96) else base) / 100f
            if (heat != null) {
                // 답을 보내는 동안 지금 칸이 조금 더 차오르고 쇳물 무늬가 흐른다.
                val h = if (heat.full in 1..2 && !heat.tempered) heat.copy(partial = shown) else heat
                app.ember.ideas.ui.components.HeatGauge(h, flowing = busy, labels = heatLabels, currentLabel = heatCurrentLabel)
            } else {
                EmberProgress(shown)
            }
        }

        Box(Modifier.weight(1f)) {
            when {
                error != null && current == null -> Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.Center) {
                    ErrorPanel(error, onRetry, onFixKey, onDismiss = onLeave, dismissLabel = s.doLater)
                }
                busy || current == null -> Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
                    Spacer(Modifier.height(16.dp))
                    if (busy && lastSubmitted != null) {
                        // 방금 두드린 답이 식어서 단조판 위에 얹힌다.
                        plates.takeLast(2).forEach { pl ->
                            app.ember.ideas.ui.components.Plate(pl.label, pl.text, pl.fromMold)
                            Spacer(Modifier.height(4.dp))
                        }
                        CoolingPlate(s.plateAnswer, lastSubmitted!!)
                        Spacer(Modifier.height(20.dp))
                    }
                    if (busy && partial != null) {
                        // 질문이 도착하는 대로 먼저 보여 준다. 다 오기 전에는 고를 수 없다.
                        PartialQuestionPreview(partial)
                    } else {
                        Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            ThinkingIndicator(thinkingLines, title = thinkingTitle)
                        }
                        Spacer(Modifier.height(20.dp))
                        // 다음 질문 카드 자리를 미리 보여 준다(스켈레톤).
                        SkeletonCards()
                    }
                    Spacer(Modifier.weight(1f))
                    Text(s.waitingNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    if (onStop != null && busy) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                            GhostButton(s.stop, onStop, icon = Icons.Rounded.Stop, color = c.textMuted)
                        }
                    }
                    Spacer(Modifier.navigationBarsPadding().height(12.dp))
                }
                else -> AnimatedContent(
                    targetState = current,
                    transitionSpec = {
                        (slideInHorizontally(tween(260)) { it / 6 } + fadeIn(tween(260))) togetherWith
                            (slideOutHorizontally(tween(200)) { -it / 6 } + fadeOut(tween(200)))
                    },
                    contentKey = { it.question.title + turns.size },
                    label = "question",
                ) { turn ->
                    QuestionCard(
                        turn = turn,
                        draft = if (error != null && pendingAnswer != null && !pendingAnswer!!.skipped) pendingAnswer else draft,
                        canUndo = turns.size >= 2 && canUndoCurrent,
                        onSubmit = submit,
                        onUndo = { pendingAnswer = null; lastSubmitted = null; onUndo() },
                        historyLabel = if (answered > 0) s.answersSoFar(answered) else null,
                        plates = plates,
                        strikeLabel = strikeLabel.ifBlank { s.next },
                        onShowHistory = onShowHistory,
                        errorBanner = if (error != null) ({ ErrorPanel(error, onRetry, onFixKey, onDismiss = onLeave, dismissLabel = s.doLater, showRetry = false, compact = true) }) else null,
                    )
                }
            }
        }
    }
}

@Composable
private fun QuestionCard(
    turn: Turn,
    draft: Answer?,
    canUndo: Boolean,
    onSubmit: (Answer) -> Unit,
    onUndo: () -> Unit,
    historyLabel: String?,
    onShowHistory: () -> Unit,
    errorBanner: (@Composable () -> Unit)?,
    plates: List<PlateItem> = emptyList(),
    strikeLabel: String,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val q = turn.question
    val key = q.title
    val recommendedId = q.options.firstOrNull { o -> o.description.startsWith("추천 · ") || o.description.startsWith("Recommended · ") }?.id
    var selected by rememberSaveable(key) { mutableStateOf(draft?.selectedIds ?: if (!q.multiSelect && recommendedId != null) listOf(recommendedId) else emptyList()) }
    var custom by rememberSaveable(key) { mutableStateOf(draft?.customText ?: "") }
    var customOpen by rememberSaveable(key) { mutableStateOf((draft?.customText ?: "").isNotEmpty()) }
    val hasAnswer = selected.isNotEmpty() || custom.isNotBlank()
    val scroll = rememberScrollState()

    LaunchedEffect(customOpen) { if (customOpen) scroll.animateScrollTo(scroll.maxValue) }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(scroll)
                .padding(horizontal = 20.dp),
        ) {
            Spacer(Modifier.height(16.dp))
            if (errorBanner != null) {
                errorBanner()
                Spacer(Modifier.height(16.dp))
            }
            if (plates.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    shownPlates(plates).forEach { pl -> app.ember.ideas.ui.components.Plate(pl.label, pl.text, pl.fromMold) }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (historyLabel != null) GhostButton(historyLabel, onShowHistory, color = c.textMuted, modifier = Modifier.offset(x = (-14).dp))
                }
                if (turn.insight.isNotBlank()) {
                    Text(turn.insight, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                    Spacer(Modifier.height(16.dp))
                } else Spacer(Modifier.height(8.dp))
            } else if (turn.insight.isNotBlank() || historyLabel != null) {
                // 지금까지 파악한 내용. 왼쪽 선 하나로 질문과 구분한다.
                Row(
                    Modifier.fillMaxWidth().height(IntrinsicSize.Min),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.width(2.dp).fillMaxHeight().padding(vertical = 4.dp).background(c.gold.copy(alpha = 0.8f)))
                    Spacer(Modifier.width(12.dp))
                    Text(
                        turn.insight.ifBlank { " " },
                        style = MaterialTheme.typography.bodySmall,
                        color = c.textMuted,
                        modifier = Modifier.weight(1f).padding(vertical = 8.dp),
                    )
                    if (historyLabel != null) GhostButton(historyLabel, onShowHistory, icon = Icons.AutoMirrored.Rounded.List, color = c.textMuted)
                }
                Spacer(Modifier.height(20.dp))
            }
            Text(q.title, style = MaterialTheme.typography.headlineSmall, color = c.text)
            if (q.subtitle.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(q.subtitle, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
            }
            Spacer(Modifier.height(6.dp))
            Text(if (q.multiSelect) s.multiHint else s.singleHint, style = MaterialTheme.typography.labelMedium, color = c.textFaint)
            Spacer(Modifier.height(16.dp))
            q.options.forEachIndexed { idx, opt ->
                val isSel = opt.id in selected
                OptionRow(opt, ('A' + idx).toString(), isSel, q.multiSelect) {
                    selected = if (q.multiSelect) {
                        if (isSel) selected - opt.id else selected + opt.id
                    } else {
                        if (isSel) emptyList() else listOf(opt.id)
                    }
                    if (!q.multiSelect && !isSel) customOpen = false
                }
                Spacer(Modifier.height(10.dp))
            }
            if (q.allowCustom) {
                CustomRow(open = customOpen, filled = custom.isNotBlank(), multi = q.multiSelect, onClick = {
                    customOpen = !customOpen
                    if (customOpen && !q.multiSelect) selected = emptyList()
                })
                AnimatedVisibility(customOpen, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                    Column {
                        Spacer(Modifier.height(10.dp))
                        EmberTextField(
                            value = custom,
                            onValueChange = { custom = it },
                            placeholder = q.customHint.ifBlank { s.customPlaceholder },
                            minHeight = 80.dp,
                            maxLength = 500,
                        )
                    }
                }
            }
            Spacer(Modifier.height(32.dp))
        }

        // 하단 동작: 되돌리기 · 건너뛰기 · 다음
        Row(
            Modifier
                .fillMaxWidth()
                .topFade(c.bg)
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            GhostButton(s.previousShort, onUndo, icon = Icons.AutoMirrored.Rounded.ArrowBack, color = c.textMuted, enabled = canUndo, modifier = Modifier.offset(x = (-12).dp).alpha(if (canUndo) 1f else 0f))
            GhostButton(s.skip, { onSubmit(Answer(skipped = true)) }, color = c.textMuted, modifier = Modifier.offset(x = (-12).dp))
            Spacer(Modifier.width(4.dp))
            app.ember.ideas.ui.components.StrikeButton(
                text = if (errorBanner != null) s.resend else strikeLabel,
                onClick = { onSubmit(Answer(selectedIds = selected, customText = if (customOpen) custom.trim() else "")) },
                enabled = hasAnswer,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun OptionRow(opt: QuestionOption, letter: String, selected: Boolean, multi: Boolean, onClick: () -> Unit) {
    val c = Ember.colors
    val shape = EmberShape.control
    val bg by animateColorAsState(if (selected) c.emberSoft else c.surface, tween(160), label = "optbg")
    // 고를 때 카드가 3px 눌렸다 돌아온다(4프레임). 움직임 줄이기가 켜져 있으면 색만 바뀐다.
    val still = app.ember.ideas.ui.components.reduceMotion()
    val press = remember { androidx.compose.animation.core.Animatable(0f) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    val border by animateColorAsState(if (selected) c.ember else c.outline, tween(160), label = "optborder")
    Row(
        Modifier
            .offset { androidx.compose.ui.unit.IntOffset(0, (press.value * 3).toInt().dp.roundToPx()) }
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clip(shape)
            .background(bg)
            .border(if (selected) 1.5.dp else 1.dp, border, shape)
            .clickable(role = if (multi) Role.Checkbox else Role.RadioButton) {
                haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                if (!still) scope.launch { for (v in listOf(1f, 1f, 0.34f, 0f)) { press.snapTo(v); kotlinx.coroutines.delay(60) } }
                onClick()
            }
            .height(IntrinsicSize.Min)
            .padding(end = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 선택지 글자는 색인 카드의 여백 칸처럼 왼쪽에 크게 두고, 세로 선으로 본문과 나눈다.
        Text(
            letter,
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            color = if (selected) c.ember else c.textFaint,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(48.dp),
        )
        Box(Modifier.width(1.dp).fillMaxHeight().background(if (selected) c.ember.copy(alpha = 0.5f) else c.outline))
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f).padding(vertical = 12.dp)) {
            val rec = listOf("추천 · ", "Recommended · ").firstOrNull { opt.description.startsWith(it) }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(opt.label, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f, fill = false))
                if (rec != null) {
                    Spacer(Modifier.width(8.dp))
                    Tag(LocalStrings.current.recommended, color = c.success, strong = true)
                }
            }
            val desc = if (rec != null) opt.description.removePrefix(rec) else opt.description
            if (desc.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(desc, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
            }
        }
        Spacer(Modifier.width(10.dp))
        SelectMark(selected, multi)
    }
}

@Composable
private fun CustomRow(open: Boolean, filled: Boolean, multi: Boolean, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val shape = EmberShape.control
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clip(shape)
            .border(1.dp, if (open || filled) c.ember else c.outline, shape)
            .clickable(onClick = onClick)
            .height(IntrinsicSize.Min)
            .padding(end = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.width(48.dp), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Edit, null, tint = c.textFaint, modifier = Modifier.size(18.dp))
        }
        Box(Modifier.width(1.dp).fillMaxHeight().background(c.outline))
        Spacer(Modifier.width(14.dp))
        Text(s.customAnswer, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Icon(if (open) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = if (filled) c.ember else c.textMuted)
    }
}


@Composable
private fun SkeletonCards() {
    val c = Ember.colors
    val t = androidx.compose.animation.core.rememberInfiniteTransition(label = "skel")
    val a by t.animateFloat(0.35f, 0.7f, androidx.compose.animation.core.infiniteRepeatable(tween(900), androidx.compose.animation.core.RepeatMode.Reverse), label = "skelA")
    Column(Modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth(0.7f).height(22.dp).clip(RoundedCornerShape(8.dp)).background(c.surface3.copy(alpha = a)))
        Spacer(Modifier.height(16.dp))
        repeat(3) {
            Box(Modifier.fillMaxWidth().height(64.dp).clip(EmberShape.control).background(c.surface2.copy(alpha = a + 0.2f)))
            Spacer(Modifier.height(10.dp))
        }
    }
}


@Composable
private fun PartialQuestionPreview(pq: app.ember.ideas.ai.PartialQuestion) {
    val s = LocalStrings.current
    val c = Ember.colors
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState())) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(Modifier.size(14.dp), color = c.ember, strokeWidth = 2.dp)
            Spacer(Modifier.width(8.dp))
            Text(s.writingQuestion, style = MaterialTheme.typography.labelMedium, color = c.textMuted)
        }
        Spacer(Modifier.height(16.dp))
        Text(pq.title, style = MaterialTheme.typography.headlineSmall, color = c.text)
        if (pq.subtitle.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(pq.subtitle, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
        }
        Spacer(Modifier.height(16.dp))
        pq.options.forEachIndexed { idx, (label, desc) ->
            Row(
                Modifier.fillMaxWidth().heightIn(min = 64.dp).clip(EmberShape.control).background(c.surface)
                    .border(1.dp, c.outline, EmberShape.control).height(IntrinsicSize.Min).padding(end = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(('A' + idx).toString(), style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = c.textFaint, textAlign = TextAlign.Center, modifier = Modifier.width(48.dp))
                Box(Modifier.width(1.dp).fillMaxHeight().background(c.outline))
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f).padding(vertical = 12.dp)) {
                    Text(label, style = MaterialTheme.typography.titleSmall, color = c.text)
                    val d = listOf("추천 · ", "Recommended · ").fold(desc) { acc, p -> acc.removePrefix(p) }
                    if (d.isNotBlank()) Text(d, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                }
            }
            Spacer(Modifier.height(10.dp))
        }
        if (pq.options.size < 3) {
            repeat(3 - pq.options.size) {
                Box(Modifier.fillMaxWidth().height(64.dp).clip(EmberShape.control).background(c.surface2.copy(alpha = 0.6f)))
                Spacer(Modifier.height(10.dp))
            }
        }
    }
}


/** 답한 질문 하나를 단조판으로 보여 줄 때의 내용. */
data class PlateItem(val label: String, val text: String, val fromMold: Boolean)

/** 방금 보낸 답. 불씨색으로 달아올랐다가 0.6초 동안 식으며 아래에서 올라와 판으로 얹힌다. */
@Composable
private fun CoolingPlate(label: String, text: String) {
    val c = Ember.colors
    val still = app.ember.ideas.ui.components.reduceMotion()
    val t = remember { androidx.compose.animation.core.Animatable(if (still) 1f else 0f) }
    LaunchedEffect(text) { if (!still) t.animateTo(1f, tween(600)) }
    val rise = ((1f - t.value) * 12).toInt()
    app.ember.ideas.ui.components.Plate(
        label, text, fromMold = false,
        modifier = Modifier.offset { androidx.compose.ui.unit.IntOffset(0, rise.dp.roundToPx()) },
        fill = androidx.compose.ui.graphics.lerp(c.ember.copy(alpha = 0.22f).compositeOver(c.surface), c.surface, t.value),
    )
}

/** 판은 세 장만 보여 준다: 거푸집 답을 앞에 두되(최대 두 장) 최근 답이 적어도 한 장은 보이게 한다. */
internal fun shownPlates(plates: List<PlateItem>): List<PlateItem> {
    val mold = plates.filter { it.fromMold }
    val answers = plates.filter { !it.fromMold }
    val answerSlots = when {
        mold.isEmpty() -> 3
        answers.isEmpty() -> 0
        else -> maxOf(1, 3 - mold.size.coerceAtMost(2))
    }.coerceAtMost(answers.size)
    return mold.take(3 - answerSlots) + answers.takeLast(answerSlots)
}
