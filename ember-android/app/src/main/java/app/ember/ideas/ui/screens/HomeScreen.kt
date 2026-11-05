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
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Person
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
        contentPadding = PaddingValues(bottom = 48.dp),
    ) {
        item {
            Row(
                Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 8.dp, top = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(30.dp).clip(RoundedCornerShape(10.dp)).background(c.emberGradient), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(17.dp))
                }
                Spacer(Modifier.width(10.dp))
                Text("Ember", style = MaterialTheme.typography.titleLarge, color = c.text, modifier = Modifier.weight(1f))
                GhostButton(s.profileButton, onOpenProfile, icon = Icons.Rounded.Person, color = c.textMuted)
            }
        }
        item {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Spacer(Modifier.height(28.dp))
                Text(s.greeting(Calendar.getInstance().get(Calendar.HOUR_OF_DAY)), style = MaterialTheme.typography.titleSmall, color = c.ember)
                Spacer(Modifier.height(8.dp))
                Text(s.homeHeadline, style = MaterialTheme.typography.displaySmall, color = c.text)
                Spacer(Modifier.height(10.dp))
                Text(s.homeSub, style = MaterialTheme.typography.bodyLarge, color = c.textMuted)
                Spacer(Modifier.height(24.dp))
                Text(s.pickKind, style = MaterialTheme.typography.titleSmall, color = c.textMuted)
                Spacer(Modifier.height(10.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(ProjectKind.GAME, ProjectKind.APP, ProjectKind.WEB, ProjectKind.ANY).forEach { k ->
                        EmberChip(s.kindLabel(k), kind == k, { kind = if (kind == k) null else k }, icon = kindIcon(k))
                    }
                }
                Spacer(Modifier.height(18.dp))
                EmberTextField(
                    value = seed,
                    onValueChange = { seed = it },
                    placeholder = s.seedPlaceholder,
                    minHeight = 92.dp,
                    maxLength = 400,
                )
                Spacer(Modifier.height(10.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    GhostButton(s.inspireMe, {
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
                if (settings.hasKey) {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                        Text(
                            s.costPerDiscovery(s.costApprox(app.ember.ideas.ai.CostEstimate.discovery(settings.model)), s.modelShort(settings.model)),
                            style = MaterialTheme.typography.bodySmall,
                            color = c.textFaint,
                            modifier = Modifier.weight(1f).padding(start = 4.dp),
                        )
                        if (kind != null) GhostButton(s.quickIdeas, { start(quick = true) }, color = c.textMuted, modifier = Modifier.offset(x = 12.dp))
                    }
                } else {
                    Spacer(Modifier.height(4.dp))
                    SecondaryButton(s.demoTry, {
                        val p = container.engine.createDemoProject(s.demoTitle)
                        onOpenProject(p.id)
                    }, Modifier.fillMaxWidth(), icon = Icons.Rounded.PlayArrow)
                    Text(s.noKeyHint, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(top = 10.dp, start = 4.dp))
                }
            }
        }

        if (inProgress.isNotEmpty()) {
            item {
                Spacer(Modifier.height(32.dp))
                SectionLabel(s.continueSection, Modifier.padding(horizontal = 20.dp))
            }
            item {
                LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(inProgress, key = { it.id }) { p ->
                        ContinueCard(p, busy = ops[p.id]?.running == true) { onOpenProject(p.id) }
                    }
                }
            }
        }

        if (docs.isNotEmpty()) {
            item {
                Spacer(Modifier.height(28.dp))
                SectionLabel(s.recentDocs, Modifier.padding(start = 20.dp, end = 6.dp)) {
                    GhostButton(s.seeAll, onOpenLibrary, color = c.textMuted)
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
                        Box(Modifier.size(44.dp).clip(CircleShape).background(c.emberSoft), contentAlignment = Alignment.Center) {
                            Icon(Icons.Rounded.Person, null, tint = c.ember)
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(s.profileTipTitle, style = MaterialTheme.typography.titleSmall, color = c.text)
                            Spacer(Modifier.height(2.dp))
                            Text(s.profileTipBody, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                        }
                        Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, tint = c.textFaint, modifier = Modifier.size(18.dp))
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
    ProjectKind.ANY -> Icons.Rounded.AutoAwesome
}

fun kindEmoji(k: ProjectKind) = when (k) {
    ProjectKind.GAME -> "🎮"
    ProjectKind.APP -> "📱"
    ProjectKind.WEB -> "🌐"
    ProjectKind.ANY -> "✨"
}

@Composable
private fun ContinueCard(p: Project, busy: Boolean, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val progress = when (p.stage) {
        ProjectStage.INTERVIEW -> (p.turns.lastOrNull()?.progress ?: 0) / 100f * 0.5f
        ProjectStage.IDEAS -> 0.55f
        ProjectStage.DESIGN_INTERVIEW -> 0.6f + (p.design?.turns?.lastOrNull()?.progress ?: 0) / 100f * 0.3f
        ProjectStage.DOCUMENT -> 1f
    }
    EmberCard(Modifier.width(250.dp), onClick = onClick) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                KindBadge(p.kind, 32)
                Spacer(Modifier.width(8.dp))
                Tag(if (busy) s.working else s.stageLabel(p.stage), color = if (busy) c.ember else null, strong = busy)
            }
            Spacer(Modifier.height(12.dp))
            Text(p.title, style = MaterialTheme.typography.titleMedium, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(4.dp))
            Text(continueHint(p, s), style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.height(38.dp))
            Spacer(Modifier.height(12.dp))
            EmberProgress(progress, height = 4.dp)
        }
    }
}

private fun continueHint(p: Project, s: app.ember.ideas.ui.strings.Strings): String = when (p.stage) {
    ProjectStage.INTERVIEW -> p.currentTurn?.question?.title ?: s.answeredN(p.answeredCount)
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
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(c.surface2), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Description, null, tint = c.ember, modifier = Modifier.size(22.dp))
        }
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


/** 분야별 색과 아이콘으로 프로젝트를 구분하는 작은 배지. */
@Composable
fun KindBadge(kind: ProjectKind, sizeDp: Int) {
    val c = Ember.colors
    val tint = when (kind) {
        ProjectKind.GAME -> c.ember
        ProjectKind.APP -> c.info
        ProjectKind.WEB -> c.success
        ProjectKind.ANY -> c.gold
    }
    Box(Modifier.size(sizeDp.dp).clip(RoundedCornerShape((sizeDp / 3).dp)).background(tint.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
        Icon(kindIcon(kind), null, tint = tint, modifier = Modifier.size((sizeDp * 0.56f).dp))
    }
}
