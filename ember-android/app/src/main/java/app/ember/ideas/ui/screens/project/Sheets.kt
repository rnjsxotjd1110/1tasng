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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.CallMerge
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.FileDownload
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
import app.ember.ideas.ui.components.IconCircleButton
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
private fun SheetTitle(title: String, subtitle: String? = null, onClose: (() -> Unit)? = null) {
    val c = Ember.colors
    Column(Modifier.padding(start = 20.dp, end = 8.dp, top = 4.dp, bottom = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.headlineSmall, color = c.text, modifier = Modifier.weight(1f))
            if (onClose != null) IconCircleButton(Icons.Rounded.Close, LocalStrings.current.close, onClose, filled = false, tint = c.textMuted)
        }
        if (!subtitle.isNullOrBlank()) {
            Spacer(Modifier.height(4.dp))
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = c.textMuted, modifier = Modifier.padding(end = 12.dp))
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
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(idea.title, style = MaterialTheme.typography.headlineMedium, color = c.text, modifier = Modifier.weight(1f))
                HeartButton(saved, onToggleSave)
                IconCircleButton(Icons.Rounded.Close, s.close, onDismiss, filled = false, tint = c.textMuted)
            }
            Spacer(Modifier.height(6.dp))
            Text(idea.logline, style = MaterialTheme.typography.bodyLarge, color = c.text.copy(alpha = 0.9f))
            Spacer(Modifier.height(14.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                (listOf(idea.genre.ifBlank { idea.category }, idea.scope, idea.devTime) + idea.platforms).filter { it.isNotBlank() }.distinct().forEach { Tag(it) }
            }
            Spacer(Modifier.height(14.dp))
            StatRow(idea)
            DetailBlock(s.fieldCoreHook, idea.coreHook)
            if (idea.risks.isNotEmpty()) BulletBlock(s.fieldRisks, idea.risks)
            DetailBlock(s.fieldValidation, idea.validation)
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
            if (idea.similarWorks.isNotEmpty()) BulletBlock(s.fieldSimilar, idea.similarWorks)
            DetailTitle(s.tryDifferently)
            Row(Modifier.fillMaxWidth().offset(x = (-12).dp)) {
                GhostButton(s.vary, onVary, icon = Icons.Rounded.Shuffle, enabled = !busy)
                if (hasOtherIdeas) GhostButton(s.combine, onCombine, icon = Icons.Rounded.CallMerge, enabled = !busy)
                GhostButton(s.copy, onCopy, icon = Icons.Rounded.ContentCopy, color = c.textMuted)
            }
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
private fun BulletBlock(title: String, items: List<String>) {
    val c = Ember.colors
    DetailTitle(title)
    items.forEach { f ->
        Row(Modifier.padding(vertical = 3.dp)) {
            Box(Modifier.padding(top = 8.dp, end = 10.dp).size(6.dp).clip(CircleShape).background(c.textFaint))
            Text(f, style = MaterialTheme.typography.bodyMedium, color = c.text)
        }
    }
}

@Composable
private fun DetailTitle(t: String) {
    Text(t, style = MaterialTheme.typography.titleSmall, color = Ember.colors.text, modifier = Modifier.padding(top = 18.dp, bottom = 6.dp))
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
        SheetTitle(s.designSetupTitle, s.designSetupSub(idea.title), onDismiss)
        Column(Modifier.padding(horizontal = 20.dp)) {
            Spacer(Modifier.height(8.dp))
            DocDepth.entries.forEach { d ->
                val cost = s.costApprox(app.ember.ideas.ai.CostEstimate.design(model, d, ask))
                val (lo, hi) = app.ember.ideas.ai.CostEstimate.minutes(model, d)
                ChoiceRow(s.depthTitle(d), s.depthBody(d) + "\n" + s.depthMeta(d, cost, s.minutes(lo, hi)), depth == d) { depth = d }
                Spacer(Modifier.height(8.dp))
            }
            Spacer(Modifier.height(4.dp))
            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).border(1.dp, Ember.colors.outline, RoundedCornerShape(18.dp)).padding(horizontal = 12.dp, vertical = 4.dp)) {
                ToggleRow(s.askDesignQuestions, s.askDesignQuestionsBody, ask, { ask = it })
            }
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
        SheetTitle(s.varyTitle, s.varySub(idea.title), onDismiss)
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
        SheetTitle(s.combineTitle, s.combineSub(base.title), onDismiss)
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
fun ReviseSheet(costUsd: Double, onDismiss: () -> Unit, initialText: String = "", onSubmit: (String) -> Unit) {
    val s = LocalStrings.current
    var preset by rememberSaveable { mutableStateOf<String?>(null) }
    var text by rememberSaveable { mutableStateOf(initialText) }
    val instruction = listOfNotNull(preset, text.trim().takeIf { it.isNotEmpty() }).joinToString(". ")
    EmberSheet(onDismiss) {
        SheetTitle(s.reviseTitle, s.reviseSub, onDismiss)
        Column(Modifier.padding(horizontal = 20.dp)) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                s.revisePresets.forEach { p -> EmberChip(p, preset == p, { preset = if (preset == p) null else p }) }
            }
            Spacer(Modifier.height(12.dp))
            EmberTextField(text, { text = it }, s.revisePlaceholder, minHeight = 96.dp, maxLength = 800)
            Text(s.reviseCost(s.costApprox(costUsd)), style = MaterialTheme.typography.bodySmall, color = Ember.colors.textFaint, modifier = Modifier.padding(top = 8.dp))
            Spacer(Modifier.height(14.dp))
            PrimaryButton(s.applyRevision, { onSubmit(instruction) }, Modifier.fillMaxWidth(), enabled = instruction.isNotBlank())
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
fun VersionsSheet(versions: List<DocVersion>, onDismiss: () -> Unit, onRestore: (DocVersion) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberSheet(onDismiss) {
        SheetTitle(s.versionsTitle, s.versionsSub, onDismiss)
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
        SheetTitle(title, null, onDismiss)
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
        SheetTitle(s.handoffTitle, if (claudeInstalled) s.handoffSubApp else s.handoffSubWeb, onDismiss)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            if (docTitle != null) {
                Text(s.handoffDocName(docTitle), style = MaterialTheme.typography.labelMedium, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(bottom = 8.dp))
            }
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
                    maxLines = if (showPreview) Int.MAX_VALUE else 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(12.dp))
            (listOf(defaultGoal) + HandoffGoal.entries.filter { it != defaultGoal }).forEach { g ->
                GoalTile(s.goalTitle(g), if (goal == g) s.goalBody(g) else s.goalShort(g), goal == g, Modifier.fillMaxWidth()) { goal = g }
                Spacer(Modifier.height(8.dp))
            }
            Spacer(Modifier.height(4.dp))
            Text(s.includeLabel, style = MaterialTheme.typography.titleSmall, color = c.textMuted, modifier = Modifier.padding(top = 10.dp))
            Column(Modifier.fillMaxWidth().padding(top = 8.dp).clip(RoundedCornerShape(18.dp)).border(1.dp, c.outline, RoundedCornerShape(18.dp)).padding(horizontal = 12.dp, vertical = 4.dp)) {
                ToggleRow(s.includeAnswers, null, answers, { answers = it })
                if (hasDocument) ToggleRow(s.includeDocument, null, document, { document = it })
                ToggleRow(s.includeProfile, null, profile, { profile = it })
            }
            Spacer(Modifier.height(8.dp))
            EmberTextField(extra, { extra = it }, s.handoffExtraPlaceholder, minHeight = 56.dp, maxLength = 500)
            Spacer(Modifier.height(12.dp))
            Spacer(Modifier.height(16.dp))
        }
        Column(Modifier.topFade(c.surface).padding(horizontal = 20.dp, vertical = 8.dp)) {
            PrimaryButton(if (claudeInstalled) s.openClaudeApp else s.openClaudeWeb, { onOpen(choice) }, Modifier.fillMaxWidth(), icon = Icons.AutoMirrored.Rounded.Send)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                GhostButton(s.copyPrompt, { onCopy(choice) }, icon = Icons.Rounded.ContentCopy, color = c.textMuted)
                GhostButton(s.share, { onShare(choice) }, icon = Icons.Rounded.Share, color = c.textMuted)
                if (onExportClaudeMd != null) GhostButton("CLAUDE.md", onExportClaudeMd, icon = Icons.Rounded.FileDownload, color = c.textMuted)
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
fun CompareSheet(ideas: List<Idea>, onDismiss: () -> Unit, onOpen: (Idea) -> Unit, onDesign: (Idea) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val easiest = ideas.minByOrNull { it.difficulty }?.id
    val rows: List<Pair<String, (Idea) -> String>> = listOf(
        s.fieldScope to { it.scope },
        s.fieldDevTime to { it.devTime },
        s.fieldDifficulty to { "${it.difficulty}/5" },
        s.fieldCoreHook to { it.coreHook },
        s.fieldMonetization to { it.monetization },
        s.fieldUnique to { it.uniquePoint },
        s.fieldRisks to { it.risks.firstOrNull().orEmpty() },
    )
    val density = androidx.compose.ui.platform.LocalDensity.current
    // 각 행의 실제 높이를 재서 고정된 항목 열과 맞춘다.
    val heights = remember { androidx.compose.runtime.mutableStateListOf(*Array(rows.size + 1) { 0 }) }
    val labelW = 88.dp
    val colW = 164.dp
    EmberSheet(onDismiss) {
        SheetTitle(s.compareTitle, s.compareCount(ideas.size), onDismiss)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState())) {
            Row(Modifier.padding(start = 20.dp)) {
                Column(Modifier.width(labelW)) {
                    Box(Modifier.height(with(density) { heights[0].toDp() }))
                    rows.forEachIndexed { i, (label, _) ->
                        Box(Modifier.height(with(density) { heights[i + 1].toDp() }).padding(top = 10.dp)) {
                            Text(label, style = MaterialTheme.typography.labelMedium, color = c.textMuted)
                        }
                    }
                }
                Column(Modifier.horizontalScroll(rememberScrollState()).padding(end = 20.dp)) {
                    // 머리 행: 아이디어 제목
                    Row(Modifier.height(IntrinsicSize.Min).onSizeChanged { heights[0] = it.height }) {
                        ideas.forEach { idea ->
                            Column(Modifier.width(colW).fillMaxHeight().padding(end = 8.dp).clip(RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp)).background(if (idea.id == easiest) c.emberSoft else c.surface2).padding(12.dp)) {
                                Text(idea.title, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                if (idea.id == easiest) { Spacer(Modifier.height(4.dp)); Tag(s.easiest, color = c.success, strong = true) }
                            }
                        }
                    }
                    rows.forEachIndexed { r, (_, value) ->
                        Row(Modifier.height(IntrinsicSize.Min).onSizeChanged { heights[r + 1] = it.height }) {
                            ideas.forEach { idea ->
                                val best = r == 2 && idea.id == easiest
                                Box(Modifier.width(colW).fillMaxHeight().padding(end = 8.dp).background(if (idea.id == easiest) c.emberSoft else c.surface2).padding(horizontal = 12.dp, vertical = 10.dp)) {
                                    Text(
                                        value(idea).ifBlank { "—" },
                                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = if (best) androidx.compose.ui.text.font.FontWeight.Bold else androidx.compose.ui.text.font.FontWeight.Normal),
                                        color = if (best) c.success else c.text,
                                    )
                                }
                            }
                        }
                    }
                    Row {
                        ideas.forEach { idea ->
                            Column(Modifier.width(colW).padding(end = 8.dp).clip(RoundedCornerShape(bottomStart = 14.dp, bottomEnd = 14.dp)).background(if (idea.id == easiest) c.emberSoft else c.surface2).padding(horizontal = 4.dp)) {
                                GhostButton(s.designThisShort, { onDesign(idea) }, icon = Icons.AutoMirrored.Rounded.ArrowForward)
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun CompareLine(label: String, value: String) {
    if (value.isBlank()) return
    val c = Ember.colors
    Row(Modifier.fillMaxWidth().padding(end = 12.dp, bottom = 6.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = c.textFaint, modifier = Modifier.width(84.dp))
        Text(value, style = MaterialTheme.typography.bodySmall, color = c.text, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun GoalTile(title: String, body: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Ember.colors
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier
            .heightIn(min = 56.dp)
            .clip(shape)
            .background(if (selected) c.emberSoft else c.surface)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.ember else c.outline, shape)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f).padding(end = 12.dp)) {
                Text(title, style = MaterialTheme.typography.titleSmall, color = c.text)
                Text(body, style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = if (selected) 3 else 1, overflow = TextOverflow.Ellipsis)
            }
            SelectMark(selected, multi = false)
        }
    }
}


// ------------------------------------------------------------------ 직접 편집

@Composable
fun EditDocumentSheet(markdown: String, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    var text by rememberSaveable { mutableStateOf(markdown) }
    EmberSheet(onDismiss) {
        SheetTitle(s.editDocument, s.editDocumentSub, onDismiss)
        Column(Modifier.weight(1f, fill = false).padding(horizontal = 20.dp)) {
            androidx.compose.foundation.text.BasicTextField(
                value = text,
                onValueChange = { text = it },
                textStyle = MaterialTheme.typography.bodyMedium.copy(color = c.text),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(c.ember),
                modifier = Modifier.fillMaxWidth().heightIn(min = 240.dp, max = 520.dp).clip(RoundedCornerShape(16.dp)).background(c.surface2).padding(14.dp).verticalScroll(rememberScrollState()),
            )
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
            PrimaryButton(s.save, { onSave(text) }, Modifier.fillMaxWidth(), enabled = text.isNotBlank() && text != markdown)
        }
    }
}
