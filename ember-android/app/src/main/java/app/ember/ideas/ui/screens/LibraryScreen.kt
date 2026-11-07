package app.ember.ideas.ui.screens

import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.components.GhostButton
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DriveFileRenameOutline
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.minimumInteractiveComponentSize
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.ui.components.EmberChip
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.EmptyState
import app.ember.ideas.ui.components.IconCircleButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.Tag
import app.ember.ideas.ui.screens.project.EmberDialog
import app.ember.ideas.ui.screens.project.IdeaCard
import app.ember.ideas.ui.screens.project.RenameDialog
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.components.UnderlineTab

enum class LibraryFilter { ALL, EXPLORING, IDEAS, DOCS, FAVORITE }

@Composable
fun LibraryScreen(
    onOpenProject: (String) -> Unit,
    onStartNew: () -> Unit,
    onDeleted: (Project) -> Unit,
    /** 여러 프로젝트를 한 번에 지웠을 때(되돌리기 알림용). */
    onDeletedMany: (List<Project>) -> Unit = { list -> list.forEach(onDeleted) },
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val projects by container.store.projects.collectAsState()
    val ops by container.engine.ops.collectAsState()
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf(LibraryFilter.ALL) }
    var tab by rememberSaveable { mutableStateOf(0) }
    var renameTarget by remember { mutableStateOf<Project?>(null) }
    var deleteTarget by remember { mutableStateOf<Project?>(null) }
    // 꾹 눌러 고른 프로젝트 id. 하나라도 있으면 고르기 상태.
    var picked by rememberSaveable { mutableStateOf(listOf<String>()) }
    var confirmMany by remember { mutableStateOf(false) }
    val selecting = picked.isNotEmpty()
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    fun togglePick(id: String) { picked = if (id in picked) picked - id else picked + id }
    androidx.activity.compose.BackHandler(selecting) { picked = emptyList() }
    // 지워지거나 다른 탭으로 가면 고른 것을 정리한다.
    androidx.compose.runtime.LaunchedEffect(tab) { picked = emptyList() }
    androidx.compose.runtime.LaunchedEffect(projects) {
        picked = picked.filter { k ->
            if (tab == 0) projects.any { it.id == k }
            else k.contains('|') && projects.any { p -> p.id == k.substringBefore('|') && p.allIdeas.any { it.id == k.substringAfter('|') } }
        }
    }

    val q = query.trim().lowercase()
    val filtered = projects.sortedByDescending { it.favorite }.filter { p ->
        val matchFilter = when (filter) {
            LibraryFilter.ALL -> true
            LibraryFilter.FAVORITE -> p.favorite
            LibraryFilter.EXPLORING -> p.stage == ProjectStage.INTERVIEW
            LibraryFilter.IDEAS -> p.stage == ProjectStage.IDEAS
            LibraryFilter.DOCS -> p.design?.latest != null
        }
        val matchQuery = q.isEmpty() || p.title.lowercase().contains(q) || p.seed.lowercase().contains(q) ||
            p.allIdeas.any { it.title.lowercase().contains(q) || it.logline.lowercase().contains(q) }
        matchFilter && matchQuery
    }
    val savedIdeas = projects.flatMap { p -> p.allIdeas.filter { it.id in p.savedIdeaIds }.map { p to it } }
        .filter { (_, i) -> q.isEmpty() || i.title.lowercase().contains(q) || i.logline.lowercase().contains(q) }

    Column(Modifier.fillMaxSize()) {
    LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(bottom = 32.dp)) {
        item {
            Column(Modifier.statusBarsPadding().padding(horizontal = 20.dp)) {
                Spacer(Modifier.height(20.dp))
                Text(s.libraryTitle, style = MaterialTheme.typography.headlineLarge, color = c.text)
                Text(s.librarySub, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.padding(top = 4.dp))
                Spacer(Modifier.height(16.dp))
                EmberTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = s.searchPlaceholder,
                    singleLine = true,
                    leading = Icons.Rounded.Search,
                    maxLength = 80,
                    trailing = if (query.isNotEmpty()) ({ IconCircleButton(Icons.Rounded.Close, s.clear, { query = "" }, filled = false, tint = c.textMuted) }) else null,
                )
                Spacer(Modifier.height(14.dp))
                Row(Modifier.fillMaxWidth()) {
                    UnderlineTab(s.tabProjects(projects.size), tab == 0, Modifier.weight(1f)) { tab = 0 }
                    UnderlineTab(s.tabSavedIdeas(savedIdeas.size), tab == 1, Modifier.weight(1f)) { tab = 1 }
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline))
            }
        }
        if (tab == 0) {
            item {
                if (selecting) {
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(start = 20.dp, end = 8.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(s.selectedN(picked.size), style = MaterialTheme.typography.titleMedium, color = c.text, modifier = Modifier.weight(1f))
                        GhostButton(s.selectAll, { picked = filtered.map { it.id } }, color = c.textMuted)
                        GhostButton(s.cancel, { picked = emptyList() }, color = c.textMuted)
                    }
                } else {
                    LazyRow(contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(LibraryFilter.entries.filter { it != LibraryFilter.FAVORITE }) { f ->
                            EmberChip(s.filterLabel(f), filter == f, { filter = f })
                        }
                    }
                    if (filtered.size >= 2) {
                        Text(s.longPressProjectsHint, style = MaterialTheme.typography.labelSmall, color = c.textFaint, modifier = Modifier.padding(start = 20.dp, bottom = 4.dp))
                    }
                }
            }
            if (filtered.isEmpty()) {
                item {
                    if (projects.isEmpty()) {
                        EmptyState(Icons.Rounded.Inventory2, s.libraryEmptyTitle, s.libraryEmptyBody, Modifier.fillMaxWidth()) {
                            PrimaryButton(s.startNew, onStartNew)
                        }
                    } else {
                        EmptyState(Icons.Rounded.Search, s.noResultsTitle, s.noResultsBody, Modifier.fillMaxWidth())
                    }
                }
            }
            items(filtered, key = { it.id }) { p ->
                ProjectRow(
                    p,
                    busy = ops[p.id]?.running == true,
                    selecting = selecting,
                    selected = p.id in picked,
                    onLongClick = {
                        haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                        togglePick(p.id)
                    },
                    onClick = { if (selecting) togglePick(p.id) else onOpenProject(p.id) },
                    onRename = { renameTarget = p },
                    onFavorite = { container.engine.setFavorite(p.id, !p.favorite) },
                    onDelete = { deleteTarget = p },
                )
            }
        } else {
            if (savedIdeas.isEmpty()) {
                item { EmptyState(Icons.Rounded.Favorite, s.noSavedTitle, s.noSavedBody, Modifier.fillMaxWidth()) }
            }
            item {
                if (selecting) {
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(start = 20.dp, end = 8.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(s.selectedN(picked.size), style = MaterialTheme.typography.titleMedium, color = c.text, modifier = Modifier.weight(1f))
                        GhostButton(s.selectAll, { picked = savedIdeas.map { (p, i) -> p.id + "|" + i.id } }, color = c.textMuted)
                        GhostButton(s.cancel, { picked = emptyList() }, color = c.textMuted)
                    }
                } else if (savedIdeas.size >= 2) {
                    Text(s.longPressHint, style = MaterialTheme.typography.labelSmall, color = c.textFaint, modifier = Modifier.padding(start = 20.dp, top = 10.dp))
                }
            }
            items(savedIdeas, key = { (p, i) -> p.id + i.id }) { (p, idea) ->
                val key = p.id + "|" + idea.id
                Box(Modifier.padding(horizontal = 20.dp, vertical = 6.dp)) {
                    IdeaCard(
                        idea = idea,
                        saved = true,
                        chosen = p.design?.ideaId == idea.id,
                        onClick = { if (selecting) togglePick(key) else onOpenProject(p.id) },
                        onToggleSave = { container.engine.toggleSaved(p.id, idea.id) },
                        projectTitle = p.title,
                        selectionMode = selecting,
                        selected = key in picked,
                        onLongClick = {
                            haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                            togglePick(key)
                        },
                    )
                }
            }
        }
    }

    if (selecting) {
        Row(
            Modifier.fillMaxWidth().topFade(c.bg).padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            app.ember.ideas.ui.components.SecondaryButton(s.cancel, { picked = emptyList() }, Modifier.weight(1f))
            app.ember.ideas.ui.screens.project.DangerButton(s.delete + " " + picked.size, { confirmMany = true }, Modifier.weight(1f))
        }
    }
    }

    if (confirmMany && tab == 0) {
        EmberDialog(s.deleteProjectsTitle(picked.size), s.deleteProjectsBody, s.delete, {
            confirmMany = false
            val gone = picked.mapNotNull { container.engine.delete(it) }
            picked = emptyList()
            if (gone.isNotEmpty()) onDeletedMany(gone)
        }, { confirmMany = false }, danger = true)
    }
    if (confirmMany && tab == 1) {
        val ctx = LocalContext.current
        val byProject = picked.groupBy({ it.substringBefore('|') }, { it.substringAfter('|') })
        val withDesign = byProject.entries.sumOf { (pid, ids) -> val p = projects.firstOrNull { it.id == pid }; ids.count { p?.designFor(it) != null } }
        EmberDialog(
            s.deleteIdeasTitle(picked.size),
            s.deleteIdeasBody + if (withDesign > 0) "\n" + s.deleteIdeasDesignNote(withDesign) else "",
            s.delete,
            {
                confirmMany = false
                val n = byProject.entries.sumOf { (pid, ids) -> container.engine.deleteIdeas(pid, ids.toSet()) }
                android.widget.Toast.makeText(ctx, if (n > 0) s.ideasDeleted(n) else s.busyCantDelete, android.widget.Toast.LENGTH_SHORT).show()
                picked = emptyList()
            },
            { confirmMany = false },
            danger = true,
        )
    }
    renameTarget?.let { p ->
        RenameDialog(p.title, { renameTarget = null }) { container.engine.rename(p.id, it); renameTarget = null }
    }
    deleteTarget?.let { p ->
        EmberDialog(s.deleteTitle, s.deleteBody(p.title), s.delete, {
            deleteTarget = null
            container.engine.delete(p.id)?.let(onDeleted)
        }, { deleteTarget = null }, danger = true)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ProjectRow(
    p: Project, busy: Boolean, onClick: () -> Unit, onRename: () -> Unit, onFavorite: () -> Unit, onDelete: () -> Unit,
    selecting: Boolean = false, selected: Boolean = false, onLongClick: () -> Unit = {},
) {
    val s = LocalStrings.current
    val c = Ember.colors
    var menu by remember { mutableStateOf(false) }
    val subtitle = p.selectedIdea?.title?.takeIf { it != p.title } ?: p.seed.takeIf { it.isNotBlank() }
        ?: p.allIdeas.takeIf { it.isNotEmpty() }?.let { s.ideasCount(it.size) } ?: s.answeredN(p.answeredCount)
    Row(
        Modifier
            .fillMaxWidth()
            .background(if (selected) c.emberSoft else androidx.compose.ui.graphics.Color.Transparent)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(start = 20.dp, end = 8.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (selecting) {
            Box(Modifier.size(36.dp), contentAlignment = Alignment.Center) { app.ember.ideas.ui.components.SelectMark(selected, multi = true) }
        } else {
            KindBadge(p.kind, 36)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (p.favorite) {
                    Icon(Icons.Rounded.PushPin, s.pin, tint = c.gold, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(4.dp))
                }
                Text(p.title, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            }
            Spacer(Modifier.height(2.dp))
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(8.dp))
            app.ember.ideas.ui.components.HeatGauge(app.ember.ideas.ui.components.Heat.of(p), Modifier.width(150.dp), flowing = busy)
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Tag(if (busy) s.working else s.stageLabel(p.stage), color = if (busy) c.ember else stageColor(p.stage), strong = true)
                if (p.isSample) { Spacer(Modifier.width(6.dp)); Tag(s.sample, color = c.textMuted) }
                if (p.isDemo) { Spacer(Modifier.width(6.dp)); Tag("Demo", color = c.textMuted) }
                Spacer(Modifier.width(8.dp))
                Text(s.relativeTime(p.updatedAt), style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1)
            }
        }
        if (!selecting) Box {
            IconCircleButton(Icons.Rounded.MoreVert, s.moreActions, { menu = true }, filled = false, tint = c.textMuted)
            DropdownMenu(menu, { menu = false }, containerColor = c.surface2, offset = androidx.compose.ui.unit.DpOffset((-12).dp, 0.dp), shadowElevation = 8.dp, tonalElevation = 0.dp) {
                DropdownMenuItem({ Text(if (p.favorite) s.unpin else s.pin, color = c.text) }, { menu = false; onFavorite() }, leadingIcon = { Icon(Icons.Rounded.PushPin, null, tint = c.textMuted) })
                DropdownMenuItem({ Text(s.rename, color = c.text) }, { menu = false; onRename() }, leadingIcon = { Icon(Icons.Rounded.DriveFileRenameOutline, null, tint = c.textMuted) })
                DropdownMenuItem({ Text(s.delete, color = c.danger) }, { menu = false; onDelete() }, leadingIcon = { Icon(Icons.Rounded.Delete, null, tint = c.danger) })
            }
        }
    }
}

@Composable
fun stageColor(stage: ProjectStage) = when (stage) {
    ProjectStage.INTERVIEW -> Ember.colors.heat
    ProjectStage.IDEAS -> Ember.colors.gold
    ProjectStage.DESIGN_INTERVIEW -> Ember.colors.ember
    ProjectStage.DOCUMENT -> Ember.colors.steel
}


