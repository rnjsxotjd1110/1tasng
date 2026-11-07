package app.ember.ideas.ui.screens

import androidx.compose.foundation.combinedClickable
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.DriveFileRenameOutline
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.Idea
import app.ember.ideas.data.Memo
import app.ember.ideas.data.Mold
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectStore
import app.ember.ideas.ui.components.EmptyState
import app.ember.ideas.ui.components.ForgeIcons
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.components.UnderlineTab
import app.ember.ideas.ui.screens.project.EmberSheet
import app.ember.ideas.ui.screens.project.SheetTitle
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape
import kotlinx.coroutines.launch

/**
 * 원석함: 떠오른 생각(메모), 찜한 아이디어, 거푸집을 한곳에 모아 둔다.
 */
@Composable
fun OreBoxScreen(
    onOpenProject: (String) -> Unit,
    onForgeMemo: (Memo) -> Unit,
    onOpenMold: (String?) -> Unit,
    onMemoDeleted: (Memo) -> Unit,
    initialTab: Int = 0,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val memos by container.memos.items.collectAsState()
    val molds by container.molds.items.collectAsState()
    val projects by container.store.projects.collectAsState()
    var tab by rememberSaveable { mutableStateOf(initialTab) }
    var tag by rememberSaveable { mutableStateOf<String?>(null) }
    var editing by remember { mutableStateOf<Memo?>(null) }

    val saved: List<Pair<Project, Idea>> = projects.flatMap { p -> p.savedIdeaIds.mapNotNull { id -> p.idea(id)?.let { p to it } } }
    // 찜한 아이디어를 꾹 눌러 여러 개 고른 것("프로젝트id|아이디어id").
    var picked by rememberSaveable { mutableStateOf(listOf<String>()) }
    var confirmDelete by remember { mutableStateOf(false) }
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    val ctx = LocalContext.current
    fun togglePick(k: String) { picked = if (k in picked) picked - k else picked + k }
    androidx.activity.compose.BackHandler(picked.isNotEmpty()) { picked = emptyList() }
    androidx.compose.runtime.LaunchedEffect(tab) { if (tab != 1) picked = emptyList() }
    val tags = memos.flatMap { it.tags }.groupingBy { it }.eachCount().entries.sortedByDescending { it.value }.map { it.key }.take(12)
    val shown = memos.filter { tag == null || tag in it.tags }.sortedWith(compareByDescending<Memo> { it.pinned }.thenByDescending { it.updatedAt })

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
        item {
            Column(Modifier.statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 18.dp)) {
                Text(s.oreBoxTitle, style = MaterialTheme.typography.headlineLarge, color = c.text)
                Text(s.oreBoxSub, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.padding(top = 4.dp))
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    OreTab(s.memosTab(memos.size), tab == 0) { tab = 0 }
                    OreTab(s.savedTab(saved.size), tab == 1) { tab = 1 }
                    OreTab(s.moldsTab(molds.size), tab == 2) { tab = 2 }
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline.copy(alpha = 0.6f)))
            }
        }
        when (tab) {
            0 -> {
                item {
                    Box(Modifier.padding(horizontal = 20.dp, vertical = 14.dp)) {
                        MemoComposer(editing = editing, onDone = { editing = null })
                    }
                }
                if (tags.isNotEmpty()) item {
                    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        TagChip(s.allTags, tag == null) { tag = null }
                        tags.forEach { t -> TagChip("#$t", tag == t) { tag = if (tag == t) null else t } }
                    }
                    Spacer(Modifier.height(10.dp))
                }
                if (memos.isEmpty()) item {
                    EmptyState(ForgeIcons.Ore, s.memoEmptyTitle, s.memoEmptyBody)
                }
                items(shown, key = { it.id }) { m ->
                    val ideas = m.projectIds.sumOf { id -> projects.firstOrNull { it.id == id }?.allIdeas?.size ?: 0 }
                    MemoRow(
                        m, ideas,
                        onForge = { onForgeMemo(m) },
                        onPin = { container.memos.update(m.id) { it.copy(pinned = !it.pinned) } },
                        onEdit = { editing = m },
                        onDelete = { container.memos.delete(m.id)?.let(onMemoDeleted) },
                    )
                }
            }
            1 -> {
                if (saved.isEmpty()) item { EmptyState(Icons.Rounded.Favorite, s.savedEmptyTitle, s.savedEmptyBody) }
                if (picked.isNotEmpty()) item {
                    Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(s.selectedN(picked.size), style = MaterialTheme.typography.titleMedium, color = c.text, modifier = Modifier.weight(1f))
                        GhostButton(s.selectAll, { picked = saved.map { it.first.id + "|" + it.second.id } }, color = c.textMuted)
                        GhostButton(s.cancel, { picked = emptyList() }, color = c.textMuted)
                    }
                    Box(Modifier.padding(horizontal = 20.dp, vertical = 6.dp)) {
                        app.ember.ideas.ui.screens.project.DangerButton(s.delete + " " + picked.size, { confirmDelete = true }, Modifier.fillMaxWidth())
                    }
                } else if (saved.size >= 2) item {
                    Text(s.longPressHint, style = MaterialTheme.typography.labelSmall, color = c.textFaint, modifier = Modifier.padding(start = 20.dp, top = 10.dp))
                }
                items(saved, key = { it.first.id + it.second.id }) { (p, idea) ->
                    val key = p.id + "|" + idea.id
                    SavedIdeaRow(
                        p, idea, selecting = picked.isNotEmpty(), selected = key in picked,
                        onClick = { if (picked.isNotEmpty()) togglePick(key) else onOpenProject(p.id) },
                        onLongClick = {
                            haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                            togglePick(key)
                        },
                    )
                }
            }
            else -> {
                if (molds.isEmpty()) item {
                    EmptyState(ForgeIcons.Mold, s.moldsEmptyTitle, s.moldsEmptyBody) {
                        PrimaryButton(s.newMold, { onOpenMold(null) })
                    }
                } else {
                    items(molds, key = { it.id }) { m -> MoldRow(m) { onOpenMold(m.id) } }
                    item {
                        Box(Modifier.padding(20.dp)) { SecondaryButton(s.newMold, { onOpenMold(null) }, Modifier.fillMaxWidth()) }
                    }
                }
            }
        }
    }
    if (confirmDelete) {
        val byProject = picked.groupBy({ it.substringBefore('|') }, { it.substringAfter('|') })
        val withDesign = byProject.entries.sumOf { (pid, ids) -> val p = projects.firstOrNull { it.id == pid }; ids.count { p?.designFor(it) != null } }
        app.ember.ideas.ui.screens.project.EmberDialog(
            s.deleteIdeasTitle(picked.size),
            s.deleteIdeasBody + if (withDesign > 0) "\n" + s.deleteIdeasDesignNote(withDesign) else "",
            s.delete,
            {
                confirmDelete = false
                val n = byProject.entries.sumOf { (pid, ids) -> container.engine.deleteIdeas(pid, ids.toSet()) }
                android.widget.Toast.makeText(ctx, if (n > 0) s.ideasDeleted(n) else s.busyCantDelete, android.widget.Toast.LENGTH_SHORT).show()
                picked = emptyList()
            },
            { confirmDelete = false },
            danger = true,
        )
    }
}

/** 글자 폭만큼만 차지하는 밑줄 탭. */
@Composable
private fun OreTab(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = Ember.colors
    Column(
        Modifier.width(androidx.compose.foundation.layout.IntrinsicSize.Max).clickable(role = Role.Tab, onClick = onClick),
    ) {
        Text(
            text,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium),
            color = if (selected) c.text else c.textMuted, maxLines = 1,
            modifier = Modifier.padding(vertical = 12.dp),
        )
        Box(Modifier.fillMaxWidth().height(2.dp).background(if (selected) c.ember else androidx.compose.ui.graphics.Color.Transparent))
    }
}

@Composable
private fun TagChip(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = Ember.colors
    Box(
        Modifier
            .clip(EmberShape.chip)
            .background(if (selected) c.emberSoft else c.bg)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.ember else c.outline, EmberShape.chip)
            .clickable(role = Role.Checkbox, onClick = onClick)
            .heightIn(min = 36.dp)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = MaterialTheme.typography.labelMedium.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium), color = if (selected) c.text else c.textMuted, maxLines = 1)
    }
}

/**
 * 원석 적는 칸. 글·말·사진으로 적고 '담기'로 원석함에 넣는다. [editing] 이 있으면 그 원석을 고친다.
 */
@Composable
fun MemoComposer(editing: Memo? = null, autoFocus: Boolean = false, onDone: () -> Unit = {}) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val scope = rememberCoroutineScope()
    var text by rememberSaveable(editing?.id) { mutableStateOf(editing?.text ?: "") }
    var image by rememberSaveable(editing?.id) { mutableStateOf(editing?.imagePath) }
    val focus = remember { androidx.compose.ui.focus.FocusRequester() }

    val voice = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        val said = r.data?.getStringArrayListExtra(android.speech.RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        if (!said.isNullOrBlank()) text = (if (text.isBlank()) said else text.trimEnd() + " " + said).take(1000)
    }
    val photo = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch {
            val path = container.images.import(uri)
            if (path == null) android.widget.Toast.makeText(ctx, s.imageFailed, android.widget.Toast.LENGTH_SHORT).show() else image = path
        }
    }
    androidx.compose.runtime.LaunchedEffect(editing?.id, autoFocus) { if (editing != null || autoFocus) runCatching { focus.requestFocus() } }

    fun save() {
        val t = text.trim()
        if (t.isEmpty() && image == null) return
        val now = System.currentTimeMillis()
        val tags = Memo.tagsIn(t)
        if (editing != null) {
            container.memos.update(editing.id) { it.copy(text = t, tags = tags, imagePath = image, updatedAt = now) }
        } else {
            container.memos.upsert(Memo(id = ProjectStore.newId(), text = t, tags = tags, imagePath = image, createdAt = now))
        }
        text = ""
        image = null
        onDone()
    }

    Column(
        Modifier.fillMaxWidth().clip(EmberShape.panel).background(c.surface).border(1.dp, if (editing != null) c.ember else c.outline, EmberShape.panel).padding(14.dp),
    ) {
        Text(s.memoPrompt, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
        Spacer(Modifier.height(10.dp))
        Box(Modifier.fillMaxWidth().heightIn(min = 52.dp)) {
            if (text.isEmpty()) Text(s.memoPlaceholder, style = MaterialTheme.typography.bodyLarge, color = c.textFaint)
            BasicTextField(
                value = text,
                onValueChange = { text = it.take(1000) },
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = c.text),
                cursorBrush = SolidColor(c.ember),
                modifier = Modifier.fillMaxWidth().focusRequester(focus),
            )
        }
        image?.let { path ->
            Spacer(Modifier.height(8.dp))
            ImageThumb(path, s.removeImage, size = 64.dp) { image = null }
        }
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            ToolIcon(ForgeIcons.Mic, s.memoVoice) {
                val intent = android.content.Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    .putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, if (s.isKorean) "ko-KR" else "en-US")
                    .putExtra(android.speech.RecognizerIntent.EXTRA_PROMPT, s.memoPrompt)
                runCatching { voice.launch(intent) }.onFailure {
                    android.widget.Toast.makeText(ctx, s.voiceUnavailable, android.widget.Toast.LENGTH_SHORT).show()
                }
            }
            ToolIcon(ForgeIcons.Image, s.memoPhoto) { photo.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            Box(
                Modifier.clip(EmberShape.tag).border(1.dp, c.outline, EmberShape.tag)
                    .clickable(role = Role.Button) { text = if (text.isEmpty() || text.endsWith(" ")) "$text#" else "$text #"; runCatching { focus.requestFocus() } }
                    .heightIn(min = 32.dp).padding(horizontal = 8.dp),
                contentAlignment = Alignment.Center,
            ) { Text(s.tagHint, style = MaterialTheme.typography.labelMedium, color = c.textMuted) }
            Spacer(Modifier.weight(1f))
            if (editing != null) GhostButton(s.cancel, { text = ""; image = null; onDone() }, color = c.textMuted)
            PrimaryButton(if (editing != null) s.save else s.memoSave, ::save, enabled = text.isNotBlank() || image != null, height = 44.dp)
        }
    }
}

@Composable
private fun ToolIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    val c = Ember.colors
    Box(
        Modifier.size(44.dp).clip(EmberShape.chip).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = c.textMuted, modifier = Modifier.size(20.dp)) }
}

@Composable
private fun MemoRow(m: Memo, ideaCount: Int, onForge: () -> Unit, onPin: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    var menu by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
        Row(Modifier.padding(top = 14.dp), verticalAlignment = Alignment.Top) {
            if (m.imagePath != null) {
                ImageThumb(m.imagePath, null, size = 56.dp)
                Spacer(Modifier.width(12.dp))
            }
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (m.pinned) {
                        Icon(ForgeIcons.Pin, null, tint = c.gold, modifier = Modifier.size(12.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(s.pinned, style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold), color = c.gold)
                        Spacer(Modifier.width(6.dp))
                    }
                    Text(
                        listOf(s.relativeTime(m.updatedAt)).plus(if (m.imagePath != null && m.text.isBlank()) listOf(s.photoMemo) else emptyList()).joinToString("  ") +
                            m.tags.joinToString("") { "  #$it" },
                        style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.height(4.dp))
                Text(m.text.ifBlank { s.photoMemo }, style = MaterialTheme.typography.bodyLarge, color = c.text, maxLines = 4, overflow = TextOverflow.Ellipsis)
            }
            Box {
                Box(
                    Modifier.size(40.dp).clip(EmberShape.chip).clickable(role = Role.Button) { menu = true }.semantics { contentDescription = s.more },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Rounded.MoreVert, null, tint = c.textFaint, modifier = Modifier.size(18.dp)) }
                DropdownMenu(menu, { menu = false }, containerColor = c.surface2) {
                    MenuLine(if (m.pinned) s.unpin else s.pin, Icons.Rounded.PushPin) { menu = false; onPin() }
                    MenuLine(s.editShort, Icons.Rounded.DriveFileRenameOutline) { menu = false; onEdit() }
                    MenuLine(s.delete, Icons.Rounded.Delete, danger = true) { menu = false; onDelete() }
                }
            }
        }
        Row(Modifier.padding(top = 8.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.clip(EmberShape.chip).border(1.dp, c.ember, EmberShape.chip).clickable(role = Role.Button, onClick = onForge)
                    .heightIn(min = 40.dp).padding(horizontal = 12.dp),
                contentAlignment = Alignment.Center,
            ) { Text(s.forgeThisOre, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.ember) }
            if (ideaCount > 0) {
                Spacer(Modifier.width(10.dp))
                Text(s.ledToIdeas(ideaCount), style = MaterialTheme.typography.labelSmall, color = c.textMuted)
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline.copy(alpha = 0.6f)))
    }
}

@Composable
private fun MenuLine(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, danger: Boolean = false, onClick: () -> Unit) {
    val c = Ember.colors
    DropdownMenuItem(
        text = { Text(text, style = MaterialTheme.typography.bodyMedium, color = if (danger) c.danger else c.text) },
        leadingIcon = { Icon(icon, null, tint = if (danger) c.danger else c.textMuted, modifier = Modifier.size(18.dp)) },
        onClick = onClick,
    )
}

@Composable
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
private fun SavedIdeaRow(p: Project, idea: Idea, selecting: Boolean, selected: Boolean, onClick: () -> Unit, onLongClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Column(
        Modifier.fillMaxWidth().background(if (selected) c.emberSoft else androidx.compose.ui.graphics.Color.Transparent)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick).padding(horizontal = 20.dp),
    ) {
        Row(Modifier.padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            if (selecting) {
                app.ember.ideas.ui.components.SelectMark(selected, multi = true)
                Spacer(Modifier.width(12.dp))
            }
            Box(Modifier.width(3.dp).height(44.dp).background(c.ember))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(idea.title, style = MaterialTheme.typography.titleMedium, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                Text(idea.logline, style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(4.dp))
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val d = idea.difficulty.coerceIn(1, 5)
                    Text(
                        s.difficultyEmoji(d) + " " + s.difficultyName(d),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                        color = app.ember.ideas.ui.screens.project.difficultyColor(d),
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(s.fromProject(p.title), style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline.copy(alpha = 0.6f)))
    }
}

@Composable
private fun MoldRow(m: Mold, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 20.dp)) {
        Row(Modifier.padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.width(3.dp).height(40.dp).background(c.gold))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(m.name, style = MaterialTheme.typography.titleMedium, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                Text(m.picks.values.joinToString(", "), style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Spacer(Modifier.width(10.dp))
            Column(horizontalAlignment = Alignment.End) {
                Text(s.moldSkips(m.picks.size), style = MaterialTheme.typography.labelSmall, color = c.gold)
                if (m.usedCount > 0) Text(s.usedTimes(m.usedCount), style = MaterialTheme.typography.labelSmall, color = c.textFaint)
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline.copy(alpha = 0.6f)))
    }
}

/** 화로 오른쪽 위 버튼: 어느 화면에서든 원석 하나를 바로 적는다. */
@Composable
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
fun QuickMemoSheet(onDismiss: () -> Unit) {
    val s = LocalStrings.current
    EmberSheet(onDismiss) {
        SheetTitle(s.memoQuick, onClose = onDismiss)
        Box(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
            MemoComposer(autoFocus = true, onDone = onDismiss)
        }
        Spacer(Modifier.height(12.dp))
    }
}

/** 원석함에서 원석 하나를 골라 화로로 꺼낸다. */
@Composable
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
fun MemoPickerSheet(memos: List<Memo>, onDismiss: () -> Unit, onPick: (Memo) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberSheet(onDismiss) {
        SheetTitle(s.fromOreBox, onClose = onDismiss)
        LazyColumn(Modifier.fillMaxWidth().heightIn(max = 520.dp)) {
            items(memos.sortedWith(compareByDescending<Memo> { it.pinned }.thenByDescending { it.updatedAt }), key = { it.id }) { m ->
                Row(
                    Modifier.fillMaxWidth().clickable { onPick(m) }.padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(ForgeIcons.OreSimple, null, tint = if (m.pinned) c.gold else c.textFaint, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(m.text.ifBlank { s.photoMemo }, style = MaterialTheme.typography.bodyMedium, color = c.text, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        Text(s.relativeTime(m.updatedAt) + m.tags.joinToString("") { "  #$it" }, style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1)
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}
