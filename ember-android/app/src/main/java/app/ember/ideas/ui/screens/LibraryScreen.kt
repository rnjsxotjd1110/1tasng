package app.ember.ideas.ui.screens

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

enum class LibraryFilter { ALL, EXPLORING, IDEAS, DOCS, FAVORITE }

@Composable
fun LibraryScreen(
    onOpenProject: (String) -> Unit,
    onStartNew: () -> Unit,
    onDeleted: (Project) -> Unit,
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

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
        item {
            Column(Modifier.statusBarsPadding().padding(horizontal = 20.dp)) {
                Spacer(Modifier.height(20.dp))
                Text(s.libraryTitle, style = MaterialTheme.typography.headlineLarge, color = c.text)
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
                LazyRow(contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(LibraryFilter.entries.filter { it != LibraryFilter.FAVORITE }) { f ->
                        EmberChip(s.filterLabel(f), filter == f, { filter = f })
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
                    onClick = { onOpenProject(p.id) },
                    onRename = { renameTarget = p },
                    onFavorite = { container.engine.setFavorite(p.id, !p.favorite) },
                    onDelete = { deleteTarget = p },
                )
            }
        } else {
            if (savedIdeas.isEmpty()) {
                item { EmptyState(Icons.Rounded.Favorite, s.noSavedTitle, s.noSavedBody, Modifier.fillMaxWidth()) }
            }
            items(savedIdeas, key = { (p, i) -> p.id + i.id }) { (p, idea) ->
                Box(Modifier.padding(horizontal = 20.dp, vertical = 6.dp)) {
                    IdeaCard(
                        idea = idea,
                        saved = true,
                        chosen = p.design?.ideaId == idea.id,
                        onClick = { onOpenProject(p.id) },
                        onToggleSave = { container.engine.toggleSaved(p.id, idea.id) },
                        projectTitle = p.title,
                    )
                }
            }
        }
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
private fun ProjectRow(p: Project, busy: Boolean, onClick: () -> Unit, onRename: () -> Unit, onFavorite: () -> Unit, onDelete: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    var menu by remember { mutableStateOf(false) }
    val subtitle = p.selectedIdea?.title?.takeIf { it != p.title } ?: p.seed.takeIf { it.isNotBlank() }
        ?: p.allIdeas.takeIf { it.isNotEmpty() }?.let { s.ideasCount(it.size) } ?: s.answeredN(p.answeredCount)
    Row(
        Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onClick, onLongClick = { menu = true })
            .padding(start = 20.dp, end = 8.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        KindBadge(p.kind, 36)
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
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Tag(if (busy) s.working else s.stageLabel(p.stage), color = if (busy) c.ember else stageColor(p.stage), strong = true)
                if (p.isSample) { Spacer(Modifier.width(6.dp)); Tag(s.sample, color = c.textMuted) }
                if (p.isDemo) { Spacer(Modifier.width(6.dp)); Tag("Demo", color = c.textMuted) }
                Spacer(Modifier.width(8.dp))
                Text(s.relativeTime(p.updatedAt), style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1)
            }
        }
        Box {
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
    ProjectStage.INTERVIEW -> Ember.colors.info
    ProjectStage.IDEAS -> Ember.colors.gold
    ProjectStage.DESIGN_INTERVIEW -> Ember.colors.ember
    ProjectStage.DOCUMENT -> Ember.colors.success
}


@Composable
private fun UnderlineTab(text: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Ember.colors
    Column(modifier.clickable(role = androidx.compose.ui.semantics.Role.Tab, onClick = onClick), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text, style = MaterialTheme.typography.titleSmall, color = if (selected) c.text else c.textMuted, modifier = Modifier.padding(vertical = 14.dp))
        Box(Modifier.fillMaxWidth(0.6f).height(3.dp).clip(RoundedCornerShape(2.dp)).background(if (selected) c.ember else androidx.compose.ui.graphics.Color.Transparent))
    }
}
