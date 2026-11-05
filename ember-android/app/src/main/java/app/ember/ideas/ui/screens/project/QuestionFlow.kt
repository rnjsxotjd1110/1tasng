package app.ember.ideas.ui.screens.project

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val current = turns.lastOrNull()?.takeIf { it.answer == null }
    val answered = turns.count { it.answer != null }
    val index = turns.size

    Column(Modifier.fillMaxSize().imePadding()) {
        // 진행 표시줄
        Column(Modifier.padding(horizontal = 24.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                val stage = current?.stage ?: turns.lastOrNull()?.stage ?: ""
                if (stage.isNotBlank()) Tag(stage, color = c.ember, strong = true)
                Spacer(Modifier.width(8.dp))
                Text(s.questionN(index.coerceAtLeast(1)), style = MaterialTheme.typography.labelMedium, color = c.textMuted, modifier = Modifier.weight(1f))
                if (answered > 0) {
                    GhostButton(s.answersSoFar(answered), onShowHistory, icon = Icons.Rounded.History, color = c.textMuted)
                }
            }
            Spacer(Modifier.height(8.dp))
            EmberProgress((current?.progress ?: turns.lastOrNull()?.progress ?: 3) / 100f)
        }

        Box(Modifier.weight(1f)) {
            when {
                error != null -> Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
                    ErrorPanel(error, onRetry, onFixKey)
                }
                busy || current == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    ThinkingIndicator(thinkingLines, title = thinkingTitle, modifier = Modifier.padding(24.dp))
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
                        draft = draft,
                        canUndo = turns.size >= 2,
                        finishLabel = finishLabel,
                        canFinish = canFinish,
                        onSubmit = onSubmit,
                        onUndo = onUndo,
                        onFinish = onFinish,
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
    finishLabel: String,
    canFinish: Boolean,
    onSubmit: (Answer) -> Unit,
    onUndo: () -> Unit,
    onFinish: () -> Unit,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val q = turn.question
    val key = q.title
    var selected by rememberSaveable(key) { mutableStateOf(draft?.selectedIds ?: emptyList()) }
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
                .padding(horizontal = 24.dp),
        ) {
            Spacer(Modifier.height(20.dp))
            if (turn.insight.isNotBlank()) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(c.surface2).padding(12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Icon(Icons.Rounded.Lightbulb, null, tint = c.gold, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(10.dp))
                    Text(turn.insight, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
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
            q.options.forEach { opt ->
                val isSel = opt.id in selected
                OptionRow(opt, isSel, q.multiSelect) {
                    selected = if (q.multiSelect) {
                        if (isSel) selected - opt.id else selected + opt.id
                    } else {
                        if (isSel) emptyList() else listOf(opt.id)
                    }
                }
                Spacer(Modifier.height(10.dp))
            }
            if (q.allowCustom) {
                CustomRow(open = customOpen, filled = custom.isNotBlank(), onClick = { customOpen = !customOpen })
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
            Spacer(Modifier.height(24.dp))
        }

        // 하단 동작
        Column(
            Modifier
                .fillMaxWidth()
                .background(c.bg)
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (canUndo) {
                    IconCircleButton(Icons.AutoMirrored.Rounded.Undo, s.previousQuestion, onUndo, tint = c.textMuted)
                    Spacer(Modifier.width(4.dp))
                }
                GhostButton(s.skip, { onSubmit(Answer(skipped = true)) }, color = c.textMuted)
                Spacer(Modifier.weight(1f))
                if (canFinish) GhostButton(finishLabel, onFinish)
            }
            Spacer(Modifier.height(6.dp))
            PrimaryButton(
                text = s.next,
                onClick = { onSubmit(Answer(selectedIds = selected, customText = if (customOpen) custom.trim() else "")) },
                enabled = hasAnswer,
                modifier = Modifier.fillMaxWidth(),
                icon = Icons.AutoMirrored.Rounded.ArrowForward,
            )
        }
    }
}

@Composable
private fun OptionRow(opt: QuestionOption, selected: Boolean, multi: Boolean, onClick: () -> Unit) {
    val c = Ember.colors
    val shape = RoundedCornerShape(18.dp)
    val bg by animateColorAsState(if (selected) c.emberSoft else c.surface, tween(160), label = "optbg")
    val border by animateColorAsState(if (selected) c.ember else c.outline, tween(160), label = "optborder")
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clip(shape)
            .background(bg)
            .border(if (selected) 1.5.dp else 1.dp, border, shape)
            .clickable(role = if (multi) Role.Checkbox else Role.RadioButton, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(c.surface2), contentAlignment = Alignment.Center) {
            Text(opt.emoji.ifBlank { "•" }, style = MaterialTheme.typography.titleLarge)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(opt.label, style = MaterialTheme.typography.titleSmall, color = c.text)
            if (opt.description.isNotBlank()) {
                Spacer(Modifier.height(2.dp))
                val recommended = opt.description.startsWith("추천 · ") || opt.description.startsWith("Recommended · ")
                if (recommended) {
                    Tag(opt.description.substringBefore(" · "), color = c.success, strong = true)
                    Spacer(Modifier.height(4.dp))
                }
                Text(
                    if (recommended) opt.description.substringAfter(" · ") else opt.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = c.textMuted,
                )
            }
        }
        Spacer(Modifier.width(10.dp))
        SelectMark(selected, multi)
    }
}

@Composable
private fun CustomRow(open: Boolean, filled: Boolean, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clip(shape)
            .border(1.dp, if (open || filled) c.ember else c.outline, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(c.surface2), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Edit, null, tint = c.textMuted, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(14.dp))
        Text(s.customAnswer, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        SelectMark(open || filled, multi = true)
    }
}
