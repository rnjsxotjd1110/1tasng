package app.ember.ideas.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.Category
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Savings
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Language
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.ui.components.EmberCard
import app.ember.ideas.ui.components.EmberChip
import app.ember.ideas.ui.components.EmberProgress
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SectionLabel
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.components.Tag
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import java.util.Calendar

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    onOpenProject: (String) -> Unit,
    onNeedKey: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenLibrary: () -> Unit,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val projects by container.store.projects.collectAsState()
    val settings by container.settings.settings.collectAsState()
    val ops by container.engine.ops.collectAsState()
    val focus = LocalFocusManager.current

    var kind by rememberSaveable { mutableStateOf<ProjectKind?>(null) }
    var seed by rememberSaveable { mutableStateOf("") }
    var shuffle by remember { mutableStateOf(0) }

    val inProgress = projects.filter { !it.isSample && it.stage != ProjectStage.DOCUMENT }.take(8)
    val docs = projects.filter { it.design?.latest != null }.take(3)

    fun start(quick: Boolean = false) {
        val k = kind ?: return
        if (!settings.hasKey) { onNeedKey(); return }
        focus.clearFocus()
        val p = container.engine.createProject(k, seed, s.defaultProjectTitle(k), quick)
        seed = ""
        kind = null
        onOpenProject(p.id)
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 72.dp),
    ) {
        item {
            Row(
                Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 8.dp, top = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(androidx.compose.ui.res.painterResource(app.ember.ideas.R.drawable.ic_ember_mark), null, tint = Color.Unspecified, modifier = Modifier.size(width = 18.dp, height = 28.dp))
                Spacer(Modifier.width(10.dp))
                Text("Ember", style = MaterialTheme.typography.titleLarge, color = c.text, modifier = Modifier.weight(1f))
                GhostButton(s.profileButton, onOpenProfile, icon = Icons.Rounded.Person, color = c.textMuted)
            }
        }
        if (settings.monthlyBudgetUsd > 0 && settings.monthUsage.costUsd >= settings.monthlyBudgetUsd * 0.8) {
            item {
                val pct = (settings.monthUsage.costUsd / settings.monthlyBudgetUsd * 100).toInt()
                Row(
                    Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(c.gold.copy(alpha = 0.14f)).padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.Savings, null, tint = c.gold, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(10.dp))
                    Text(s.budgetWarn(pct), style = MaterialTheme.typography.bodySmall, color = c.text)
                }
            }
        }
        if (inProgress.isNotEmpty()) {
            item {
                Spacer(Modifier.height(16.dp))
                SectionLabel(s.continueSection, Modifier.padding(horizontal = 20.dp))
            }
            item {
                if (inProgress.size == 1) {
                    val p = inProgress.first()
                    Box(Modifier.padding(horizontal = 20.dp)) { ContinueCard(p, busy = ops[p.id]?.running == true, full = true) { onOpenProject(p.id) } }
                } else {
                    Box {
                        LazyRow(contentPadding = PaddingValues(start = 20.dp, end = 40.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            items(inProgress, key = { it.id }) { p ->
                                ContinueCard(p, busy = ops[p.id]?.running == true) { onOpenProject(p.id) }
                            }
                        }
                        Box(Modifier.align(Alignment.CenterEnd).width(36.dp).height(80.dp).background(androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(c.bg.copy(alpha = 0f), c.bg))))
                    }
                }
            }
        }

        item {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Spacer(Modifier.height(if (inProgress.isNotEmpty()) 24.dp else 28.dp))
                if (inProgress.isEmpty()) {
                    Text(s.greeting(Calendar.getInstance().get(Calendar.HOUR_OF_DAY)), style = MaterialTheme.typography.titleSmall, color = c.ember)
                    Spacer(Modifier.height(8.dp))
                    Text(s.homeHeadline, style = MaterialTheme.typography.displaySmall, color = c.text)
                    Spacer(Modifier.height(10.dp))
                    Text(s.homeSub, style = MaterialTheme.typography.bodyLarge, color = c.textMuted)
                    Spacer(Modifier.height(24.dp))
                } else {
                    Text(s.newIdeaHeadline, style = MaterialTheme.typography.headlineSmall, color = c.text)
                    Spacer(Modifier.height(14.dp))
                }
                Text(s.pickKind, style = MaterialTheme.typography.titleSmall, color = c.textMuted)
                Spacer(Modifier.height(10.dp))
                listOf(listOf(ProjectKind.GAME, ProjectKind.APP), listOf(ProjectKind.WEB, ProjectKind.ANY)).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { k -> EmberChip(s.kindLabel(k), kind == k, { kind = if (kind == k) null else k }, Modifier.weight(1f), icon = kindIcon(k)) }
                    }
                    Spacer(Modifier.height(8.dp))
                }
                Spacer(Modifier.height(18.dp))
                EmberTextField(
                    value = seed,
                    onValueChange = { seed = it },
                    placeholder = s.seedPlaceholder,
                    minHeight = if (inProgress.isEmpty()) 92.dp else 56.dp,
                    maxLength = 400,
                )
                Spacer(Modifier.height(10.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    GhostButton(modifier = Modifier.offset(x = (-14).dp), text = s.inspireMe, onClick = {
                        shuffle++
                        seed = s.inspirations.random()
                        if (kind == null) kind = ProjectKind.ANY
                    }, icon = Icons.Rounded.Casino)
                    Spacer(Modifier.weight(1f))
                    if (seed.isNotEmpty()) Text("${seed.length}/400", style = MaterialTheme.typography.labelSmall, color = c.textFaint, modifier = Modifier.padding(end = 6.dp))
                }
                Spacer(Modifier.height(12.dp))
                PrimaryButton(
                    text = when {
                        !settings.hasKey -> s.connectToStart
                        kind == null -> s.pickKindFirst
                        else -> s.startDiscovery
                    },
                    onClick = { if (!settings.hasKey) onNeedKey() else start() },
                    enabled = kind != null || !settings.hasKey,
                    modifier = Modifier.fillMaxWidth(),
                    icon = if (!settings.hasKey) Icons.Rounded.Key else if (kind != null) Icons.AutoMirrored.Rounded.ArrowForward else null,
                )
                if (!settings.hasKey) {
                    Text(
                        s.costPerDiscovery(s.costApprox(app.ember.ideas.ai.CostEstimate.discovery(app.ember.ideas.ai.ClaudeModel.OPUS)), s.modelShort(app.ember.ideas.ai.ClaudeModel.OPUS)),
                        style = MaterialTheme.typography.bodySmall, color = c.textFaint,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    )
                }
                if (settings.hasKey) {
                    Text(
                        s.costPerDiscovery(s.costApprox(app.ember.ideas.ai.CostEstimate.discovery(settings.model)), s.modelShort(settings.model)),
                        style = MaterialTheme.typography.bodySmall,
                        color = c.textFaint,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    )
                    if (kind != null) {
                        Spacer(Modifier.height(8.dp))
                        SecondaryButton(s.quickIdeas, { start(quick = true) }, Modifier.fillMaxWidth(), icon = Icons.Rounded.FastForward, height = 48.dp)
                    }
                } else {
                    Spacer(Modifier.height(12.dp))
                    SecondaryButton(s.demoTry, {
                        val p = container.engine.createDemoProject(s.demoTitle)
                        onOpenProject(p.id)
                    }, Modifier.fillMaxWidth(), icon = Icons.Rounded.PlayArrow)
                    Text(s.noKeyHint, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(top = 10.dp))

                }
            }
        }

        if (docs.isNotEmpty()) {
            item {
                Spacer(Modifier.height(28.dp))
                SectionLabel(s.recentDocs, Modifier.padding(horizontal = 20.dp)) {
                    GhostButton(s.seeAll, onOpenLibrary, color = c.textMuted, modifier = Modifier.offset(x = 14.dp))
                }
            }
            items(docs, key = { "doc_" + it.id }) { p ->
                DocRow(p) { onOpenProject(p.id) }
            }
        }

        if (settings.profile.isEmpty()) {
            item {
                Spacer(Modifier.height(24.dp))
                EmberCard(Modifier.padding(horizontal = 20.dp).fillMaxWidth(), onClick = onOpenProfile) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Person, null, tint = c.ember)
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(s.profileTipTitle, style = MaterialTheme.typography.titleSmall, color = c.text)
                            Spacer(Modifier.height(2.dp))
                            Text(s.profileTipBody, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                        }
                        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = c.textFaint, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }
}

fun kindIcon(k: ProjectKind): androidx.compose.ui.graphics.vector.ImageVector = when (k) {
    ProjectKind.GAME -> Icons.Rounded.SportsEsports
    ProjectKind.APP -> Icons.Rounded.PhoneAndroid
    ProjectKind.WEB -> Icons.Rounded.Language
    ProjectKind.ANY -> Icons.Rounded.Category
}

@Composable
private fun ContinueCard(p: Project, busy: Boolean, full: Boolean = false, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val progress = when (p.stage) {
        ProjectStage.INTERVIEW -> (p.turns.lastOrNull()?.progress ?: 0) / 100f * 0.5f
        ProjectStage.IDEAS -> 0.55f
        ProjectStage.DESIGN_INTERVIEW -> 0.6f + (p.design?.turns?.lastOrNull()?.progress ?: 0) / 100f * 0.3f
        ProjectStage.DOCUMENT -> 1f
    }
    EmberCard(if (full) Modifier.fillMaxWidth() else Modifier.width(240.dp), onClick = onClick, padding = PaddingValues(14.dp)) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                KindBadge(p.kind, 36)
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text(p.title, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(
                        if (busy) s.working else if (p.stage == ProjectStage.IDEAS) continueHint(p, s) else s.stageLabel(p.stage) + " · " + continueHint(p, s),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (busy) c.ember else c.textMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            EmberProgress(progress, height = 4.dp)
        }
    }
}

private fun continueHint(p: Project, s: app.ember.ideas.ui.strings.Strings): String = when (p.stage) {
    ProjectStage.INTERVIEW -> s.answeredN(p.answeredCount)
    ProjectStage.IDEAS -> s.ideasCount(p.allIdeas.size)
    ProjectStage.DESIGN_INTERVIEW -> p.design?.turns?.lastOrNull()?.question?.title ?: s.stageLabel(p.stage)
    ProjectStage.DOCUMENT -> s.stageLabel(p.stage)
}

@Composable
private fun DocRow(p: Project, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Description, null, tint = c.textFaint, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(p.title, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (p.isSample) {
                    Spacer(Modifier.width(6.dp))
                    Tag(s.sample, color = c.gold, strong = true)
                }
            }
            Spacer(Modifier.height(2.dp))
            Text(
                p.selectedIdea?.logline ?: "",
                style = MaterialTheme.typography.bodySmall,
                color = c.textMuted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(s.relativeTime(p.updatedAt), style = MaterialTheme.typography.labelSmall, color = c.textFaint)
    }
}


/** 분야별 색 아이콘으로 프로젝트를 구분한다. 바탕 타일 없이 아이콘만 둔다. */
@Composable
fun KindBadge(kind: ProjectKind, sizeDp: Int) {
    val c = Ember.colors
    val tint = when (kind) {
        ProjectKind.GAME -> c.ember
        ProjectKind.APP -> c.info
        ProjectKind.WEB -> c.success
        ProjectKind.ANY -> c.gold
    }
    Box(Modifier.size(sizeDp.dp), contentAlignment = Alignment.Center) {
        Icon(kindIcon(kind), null, tint = tint, modifier = Modifier.size((sizeDp * 0.62f).dp))
    }
}
