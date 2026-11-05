package app.ember.ideas.ui.screens.project

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.WarningAmber
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.Protocol
import app.ember.ideas.data.Project
import app.ember.ideas.ui.components.EmberCard
import app.ember.ideas.ui.components.ErrorPanel
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.IconCircleButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.components.Tag
import app.ember.ideas.ui.components.ThinkingIndicator
import app.ember.ideas.ui.markdown.MarkdownBlockView
import app.ember.ideas.ui.markdown.MarkdownParser
import app.ember.ideas.ui.markdown.MdBlock
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import kotlinx.coroutines.launch

@Composable
fun DocumentContent(
    project: Project,
    busy: Boolean,
    revising: Boolean,
    streamingText: String,
    error: AiError?,
    onRevise: () -> Unit,
    onHandoff: () -> Unit,
    onStop: () -> Unit,
    onRegenerate: () -> Unit,
    onRetry: () -> Unit,
    onFixKey: () -> Unit,
    onDismissError: () -> Unit,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val design = project.design
    val latest = design?.latest
    val showing = if (busy && streamingText.isNotEmpty()) streamingText else latest?.markdown.orEmpty()
    val blocks = remember(showing) { MarkdownParser.parse(showing) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    var follow by remember { mutableStateOf(true) }
    var summaryOpen by rememberSaveable { mutableStateOf(false) }

    val headerCount = 1
    val sectionIndices = remember(blocks) {
        blocks.mapIndexedNotNull { i, b -> if (b is MdBlock.Heading && b.level == 2) i to b.text else null }
    }

    // 스트리밍 중에는 사용자가 위로 올리기 전까지 끝을 따라간다.
    val atBottom by remember { derivedStateOf { !listState.canScrollForward } }
    LaunchedEffect(listState.isScrollInProgress) { if (listState.isScrollInProgress && busy) follow = atBottom }
    LaunchedEffect(blocks.size, busy) {
        if (busy && follow && blocks.isNotEmpty()) listState.scrollToItem(headerCount + blocks.size - 1, Int.MAX_VALUE / 4)
    }

    Column(Modifier.fillMaxSize()) {
        if (sectionIndices.isNotEmpty() && !busy) {
            LazyRow(
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(bottom = 8.dp),
            ) {
                itemsIndexed(sectionIndices) { n, (idx, title) ->
                    Text(
                        "${n + 1}. $title",
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(c.surface2)
                            .clickable { scope.launch { listState.animateScrollToItem(headerCount + idx) } }
                            .padding(horizontal = 14.dp, vertical = 9.dp),
                        style = MaterialTheme.typography.labelMedium,
                        color = c.textMuted,
                        maxLines = 1,
                    )
                }
            }
        }
        Box(Modifier.weight(1f)) {
            if (blocks.isEmpty() && busy) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    ThinkingIndicator(s.docThinkingLines, title = if (revising) s.revisingTitle else s.writingTitle, modifier = Modifier.padding(24.dp))
                }
            } else if (blocks.isEmpty() && error != null) {
                Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                    ErrorPanel(error, onRetry, onFixKey)
                }
            } else {
                LazyColumn(state = listState, contentPadding = PaddingValues(start = 22.dp, end = 22.dp, bottom = 40.dp)) {
                    item {
                        Column {
                            if (latest != null && !busy) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Tag(s.versionLabel(design.versions.size), color = c.ember, strong = true)
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        listOfNotNull(s.relativeTime(latest.createdAt), latest.note.takeIf { it.isNotBlank() }?.let { "“$it”" }).joinToString(" · "),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = c.textFaint,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                        modifier = Modifier.weight(1f),
                                    )
                                }
                                if (!latest.complete) {
                                    Spacer(Modifier.height(12.dp))
                                    EmberCard(Modifier.fillMaxWidth()) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Rounded.WarningAmber, null, tint = c.gold)
                                            Spacer(Modifier.width(10.dp))
                                            Text(s.incompleteDoc, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.weight(1f))
                                            GhostButton(s.regenerate, onRegenerate, icon = Icons.Rounded.Refresh)
                                        }
                                    }
                                }
                            }
                            if (busy) {
                                Row(
                                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(c.emberSoft).padding(horizontal = 14.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    CircularProgressIndicator(Modifier.size(16.dp), color = c.ember, strokeWidth = 2.dp)
                                    Spacer(Modifier.width(10.dp))
                                    Text(
                                        (if (revising) s.revisingTitle else s.writingTitle) + " · " + s.charCount(streamingText.length),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = c.text,
                                        modifier = Modifier.weight(1f),
                                    )
                                    IconCircleButton(Icons.Rounded.Stop, s.stop, onStop, filled = false, tint = c.textMuted)
                                }
                            }
                            if (error != null && blocks.isNotEmpty()) {
                                Spacer(Modifier.height(12.dp))
                                ErrorPanel(error, onRetry, onFixKey, onDismiss = onDismissError)
                            }
                            if (design != null && design.readySummary.isNotBlank() && !busy) {
                                Spacer(Modifier.height(12.dp))
                                EmberCard(Modifier.fillMaxWidth(), onClick = { summaryOpen = !summaryOpen }, padding = PaddingValues(14.dp)) {
                                    Column {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Rounded.Checklist, null, tint = c.success, modifier = Modifier.size(20.dp))
                                            Spacer(Modifier.width(10.dp))
                                            Text(s.decisionsTitle, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f))
                                            Icon(if (summaryOpen) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = c.textMuted)
                                        }
                                        AnimatedVisibility(summaryOpen) {
                                            Column(Modifier.padding(top = 8.dp)) {
                                                MarkdownParser.parse(design.readySummary).forEach { MarkdownBlockView(it) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    itemsIndexed(blocks) { _, b -> MarkdownBlockView(b) }
                    if (busy) {
                        item {
                            Box(Modifier.padding(top = 8.dp).size(10.dp).clip(CircleShape).background(c.ember))
                        }
                    }
                }
                androidx.compose.animation.AnimatedVisibility(
                    busy && !follow,
                    enter = fadeIn(),
                    exit = fadeOut(),
                    modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp),
                ) {
                    SecondaryButton(s.followWriting, { follow = true; scope.launch { listState.scrollToItem(headerCount + blocks.size - 1, Int.MAX_VALUE / 4) } }, icon = Icons.Rounded.KeyboardArrowDown, height = 44.dp)
                }
            }
        }
        if (!busy && latest != null) {
            Row(
                Modifier.fillMaxWidth().background(c.bg).navigationBarsPadding().padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                SecondaryButton(s.revise, onRevise, Modifier.weight(1f), icon = Icons.Rounded.Tune)
                PrimaryButton(s.continueInClaude, onHandoff, Modifier.weight(1.3f), icon = Icons.AutoMirrored.Rounded.Send, height = 52.dp)
            }
        }
    }
}

/** 문서 제목을 뽑되, 없으면 아이디어 제목을 쓴다. */
fun documentTitleOf(project: Project): String =
    project.design?.latest?.markdown?.let { Protocol.documentTitle(it) } ?: project.selectedIdea?.title ?: project.title
