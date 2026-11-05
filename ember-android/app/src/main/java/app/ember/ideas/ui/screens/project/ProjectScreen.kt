package app.ember.ideas.ui.screens.project

import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DriveFileRenameOutline
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.Answer
import app.ember.ideas.data.OpKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.handoff.Handoff
import app.ember.ideas.handoff.HandoffGoal
import app.ember.ideas.handoff.HandoffOptions
import app.ember.ideas.ui.components.EmberBackground
import app.ember.ideas.ui.components.EmberTopBar
import app.ember.ideas.ui.components.EmptyState
import app.ember.ideas.ui.components.IconCircleButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import java.util.Locale

private sealed interface Sheet {
    data class IdeaDetail(val ideaId: String) : Sheet
    data class DesignSetup(val ideaId: String) : Sheet
    data class Vary(val ideaId: String) : Sheet
    data class Combine(val ideaId: String) : Sheet
    data class Handoff(val ideaId: String?, val goal: HandoffGoal) : Sheet
    data object Revise : Sheet
    data object Versions : Sheet
    data object History : Sheet
    data object DesignHistory : Sheet
}

@Composable
fun ProjectScreen(projectId: String, onBack: () -> Unit, onFixKey: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val engine = container.engine
    val projects by container.store.projects.collectAsState()
    val ops by engine.ops.collectAsState()
    val settings by container.settings.settings.collectAsState()
    val project = projects.firstOrNull { it.id == projectId }
    val op = ops[projectId]

    var sheet by remember { mutableStateOf<Sheet?>(null) }
    var menu by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var confirmRegenerate by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf<Answer?>(null) }
    var designDraft by remember { mutableStateOf<Answer?>(null) }
    var viewStage by rememberSaveable { mutableStateOf<ProjectStage?>(null) }

    if (project == null) {
        EmberBackground {
            Column(Modifier.fillMaxSize()) {
                EmberTopBar("", onBack)
                EmptyState(Icons.Rounded.Lightbulb, s.projectMissingTitle, s.projectMissingBody) {
                    PrimaryButton(s.back, onBack)
                }
            }
        }
        return
    }

    val busy = op?.running == true
    val error = op?.error
    val korean = s.isKorean
    // 사용자가 문서 화면에서 아이디어 목록으로 잠시 돌아가 보는 경우를 위한 보기 단계.
    val stage = when {
        op?.running == true && op.kind == OpKind.IDEAS && project.stage == ProjectStage.INTERVIEW && project.ideaBatches.isEmpty() -> ProjectStage.INTERVIEW
        op?.running == true && (op.kind == OpKind.WRITING || op.kind == OpKind.REVISING) -> ProjectStage.DOCUMENT
        else -> viewStage ?: project.stage
    }

    fun handoffText(choice: HandoffChoice, ideaId: String?): String {
        val idea = ideaId?.let { project.idea(it) } ?: project.selectedIdea
        return Handoff.buildPrompt(
            project, idea, settings.profile,
            HandoffOptions(choice.goal, choice.answers, choice.document, choice.profile, choice.extra),
            korean,
        )
    }

    EmberBackground(glow = stage != ProjectStage.DOCUMENT) {
        Column(Modifier.fillMaxSize()) {
            EmberTopBar(
                title = project.title,
                subtitle = s.stageLabel(stage) + if (project.isSample) " · " + s.sample else "",
                onBack = {
                    if (viewStage != null && viewStage != project.stage) viewStage = null else onBack()
                },
                onTitleClick = { renaming = true },
            ) {
                if (stage == ProjectStage.DOCUMENT && project.design?.latest != null && !busy) {
                    IconCircleButton(Icons.Rounded.Share, s.share, {
                        val md = project.design.latest!!.markdown
                        Handoff.shareMarkdown(ctx, documentTitleOf(project), md, s.share)
                    }, filled = false)
                }
                Box {
                    IconCircleButton(Icons.Rounded.MoreVert, s.more, { menu = true }, filled = false)
                    DropdownMenu(menu, { menu = false }, containerColor = c.surface2) {
                        MenuItem(s.rename, Icons.Rounded.DriveFileRenameOutline) { menu = false; renaming = true }
                        MenuItem(if (project.favorite) s.unfavorite else s.favorite, if (project.favorite) Icons.Rounded.Star else Icons.Rounded.StarBorder) {
                            menu = false; engine.setFavorite(project.id, !project.favorite)
                        }
                        if (project.allIdeas.isNotEmpty() && stage != ProjectStage.IDEAS) {
                            MenuItem(s.viewIdeas, Icons.Rounded.Lightbulb) { menu = false; viewStage = ProjectStage.IDEAS }
                        }
                        if (stage == ProjectStage.IDEAS && project.design?.latest != null) {
                            MenuItem(s.viewDocument, Icons.Rounded.History) { menu = false; viewStage = ProjectStage.DOCUMENT }
                        }
                        if (stage == ProjectStage.DOCUMENT && project.design?.latest != null) {
                            MenuItem(s.copyDocument, Icons.Rounded.ContentCopy) {
                                menu = false
                                Handoff.copy(ctx, project.title, project.design.latest!!.markdown)
                                Toast.makeText(ctx, s.copied, Toast.LENGTH_SHORT).show()
                            }
                            if ((project.design.versions.size) > 1) MenuItem(s.versionsTitle, Icons.Rounded.History) { menu = false; sheet = Sheet.Versions }
                            if (!busy) MenuItem(s.regenerateAll, Icons.Rounded.Refresh) { menu = false; confirmRegenerate = true }
                        }
                        if ((stage == ProjectStage.INTERVIEW || stage == ProjectStage.DESIGN_INTERVIEW) && busy) {
                            MenuItem(s.stop, Icons.AutoMirrored.Rounded.ArrowBack) { menu = false; engine.cancel(project.id) }
                        }
                        MenuItem(s.delete, Icons.Rounded.Delete, danger = true) { menu = false; confirmDelete = true }
                    }
                }
            }

            Box(Modifier.weight(1f)) {
                when (stage) {
                    ProjectStage.INTERVIEW -> {
                        val noIdeasYet = project.ideaBatches.isEmpty()
                        val emptyAndIdle = project.turns.isEmpty() && !busy && error == null
                        if (emptyAndIdle) {
                            // 첫 질문 요청이 앱 종료 등으로 끊긴 경우
                            EmptyState(Icons.Rounded.Lightbulb, s.resumeTitle, s.resumeBody) {
                                PrimaryButton(s.resume, { engine.startInterview(project.id) })
                            }
                        } else {
                            QuestionFlow(
                                turns = project.turns,
                                busy = busy,
                                error = error,
                                thinkingTitle = when {
                                    op?.kind == OpKind.IDEAS -> s.ideaThinkingTitle
                                    project.turns.isEmpty() -> s.firstQuestionTitle
                                    else -> s.nextQuestionTitle
                                },
                                thinkingLines = if (op?.kind == OpKind.IDEAS) s.ideaThinkingLines else s.questionThinkingLines,
                                finishLabel = if (noIdeasYet) s.showIdeasNow else s.backToIdeasShort,
                                canFinish = project.answeredCount >= 2 || !noIdeasYet,
                                draft = draft,
                                onSubmit = { a -> draft = null; engine.answer(project.id, a) },
                                onUndo = { draft = engine.undo(project.id) },
                                onFinish = {
                                    if (noIdeasYet) engine.requestIdeasNow(project.id) else engine.backToIdeas(project.id)
                                },
                                onRetry = { engine.retry(project.id) },
                                onFixKey = onFixKey,
                                onShowHistory = { sheet = Sheet.History },
                            )
                        }
                    }
                    ProjectStage.IDEAS -> IdeasContent(
                        project = project,
                        busy = busy,
                        error = error,
                        onOpenIdea = { sheet = Sheet.IdeaDetail(it.id) },
                        onToggleSave = { engine.toggleSaved(project.id, it.id) },
                        onMoreIdeas = { engine.moreIdeas(project.id) },
                        onMoreQuestions = { viewStage = null; engine.moreQuestions(project.id) },
                        onOpenDocument = { viewStage = null; engine.openDocument(project.id) },
                        onRetry = { engine.retry(project.id) },
                        onFixKey = onFixKey,
                        onDismissError = { engine.dismissError(project.id) },
                    )
                    ProjectStage.DESIGN_INTERVIEW -> {
                        val d = project.design
                        QuestionFlow(
                            turns = d?.turns.orEmpty(),
                            busy = busy,
                            error = error,
                            thinkingTitle = if (d?.turns.isNullOrEmpty()) s.designFirstTitle else s.nextQuestionTitle,
                            thinkingLines = s.designThinkingLines,
                            finishLabel = s.writeDocNow,
                            canFinish = (d?.turns?.count { it.answer != null } ?: 0) >= 1,
                            draft = designDraft,
                            onSubmit = { a -> designDraft = null; engine.designAnswer(project.id, a) },
                            onUndo = { designDraft = engine.designUndo(project.id) },
                            onFinish = { engine.designReadyNow(project.id) },
                            onRetry = { engine.retry(project.id) },
                            onFixKey = onFixKey,
                            onShowHistory = { sheet = Sheet.DesignHistory },
                        )
                    }
                    ProjectStage.DOCUMENT -> DocumentContent(
                        project = project,
                        busy = busy && (op?.kind == OpKind.WRITING || op?.kind == OpKind.REVISING),
                        revising = op?.kind == OpKind.REVISING,
                        streamingText = op?.streamingText.orEmpty(),
                        error = error,
                        onRevise = { sheet = Sheet.Revise },
                        onHandoff = { sheet = Sheet.Handoff(project.design?.ideaId, HandoffGoal.START_BUILD) },
                        onStop = { engine.cancel(project.id) },
                        onRegenerate = { engine.generateDocument(project.id) },
                        onRetry = { engine.retry(project.id) },
                        onFixKey = onFixKey,
                        onDismissError = { engine.dismissError(project.id) },
                    )
                }
            }
        }
    }

    // ---------------------------------------------------------------- 시트·대화상자
    when (val sh = sheet) {
        is Sheet.IdeaDetail -> project.idea(sh.ideaId)?.let { idea ->
            IdeaDetailSheet(
                idea = idea,
                saved = idea.id in project.savedIdeaIds,
                hasOtherIdeas = project.allIdeas.size > 1,
                busy = busy,
                onDismiss = { sheet = null },
                onToggleSave = { engine.toggleSaved(project.id, idea.id) },
                onDesign = {
                    if (!settings.hasKey) { sheet = null; onFixKey() } else sheet = Sheet.DesignSetup(idea.id)
                },
                onVary = { sheet = Sheet.Vary(idea.id) },
                onCombine = { sheet = Sheet.Combine(idea.id) },
                onSendToClaude = { sheet = Sheet.Handoff(idea.id, HandoffGoal.BRAINSTORM) },
                onCopy = {
                    Handoff.copy(ctx, idea.title, ideaAsText(idea))
                    Toast.makeText(ctx, s.copied, Toast.LENGTH_SHORT).show()
                },
            )
        } ?: run { sheet = null }
        is Sheet.DesignSetup -> project.idea(sh.ideaId)?.let { idea ->
            DesignSetupSheet(idea, { sheet = null }) { depth, ask ->
                sheet = null
                viewStage = null
                engine.startDesign(project.id, idea.id, depth, ask)
            }
        }
        is Sheet.Vary -> project.idea(sh.ideaId)?.let { idea ->
            VariationSheet(idea, { sheet = null }) { dir ->
                sheet = null
                if (!settings.hasKey) onFixKey() else engine.variation(project.id, idea, dir)
            }
        }
        is Sheet.Combine -> project.idea(sh.ideaId)?.let { idea ->
            CombineSheet(idea, project.allIdeas.filter { it.id != idea.id }, { sheet = null }) { other ->
                sheet = null
                if (!settings.hasKey) onFixKey() else engine.combine(project.id, idea, other)
            }
        }
        is Sheet.Handoff -> HandoffSheet(
            hasDocument = project.design?.latest != null,
            defaultGoal = sh.goal,
            claudeInstalled = remember { Handoff.isClaudeInstalled(ctx) },
            preview = { handoffText(it, sh.ideaId) },
            onDismiss = { sheet = null },
            onOpen = { ch ->
                val r = Handoff.open(ctx, handoffText(ch, sh.ideaId))
                val msg = when (r) {
                    Handoff.OpenResult.CLAUDE_APP -> s.openedClaudeApp
                    Handoff.OpenResult.WEB_WITH_PROMPT -> s.openedClaudeWeb
                    Handoff.OpenResult.WEB_PASTE -> s.openedPaste
                    Handoff.OpenResult.FAILED -> s.openFailed
                }
                Toast.makeText(ctx, msg, Toast.LENGTH_LONG).show()
                sheet = null
            },
            onCopy = { ch ->
                Handoff.copy(ctx, "Ember", handoffText(ch, sh.ideaId))
                Toast.makeText(ctx, s.copied, Toast.LENGTH_SHORT).show()
            },
            onShare = { ch -> Handoff.shareText(ctx, handoffText(ch, sh.ideaId), s.share) },
        )
        Sheet.Revise -> ReviseSheet({ sheet = null }) { text ->
            sheet = null
            if (!settings.hasKey) onFixKey() else engine.reviseDocument(project.id, text)
        }
        Sheet.Versions -> VersionsSheet(project.design?.versions.orEmpty(), { sheet = null }) { v ->
            sheet = null
            engine.restoreVersion(project.id, v.id, s.restoredNote(project.design?.versions?.indexOf(v)?.plus(1) ?: 0))
        }
        Sheet.History -> HistorySheet(s.answersTitle, project.turns) { sheet = null }
        Sheet.DesignHistory -> HistorySheet(s.decisionsTitle, project.design?.turns.orEmpty()) { sheet = null }
        null -> Unit
    }

    if (renaming) {
        RenameDialog(project.title, { renaming = false }) { engine.rename(project.id, it); renaming = false }
    }
    if (confirmDelete) {
        EmberDialog(s.deleteTitle, s.deleteBody(project.title), s.delete, {
            confirmDelete = false
            engine.delete(project.id)
            onBack()
        }, { confirmDelete = false }, danger = true)
    }
    if (confirmRegenerate) {
        EmberDialog(s.regenerateAll, s.regenerateBody, s.regenerate, {
            confirmRegenerate = false
            if (!settings.hasKey) onFixKey() else engine.generateDocument(project.id)
        }, { confirmRegenerate = false })
    }

    @Suppress("UNUSED_VARIABLE") val unusedLocale = Locale.ROOT
}

@Composable
private fun MenuItem(text: String, icon: ImageVector, danger: Boolean = false, onClick: () -> Unit) {
    val c = Ember.colors
    DropdownMenuItem(
        text = { Text(text, style = MaterialTheme.typography.bodyMedium, color = if (danger) c.danger else c.text) },
        leadingIcon = { Icon(icon, null, tint = if (danger) c.danger else c.textMuted, modifier = androidx.compose.ui.Modifier) },
        onClick = onClick,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp),
    )
}
