@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.ember.ideas.ui.screens.project

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.CallMerge
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import app.ember.ideas.ui.text.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
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
import app.ember.ideas.ai.Protocol
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.DocVersion
import app.ember.ideas.data.Idea
import app.ember.ideas.data.Turn
import app.ember.ideas.handoff.HandoffGoal
import app.ember.ideas.ui.components.EmberChip
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.components.SelectMark
import app.ember.ideas.ui.components.Tag
import app.ember.ideas.ui.components.ToggleRow
import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember

// ------------------------------------------------------------------ 공통 시트

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EmberSheet(onDismiss: () -> Unit, state: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), content: @Composable ColumnScope.() -> Unit) {
    val c = Ember.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        containerColor = c.surface,
        contentColor = c.text,
        scrimColor = androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.55f),
        dragHandle = {
            Box(Modifier.padding(top = 10.dp, bottom = 6.dp).size(width = 40.dp, height = 4.dp).clip(CircleShape).background(c.surface3))
        },
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding(), content = content)
    }
}

@Composable
private fun SheetTitle(title: String, subtitle: String? = null) {
    val c = Ember.colors
    Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
        Text(title, style = MaterialTheme.typography.headlineSmall, color = c.text)
        if (!subtitle.isNullOrBlank()) {
            Spacer(Modifier.height(6.dp))
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
        }
    }
}

// ------------------------------------------------------------------ 아이디어 상세

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun IdeaDetailSheet(
    idea: Idea,
    saved: Boolean,
    hasOtherIdeas: Boolean,
    busy: Boolean,
    onDismiss: () -> Unit,
    onToggleSave: () -> Unit,
    onDesign: () -> Unit,
    onVary: () -> Unit,
    onCombine: () -> Unit,
    onSendToClaude: () -> Unit,
    onCopy: () -> Unit,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberSheet(onDismiss) {
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text(idea.title, style = MaterialTheme.typography.headlineMedium, color = c.text)
                    Spacer(Modifier.height(8.dp))
                    Text(idea.logline, style = MaterialTheme.typography.bodyLarge, color = c.text.copy(alpha = 0.9f))
                }
                HeartButton(saved, onToggleSave)
            }
            Spacer(Modifier.height(14.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                (listOf(idea.genre.ifBlank { idea.category }) + idea.platforms).filter { it.isNotBlank() }.distinct().forEach { Tag(it) }
            }
            Spacer(Modifier.height(10.dp))
            Row(Modifier.fillMaxWidth().offset(x = (-12).dp)) {
                GhostButton(s.vary, onVary, icon = Icons.Rounded.Shuffle, enabled = !busy)
                if (hasOtherIdeas) GhostButton(s.combine, onCombine, icon = Icons.Rounded.CallMerge, enabled = !busy)
                GhostButton(s.copy, onCopy, icon = Icons.Rounded.ContentCopy, color = c.textMuted)
            }
            Spacer(Modifier.height(8.dp))
            StatRow(idea)
            DetailBlock(s.fieldCoreHook, idea.coreHook)
            if (idea.keyFeatures.isNotEmpty()) {
                DetailTitle(s.fieldFeatures)
                idea.keyFeatures.forEach { f ->
                    Row(Modifier.padding(vertical = 4.dp)) {
                        Box(Modifier.padding(top = 8.dp, end = 10.dp).size(6.dp).clip(CircleShape).background(c.ember))
                        Text(f, style = MaterialTheme.typography.bodyMedium, color = c.text)
                    }
                }
            }
            DetailBlock(s.fieldUnique, idea.uniquePoint)
            DetailBlock(s.fieldAudience, idea.targetAudience)
            DetailBlock(s.fieldMonetization, idea.monetization)
            DetailBlock(s.fieldFit, idea.fitReason, accent = true)
            Spacer(Modifier.height(8.dp))
            GhostButton(s.sendIdeaToClaude, onSendToClaude, icon = Icons.AutoMirrored.Rounded.Send, modifier = Modifier.offset(x = (-12).dp))
            Spacer(Modifier.height(16.dp))
        }
        Column(Modifier.topFade(c.surface).padding(horizontal = 20.dp, vertical = 10.dp)) {
            PrimaryButton(s.designThis, onDesign, Modifier.fillMaxWidth(), icon = Icons.Rounded.Description, enabled = !busy)
        }
    }
}

@Composable
private fun StatRow(idea: Idea) {
    val s = LocalStrings.current
    val c = Ember.colors
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.surface2).padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        Stat(s.fieldScope, idea.scope.ifBlank { "—" })
        Stat(s.fieldDevTime, idea.devTime.ifBlank { "—" })
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 6.dp)) {
            Text(s.fieldDifficulty, style = MaterialTheme.typography.labelSmall, color = c.textFaint)
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                repeat(5) { i ->
                    Box(Modifier.padding(horizontal = 2.dp).size(8.dp).clip(CircleShape).background(if (i < idea.difficulty) difficultyColor(idea.difficulty) else c.control))
                }
                Spacer(Modifier.width(6.dp))
                Text("${idea.difficulty}/5", style = MaterialTheme.typography.labelMedium, color = c.text)
            }
        }
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun Stat(label: String, value: String) {
    val c = Ember.colors
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 6.dp).width(96.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = c.textFaint)
        Spacer(Modifier.height(4.dp))
        Text(value, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun DetailTitle(t: String) {
    Text(t, style = MaterialTheme.typography.labelLarge, color = Ember.colors.ember, modifier = Modifier.padding(top = 16.dp, bottom = 6.dp))
}

@Composable
private fun DetailBlock(title: String, body: String, accent: Boolean = false) {
    if (body.isBlank()) return
    val c = Ember.colors
    DetailTitle(title)
    if (accent) {
        Text(body, style = MaterialTheme.typography.bodyMedium, color = c.text, modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(c.emberSoft).padding(12.dp))
    } else {
        Text(body, style = MaterialTheme.typography.bodyMedium, color = c.text)
    }
}

// ------------------------------------------------------------------ 설계 시작

@Composable
fun DesignSetupSheet(idea: Idea, model: app.ember.ideas.ai.ClaudeModel, onDismiss: () -> Unit, onStart: (DocDepth, Boolean) -> Unit) {
    val s = LocalStrings.current
    var depth by rememberSaveable { mutableStateOf(DocDepth.STANDARD) }
    var ask by rememberSaveable { mutableStateOf(true) }
    EmberSheet(onDismiss) {
        SheetTitle(s.designSetupTitle, s.designSetupSub(idea.title))
        Column(Modifier.padding(horizontal = 20.dp)) {
            Spacer(Modifier.height(8.dp))
            DocDepth.entries.forEach { d ->
                val cost = s.costApprox(app.ember.ideas.ai.CostEstimate.design(model, d, ask))
                val (lo, hi) = app.ember.ideas.ai.CostEstimate.minutes(model, d)
                ChoiceRow(s.depthTitle(d), s.depthBody(d) + "\n" + s.depthMeta(d, cost, s.minutes(lo, hi)), depth == d) { depth = d }
                Spacer(Modifier.height(8.dp))
            }
            Spacer(Modifier.height(4.dp))
            ToggleRow(s.askDesignQuestions, s.askDesignQuestionsBody, ask, { ask = it })
            Spacer(Modifier.height(12.dp))
            PrimaryButton(s.startDesign, { onStart(depth, ask) }, Modifier.fillMaxWidth(), icon = Icons.AutoMirrored.Rounded.ArrowForward)
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
fun ChoiceRow(title: String, body: String, selected: Boolean, onClick: () -> Unit) {
    val c = Ember.colors
    val shape = RoundedCornerShape(18.dp)
    val border by animateColorAsState(if (selected) c.ember else c.outline, label = "choice")
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clip(shape)
            .background(if (selected) c.emberSoft else c.surface)
            .border(if (selected) 1.5.dp else 1.dp, border, shape)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = c.text)
            Spacer(Modifier.height(2.dp))
            Text(body, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
        }
        Spacer(Modifier.width(12.dp))
        SelectMark(selected, multi = false)
    }
}

// ------------------------------------------------------------------ 변형·조합

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun VariationSheet(idea: Idea, onDismiss: () -> Unit, onSubmit: (String) -> Unit) {
    val s = LocalStrings.current
    var text by rememberSaveable { mutableStateOf("") }
    EmberSheet(onDismiss) {
        SheetTitle(s.varyTitle, s.varySub(idea.title))
        Column(Modifier.padding(horizontal = 20.dp)) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                s.varyPresets.forEach { p -> EmberChip(p, text == p, { text = p }) }
            }
            Spacer(Modifier.height(12.dp))
            EmberTextField(text, { text = it }, s.varyPlaceholder, minHeight = 80.dp, maxLength = 300)
            Spacer(Modifier.height(14.dp))
            PrimaryButton(s.makeVariations, { onSubmit(text) }, Modifier.fillMaxWidth(), enabled = text.isNotBlank(), icon = Icons.Rounded.Shuffle)
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
fun CombineSheet(base: Idea, others: List<Idea>, onDismiss: () -> Unit, onSubmit: (Idea) -> Unit) {
    val s = LocalStrings.current
    var pick by remember { mutableStateOf<Idea?>(null) }
    EmberSheet(onDismiss) {
        SheetTitle(s.combineTitle, s.combineSub(base.title))
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            others.forEach { o ->
                ChoiceRow(o.title, o.logline, pick?.id == o.id) { pick = o }
                Spacer(Modifier.height(8.dp))
            }
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 10.dp)) {
            PrimaryButton(s.combine, { pick?.let(onSubmit) }, Modifier.fillMaxWidth(), enabled = pick != null, icon = Icons.Rounded.CallMerge)
        }
    }
}

// ------------------------------------------------------------------ 설계서 수정·버전

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ReviseSheet(costUsd: Double, onDismiss: () -> Unit, onSubmit: (String) -> Unit) {
    val s = LocalStrings.current
    var text by rememberSaveable { mutableStateOf("") }
    EmberSheet(onDismiss) {
        SheetTitle(s.reviseTitle, s.reviseSub)
        Column(Modifier.padding(horizontal = 20.dp)) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                s.revisePresets.forEach { p -> EmberChip(p, text == p, { text = p }) }
            }
            Spacer(Modifier.height(12.dp))
            EmberTextField(text, { text = it }, s.revisePlaceholder, minHeight = 96.dp, maxLength = 800)
            Text(s.reviseCost(s.costApprox(costUsd)), style = MaterialTheme.typography.bodySmall, color = Ember.colors.textFaint, modifier = Modifier.padding(start = 4.dp, top = 8.dp))
            Spacer(Modifier.height(14.dp))
            PrimaryButton(s.applyRevision, { onSubmit(text) }, Modifier.fillMaxWidth(), enabled = text.isNotBlank())
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
fun VersionsSheet(versions: List<DocVersion>, onDismiss: () -> Unit, onRestore: (DocVersion) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberSheet(onDismiss) {
        SheetTitle(s.versionsTitle, s.versionsSub)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp)) {
            versions.withIndex().reversed().forEach { (i, v) ->
                val isLatest = i == versions.lastIndex
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(if (isLatest) c.emberSoft else c.surface2).padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(s.versionLabel(i + 1), style = MaterialTheme.typography.titleSmall, color = c.text)
                            if (isLatest) { Spacer(Modifier.width(8.dp)); Tag(s.current, color = c.ember, strong = true) }
                            if (!v.complete) { Spacer(Modifier.width(8.dp)); Tag(s.incomplete, color = c.gold, strong = true) }
                        }
                        Spacer(Modifier.height(2.dp))
                        Text(
                            listOfNotNull(s.relativeTime(v.createdAt), s.charCount(v.markdown.length), v.note.takeIf { it.isNotBlank() }).joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 2, overflow = TextOverflow.Ellipsis,
                        )
                    }
                    if (!isLatest) GhostButton(s.restore, { onRestore(v) }, icon = Icons.Rounded.History)
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

// ------------------------------------------------------------------ 지금까지의 답변

@Composable
fun HistorySheet(title: String, turns: List<Turn>, onDismiss: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberSheet(onDismiss) {
        SheetTitle(title)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp)) {
            turns.filter { it.answer != null }.forEachIndexed { i, t ->
                Row(Modifier.padding(vertical = 8.dp)) {
                    Box(Modifier.size(26.dp).clip(CircleShape).background(c.surface2), contentAlignment = Alignment.Center) {
                        Text("${i + 1}", style = MaterialTheme.typography.labelSmall, color = c.textMuted)
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(t.question.title, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
                        Spacer(Modifier.height(2.dp))
                        Text(
                            if (t.answer?.skipped == true) s.skipped else t.answerSummary(),
                            style = MaterialTheme.typography.titleSmall,
                            color = if (t.answer?.skipped == true) c.textFaint else c.text,
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

// ------------------------------------------------------------------ Claude 로 넘기기

data class HandoffChoice(val goal: HandoffGoal, val answers: Boolean, val document: Boolean, val profile: Boolean, val extra: String)

@Composable
fun HandoffSheet(
    docTitle: String?,
    hasDocument: Boolean,
    defaultGoal: HandoffGoal,
    claudeInstalled: Boolean,
    preview: (HandoffChoice) -> String,
    onDismiss: () -> Unit,
    onOpen: (HandoffChoice) -> Unit,
    onCopy: (HandoffChoice) -> Unit,
    onShare: (HandoffChoice) -> Unit,
    onExportClaudeMd: (() -> Unit)? = null,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    var goal by rememberSaveable { mutableStateOf(defaultGoal) }
    var answers by rememberSaveable { mutableStateOf(true) }
    var document by rememberSaveable { mutableStateOf(hasDocument) }
    var profile by rememberSaveable { mutableStateOf(true) }
    var extra by rememberSaveable { mutableStateOf("") }
    var showPreview by rememberSaveable { mutableStateOf(false) }
    val choice = HandoffChoice(goal, answers, document, profile, extra)
    val text = remember(choice) { preview(choice) }

    EmberSheet(onDismiss) {
        SheetTitle(s.handoffTitle, if (claudeInstalled) s.handoffSubApp else s.handoffSubWeb)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            if (docTitle != null) {
                Text(s.handoffDocName(docTitle), style = MaterialTheme.typography.labelMedium, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(start = 4.dp, bottom = 8.dp))
            }
            HandoffGoal.entries.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pair.forEach { g -> GoalTile(s.goalTitle(g), s.goalShort(g), goal == g, Modifier.weight(1f)) { goal = g } }
                }
                Spacer(Modifier.height(8.dp))
            }
            Text(s.goalBody(goal), style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.padding(start = 4.dp, bottom = 4.dp))
            Text(s.includeLabel, style = MaterialTheme.typography.titleSmall, color = c.textMuted, modifier = Modifier.padding(start = 4.dp, top = 10.dp))
            ToggleRow(s.includeAnswers, null, answers, { answers = it })
            if (hasDocument) ToggleRow(s.includeDocument, null, document, { document = it })
            ToggleRow(s.includeProfile, null, profile, { profile = it })
            Spacer(Modifier.height(8.dp))
            EmberTextField(extra, { extra = it }, s.handoffExtraPlaceholder, minHeight = 56.dp, maxLength = 500)
            Spacer(Modifier.height(12.dp))
            // 미리 보기: 처음 몇 줄을 항상 보여 주고 눌러서 펼친다.
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.surface2).clickable { showPreview = !showPreview }.padding(14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(s.previewPrompt, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f))
                    Text(s.charCount(text.length), style = MaterialTheme.typography.labelMedium, color = c.textFaint)
                    Spacer(Modifier.width(4.dp))
                    Icon(if (showPreview) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = c.textMuted)
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    if (showPreview) text.take(4000) + if (text.length > 4000) "\n…" else "" else text,
                    style = MaterialTheme.typography.bodySmall,
                    color = c.textMuted,
                    maxLines = if (showPreview) Int.MAX_VALUE else 4,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (!claudeInstalled) {
                Text(s.claudeWebNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(start = 4.dp, top = 10.dp))
            }
            if (onExportClaudeMd != null) {
                GhostButton(s.exportClaudeMd, onExportClaudeMd, icon = Icons.Rounded.Description, modifier = Modifier.offset(x = (-12).dp).padding(top = 4.dp))
            }
            Spacer(Modifier.height(16.dp))
        }
        Column(Modifier.topFade(c.surface).padding(horizontal = 20.dp, vertical = 8.dp)) {
            PrimaryButton(if (claudeInstalled) s.openClaudeApp else s.openClaudeWeb, { onOpen(choice) }, Modifier.fillMaxWidth(), icon = Icons.AutoMirrored.Rounded.Send)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                GhostButton(s.copyPrompt, { onCopy(choice) }, icon = Icons.Rounded.ContentCopy, color = c.textMuted)
                GhostButton(s.share, { onShare(choice) }, icon = Icons.Rounded.Share, color = c.textMuted)
            }
        }
    }
}

// ------------------------------------------------------------------ 대화상자

@Composable
fun EmberDialog(
    title: String,
    body: String?,
    confirm: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    danger: Boolean = false,
    content: (@Composable () -> Unit)? = null,
    confirmEnabled: Boolean = true,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.surface,
        shape = RoundedCornerShape(28.dp),
        title = { Text(title, style = MaterialTheme.typography.titleLarge, color = c.text) },
        text = {
            Column {
                if (!body.isNullOrBlank()) Text(body, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
                if (content != null) { Spacer(Modifier.height(12.dp)); content() }
            }
        },
        confirmButton = { GhostButton(confirm, onConfirm, color = if (danger) c.danger else c.ember, enabled = confirmEnabled) },
        dismissButton = { GhostButton(s.cancel, onDismiss, color = c.textMuted) },
    )
}

@Composable
fun RenameDialog(current: String, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    val s = LocalStrings.current
    var text by rememberSaveable { mutableStateOf(current) }
    EmberDialog(
        title = s.rename,
        body = null,
        confirm = s.save,
        onConfirm = { onSave(text) },
        onDismiss = onDismiss,
        confirmEnabled = text.isNotBlank(),
        content = { EmberTextField(text, { text = it }, s.renamePlaceholder, singleLine = true, maxLength = 60) },
    )
}

@Suppress("unused")
private val unusedCheck = Icons.Rounded.CheckCircle

/** 아이디어를 공유·복사할 때 쓰는 일반 텍스트. */
fun ideaAsText(idea: Idea): String = Protocol.ideaBrief(idea).removePrefix("### ")


// ------------------------------------------------------------------ 아이디어 비교

@Composable
fun CompareSheet(ideas: List<Idea>, onDismiss: () -> Unit, onOpen: (Idea) -> Unit) {
    val s = LocalStrings.current
    EmberSheet(onDismiss) {
        SheetTitle(s.compareTitle, s.compareSub)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            val header = listOf("") + ideas.map { it.title }
            val rows = listOf(
                listOf(s.fieldScope) + ideas.map { it.scope },
                listOf(s.fieldDevTime) + ideas.map { it.devTime },
                listOf(s.fieldDifficulty) + ideas.map { "${it.difficulty}/5" },
                listOf(s.fieldCoreHook) + ideas.map { it.coreHook },
                listOf(s.fieldMonetization) + ideas.map { it.monetization },
                listOf(s.fieldUnique) + ideas.map { it.uniquePoint },
            )
            app.ember.ideas.ui.markdown.MarkdownBlockView(app.ember.ideas.ui.markdown.MdBlock.Table(header, rows))
            Spacer(Modifier.height(8.dp))
            ideas.forEach { idea ->
                GhostButton(s.openIdea(idea.title), { onOpen(idea) }, icon = Icons.AutoMirrored.Rounded.ArrowForward)
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}


@Composable
private fun GoalTile(title: String, body: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Ember.colors
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier
            .heightIn(min = 76.dp)
            .clip(shape)
            .background(if (selected) c.emberSoft else c.surface)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.ember else c.outline, shape)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f))
            if (selected) Icon(Icons.Rounded.CheckCircle, null, tint = c.ember, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.height(2.dp))
        Text(body, style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}
