package app.ember.ideas.ui.screens.project

import androidx.compose.foundation.layout.Arrangement
import app.ember.ideas.ui.components.ErrorPanel
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.CloudUpload
import androidx.compose.material.icons.rounded.Flag
import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.material.icons.rounded.FolderOff
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DriveFileRenameOutline
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import app.ember.ideas.ui.text.Text
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
    data class Revise(val initial: String = "") : Sheet
    data object EditDoc : Sheet
    data object Versions : Sheet
    data object History : Sheet
    data object DesignHistory : Sheet
    data object Compare : Sheet
    data class Report(val target: app.ember.ideas.report.ReportTarget) : Sheet
    data object GitHub : Sheet
    data object Workbench : Sheet
    data class Diff(val index: Int) : Sheet
    data class EditSection(val heading: String) : Sheet
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
                EmptyState(Icons.Rounded.FolderOff, s.projectMissingTitle, s.projectMissingBody) {
                    PrimaryButton(s.back, onBack)
                }
            }
        }
        return
    }

    val busy = op?.running == true
    // 첫 작업을 시작할 때 한 번만 알림 권한을 묻는다(Android 13 이상).
    val notifLauncher = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) { }
    androidx.compose.runtime.LaunchedEffect(busy) {
        if (!busy || android.os.Build.VERSION.SDK_INT < 33 || !settings.notifyDone || project?.isDemo == true) return@LaunchedEffect
        val meta = ctx.getSharedPreferences("ember_meta", android.content.Context.MODE_PRIVATE)
        val granted = androidx.core.content.ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (!granted && !meta.getBoolean("asked_notif", false)) {
            meta.edit().putBoolean("asked_notif", true).apply()
            notifLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }
    val error = op?.error
    val korean = s.isKorean

    /** 아이디어로 설계하기. 이미 설계서가 있으면 그 설계서를 열고, 작업 중이면 아무것도 하지 않는다. */
    fun designIdea(ideaId: String) {
        when {
            busy -> Unit
            project.designFor(ideaId) != null -> { sheet = null; viewStage = null; engine.openDesign(project.id, ideaId) }
            !settings.ready && !project.isDemo -> { sheet = null; onFixKey() }
            else -> sheet = Sheet.DesignSetup(ideaId)
        }
    }
    // 사용자가 문서 화면에서 아이디어 목록으로 잠시 돌아가 보는 경우를 위한 보기 단계.
    val stage = when {
        op?.running == true && op.kind == OpKind.IDEAS && project.stage == ProjectStage.INTERVIEW && project.ideaBatches.isEmpty() -> ProjectStage.INTERVIEW
        op?.running == true && (op.kind == OpKind.WRITING || op.kind == OpKind.REVISING) -> ProjectStage.DOCUMENT
        // 아이디어·문서 화면에서 '질문 더 받기'를 누르면 바로 질문 화면에서 기다리게 한다.
        op?.running == true && op.kind == OpKind.ASKING -> ProjectStage.INTERVIEW
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

    EmberBackground {
        Column(Modifier.fillMaxSize()) {
            EmberTopBar(
                title = project.title,
                subtitle = when {
                    project.isSample -> s.stageLabel(stage) + " · " + s.sample
                    stage == ProjectStage.INTERVIEW && !project.isDemo -> s.depthSubtitle(project.depthMode)
                    else -> s.stageLabel(stage)
                },
                onBack = {
                    if (viewStage != null && viewStage != project.stage) viewStage = null else onBack()
                },
                onTitleClick = { renaming = true },
            ) {
                if (stage == ProjectStage.DOCUMENT && project.design?.latest != null && !busy) {
                    IconCircleButton(Icons.Rounded.Share, s.share, {
                        val md = Handoff.aiLabeled(project.design.latest!!.markdown, korean)
                        Handoff.shareMarkdown(ctx, documentTitleOf(project), md, s.share)
                    }, filled = false)
                }
                Box {
                    IconCircleButton(Icons.Rounded.MoreVert, s.more, { menu = true }, filled = false)
                    DropdownMenu(menu, { menu = false }, containerColor = c.surface2) {
                        MenuItem(s.rename, Icons.Rounded.DriveFileRenameOutline) { menu = false; renaming = true }
                        MenuItem(if (project.favorite) s.unfavorite else s.favorite, Icons.Rounded.PushPin) {
                            menu = false; engine.setFavorite(project.id, !project.favorite)
                        }
                        if (project.allIdeas.isNotEmpty() && stage != ProjectStage.IDEAS) {
                            MenuItem(s.viewIdeas, Icons.Rounded.ViewAgenda) { menu = false; viewStage = ProjectStage.IDEAS }
                        }
                        if (stage == ProjectStage.IDEAS && project.design?.latest != null) {
                            MenuItem(s.viewDocument, Icons.Rounded.History) { menu = false; viewStage = ProjectStage.DOCUMENT }
                        }
                        if (stage == ProjectStage.DOCUMENT && project.design?.latest != null) {
                            if (!busy) MenuItem(s.editDocument, Icons.Rounded.DriveFileRenameOutline) { menu = false; sheet = Sheet.EditDoc }
                            MenuItem(s.copyDocument, Icons.Rounded.ContentCopy) {
                                menu = false
                                Handoff.copy(ctx, project.title, Handoff.aiLabeled(project.design.latest!!.markdown, korean))
                                Toast.makeText(ctx, s.copied, Toast.LENGTH_SHORT).show()
                            }
                            if ((project.design.versions.size) > 1) MenuItem(s.versionsTitle, Icons.Rounded.History) { menu = false; sheet = Sheet.Versions }
                            if (!busy) MenuItem(s.github, Icons.Rounded.CloudUpload) { menu = false; sheet = Sheet.GitHub }
                            if (!busy) MenuItem(s.regenerateAll, Icons.Rounded.Refresh) { menu = false; confirmRegenerate = true }
                        }
                        if ((stage == ProjectStage.INTERVIEW || stage == ProjectStage.DESIGN_INTERVIEW) && busy) {
                            MenuItem(s.stop, Icons.AutoMirrored.Rounded.ArrowBack) { menu = false; engine.cancel(project.id) }
                        }
                        if (!project.isSample) MenuItem(s.reportAi, Icons.Rounded.Flag) {
                            menu = false
                            sheet = Sheet.Report(app.ember.ideas.report.ReportSender.targetFor(project, stage))
                        }
                        MenuItem(s.delete, Icons.Rounded.Delete, danger = true) { menu = false; confirmDelete = true }
                    }
                }
            }

            if (project.isDemo) {
                androidx.compose.foundation.layout.Row(
                    Modifier
                        .padding(horizontal = 20.dp, vertical = 4.dp)
                        .fillMaxWidth()
                        .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                        .background(c.gold.copy(alpha = 0.12f))
                        .padding(start = 14.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                ) {
                    Text(s.demoBanner, style = MaterialTheme.typography.bodySmall, color = c.text, modifier = Modifier.weight(1f))
                    if (!settings.ready) app.ember.ideas.ui.components.GhostButton(s.demoConnect, onFixKey)
                }
            }
            Box(Modifier.weight(1f)) {
                when (stage) {
                    ProjectStage.INTERVIEW -> {
                        val noIdeasYet = project.ideaBatches.isEmpty()
                        val emptyAndIdle = project.turns.isEmpty() && !busy && error == null
                        if (emptyAndIdle) {
                            // 첫 질문 요청이 앱 종료 등으로 끊긴 경우
                            EmptyState(Icons.Rounded.History, s.resumeTitle, s.resumeBody) {
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
                                finishLabel = when {
                                    noIdeasYet -> s.showIdeasNow
                                    project.inExtraQuestions -> s.newIdeasNow
                                    else -> s.backToIdeasShort
                                },
                                canFinish = project.answeredCount >= 2 || !noIdeasYet,
                                draft = draft,
                                onSubmit = { a -> draft = null; engine.answer(project.id, a) },
                                onUndo = { draft = engine.undo(project.id) },
                                onFinish = {
                                    if (noIdeasYet || project.inExtraQuestions) engine.requestIdeasNow(project.id) else engine.backToIdeas(project.id)
                                },
                                onRetry = { engine.retry(project.id) },
                                onFixKey = onFixKey,
                                onShowHistory = { sheet = Sheet.History },
                                expectedTotal = if (project.isDemo) 8 else project.depthMode.questions.takeIf { it > 0 } ?: 12,
                                onStop = { engine.cancel(project.id) },
                                onLeave = { engine.dismissError(project.id); onBack() },
                                partial = op?.partial,
                                canUndoCurrent = engine.canUndo(project),
                                counter = when {
                                    project.inExtraQuestions -> ({ sending ->
                                        val total = app.ember.ideas.ai.Protocol.EXTRA_QUESTIONS
                                        s.extraQuestionOf((total - project.extraQuestionsLeft + if (sending) 1 else 0).coerceIn(1, total), total)
                                    })
                                    // 길게 단련하면 질문 수에 끝이 없으므로 몇 번째인지만 보여 준다.
                                    project.depthMode == app.ember.ideas.data.DepthMode.LONG -> ({ sending -> s.questionN((project.turns.size + if (sending) 1 else 0).coerceAtLeast(1)) })
                                    else -> null
                                },
                                heat = app.ember.ideas.ui.components.Heat.of(project, op?.kind),
                                heatLabels = s.heatStages,
                                heatCurrentLabel = s.heatNow(s.heatStages[1], project.turns.lastOrNull()?.progress ?: 0),
                                plates = project.presets.map { PlateItem(s.plateMold, "${it.category}: ${it.value}", true) } +
                                    project.turns.filter { it.answer != null && !it.answer.skipped }.map { PlateItem(s.plateAnswer, plateText(it), false) },
                                strikeLabel = s.strike,
                            )
                        }
                    }
                    ProjectStage.IDEAS -> IdeasContent(
                        project = project,
                        busy = busy,
                        error = error,
                        onOpenIdea = { sheet = Sheet.IdeaDetail(it.id) },
                        onCompare = { sheet = Sheet.Compare },
                        onDesignIdea = { designIdea(it.id) },
                        onToggleSave = { engine.toggleSaved(project.id, it.id) },
                        onMoreIdeas = { engine.moreIdeas(project.id) },
                        onMoreQuestions = { viewStage = null; engine.moreQuestions(project.id) },
                        onOpenDocument = { viewStage = null; engine.openDocument(project.id) },
                        onRetry = { engine.retry(project.id) },
                        onFixKey = onFixKey,
                        onDismissError = { engine.dismissError(project.id) },
                        onDeleteIdeas = { ids ->
                            val n = engine.deleteIdeas(project.id, ids)
                            Toast.makeText(ctx, if (n > 0) s.ideasDeleted(n) else s.busyCantDelete, Toast.LENGTH_SHORT).show()
                        },
                    )
                    ProjectStage.DESIGN_INTERVIEW -> if (project.design?.turns.isNullOrEmpty() && !busy && error == null) {
                        // 첫 설계 질문을 기다리다 중지했거나 앱이 꺼진 경우
                        EmptyState(Icons.Rounded.History, s.resumeTitle, s.designResumeBody) {
                            PrimaryButton(s.resume, { engine.designStart(project.id) })
                        }
                    } else {
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
                            partial = op?.partial,
                            expectedTotal = d?.depth?.designQuestions ?: 6,
                            heat = app.ember.ideas.ui.components.Heat.of(project, op?.kind),
                            heatLabels = s.heatStages,
                            heatCurrentLabel = s.heatNow(s.heatStages[2], d?.turns?.lastOrNull()?.progress ?: 0),
                            plates = d?.turns.orEmpty().filter { it.answer != null && !it.answer.skipped }.map { PlateItem(s.plateAnswer, plateText(it), false) },
                            strikeLabel = s.strike,
                            onStop = { engine.cancel(project.id) },
                            onLeave = { engine.dismissError(project.id); onBack() },
                        )
                    }
                    ProjectStage.DOCUMENT -> if (project.design?.latest == null && !busy) {
                        // 설계서를 쓰기 시작했지만 한 버전도 남지 않은 채 멈춘 경우
                        if (error != null) {
                            Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.Center) {
                                ErrorPanel(error, { engine.retry(project.id) }, onFixKey, onDismiss = { engine.dismissError(project.id) })
                            }
                        } else {
                            EmptyState(Icons.Rounded.Description, s.docResumeTitle, s.docResumeBody) {
                                PrimaryButton(s.resume, { engine.generateDocument(project.id) })
                            }
                        }
                    } else DocumentContent(
                        project = project,
                        busy = busy && (op?.kind == OpKind.WRITING || op?.kind == OpKind.REVISING),
                        revising = op?.kind == OpKind.REVISING,
                        streamingText = op?.streamingText.orEmpty(),
                        startedAt = op?.startedAt ?: System.currentTimeMillis(),
                        error = error,
                        onRevise = { sheet = Sheet.Revise() },
                        onReviseSection = { title -> sheet = Sheet.Revise(s.rewriteSection(title)) },
                        onEditSection = { heading -> sheet = Sheet.EditSection(heading) },
                        onHandoff = { sheet = Sheet.Handoff(project.design?.ideaId, HandoffGoal.START_BUILD) },
                        onWorkbench = { sheet = Sheet.Workbench },
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
        is Sheet.Report -> ReportSheet(sh.target) { sheet = null }
        Sheet.GitHub -> GitHubSheet(project) { sheet = null }
        Sheet.Workbench -> if (app.ember.ideas.BuildConfig.WORKBENCH_ENABLED) WorkbenchSheet(
            project,
            onDismiss = { sheet = null },
            onClaudeApp = { sheet = Sheet.Handoff(project.design?.ideaId, HandoffGoal.START_BUILD) },
            onGitHub = { sheet = Sheet.GitHub },
            onShareFile = {
                sheet = null
                project.design?.latest?.markdown?.let { Handoff.shareMarkdown(ctx, documentTitleOf(project), Handoff.aiLabeled(it, korean), s.share) }
            },
        )
        is Sheet.IdeaDetail -> project.idea(sh.ideaId)?.let { idea ->
            IdeaDetailSheet(
                idea = idea,
                saved = idea.id in project.savedIdeaIds,
                hasOtherIdeas = project.allIdeas.size > 1,
                busy = busy,
                onDismiss = { sheet = null },
                onToggleSave = { engine.toggleSaved(project.id, idea.id) },
                onDesign = {
                    designIdea(idea.id)
                },
                onVary = { sheet = Sheet.Vary(idea.id) },
                onCombine = { sheet = Sheet.Combine(idea.id) },
                onSendToClaude = { sheet = Sheet.Handoff(idea.id, HandoffGoal.BRAINSTORM) },
                onCopy = {
                    Handoff.copy(ctx, idea.title, ideaAsText(idea))
                    Toast.makeText(ctx, s.copied, Toast.LENGTH_SHORT).show()
                },
                onReport = { sheet = Sheet.Report(app.ember.ideas.report.ReportSender.forIdea(idea)) },
                hasDesign = project.designFor(idea.id) != null,
            )
        } ?: run { sheet = null }
        is Sheet.DesignSetup -> project.idea(sh.ideaId)?.let { idea ->
            DesignSetupSheet(idea, settings.activeModel, { sheet = null }) { depth, ask ->
                sheet = null
                viewStage = null
                engine.startDesign(project.id, idea.id, depth, ask)
            }
        }
        is Sheet.Vary -> project.idea(sh.ideaId)?.let { idea ->
            VariationSheet(idea, { sheet = null }) { dir ->
                sheet = null
                if (!settings.ready && !project.isDemo) onFixKey() else engine.variation(project.id, idea, dir)
            }
        }
        is Sheet.Combine -> project.idea(sh.ideaId)?.let { idea ->
            CombineSheet(idea, project.allIdeas.filter { it.id != idea.id }, { sheet = null }) { other ->
                sheet = null
                if (!settings.ready && !project.isDemo) onFixKey() else engine.combine(project.id, idea, other)
            }
        }
        is Sheet.Handoff -> HandoffSheet(
            docTitle = if (project.design?.latest != null) documentTitleOf(project) else null,
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
            onExportClaudeMd = if (project.design?.latest != null) ({
                val idea = sh.ideaId?.let { project.idea(it) } ?: project.selectedIdea
                Handoff.shareMarkdown(ctx, "CLAUDE", Handoff.buildClaudeMd(project, idea, settings.profile, korean), s.share, fileName = "CLAUDE.md")
            }) else null,
            onGitHub = if (project.design?.latest != null) ({ sheet = Sheet.GitHub }) else null,
        )
        Sheet.Compare -> CompareSheet(project.ideaBatches.lastOrNull()?.ideas ?: project.allIdeas, { sheet = null }, { sheet = Sheet.IdeaDetail(it.id) }, busy = busy, hasDesign = { project.designFor(it) != null }) {
            designIdea(it.id)
        }
        is Sheet.Revise -> ReviseSheet(app.ember.ideas.ai.CostEstimate.revision(settings.activeModel, project.design?.depth ?: app.ember.ideas.data.DocDepth.STANDARD), { sheet = null }, sh.initial) { text ->
            sheet = null
            if (!settings.ready && !project.isDemo) onFixKey() else engine.reviseDocument(project.id, text)
        }
        Sheet.EditDoc -> EditDocumentSheet(project.design?.latest?.markdown.orEmpty(), { sheet = null }) { md ->
            sheet = null
            engine.saveManualEdit(project.id, md, s.editedNote)
        }
        is Sheet.EditSection -> {
            val full = project.design?.latest?.markdown.orEmpty()
            val section = app.ember.ideas.data.DocSections.get(full, sh.heading)
            if (section == null) sheet = null
            else {
                val name = sh.heading.substringAfter(". ")
                EditDocumentSheet(section, { sheet = null }, title = s.editSectionTitle(name), subtitle = s.editSectionSub) { md ->
                    sheet = null
                    engine.saveManualEdit(project.id, app.ember.ideas.data.DocSections.replace(full, sh.heading, md), s.editedSectionNote(name))
                }
            }
        }
        is Sheet.Diff -> project.design?.versions?.let { vs ->
            if (sh.index in 1..vs.lastIndex) DiffSheet(vs[sh.index - 1], vs[sh.index], sh.index, sh.index + 1) { sheet = Sheet.Versions }
        }
        Sheet.Versions -> VersionsSheet(project.design?.versions.orEmpty(), { sheet = null }, onCompare = { sheet = Sheet.Diff(it) }) { v ->
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
            if (!settings.ready && !project.isDemo) onFixKey() else engine.generateDocument(project.id)
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


/** 단조판에 적을 한 줄: "갈래: 고른 답". 갈래가 없으면 질문 제목을 쓴다. */
internal fun plateText(t: app.ember.ideas.data.Turn): String =
    (t.stage.ifBlank { t.question.title.take(14) }) + ": " + t.answerSummary()
