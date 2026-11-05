package app.ember.ideas.ui.screens.project

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.minimumInteractiveComponentSize
import app.ember.ideas.ui.components.EmberProgress
import app.ember.ideas.ui.components.topFade
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
import app.ember.ideas.ui.text.Text
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
    // 제목(H1)은 상단 바에 이미 보이므로 본문에서는 뺀다.
    val blocks = remember(showing) {
        MarkdownParser.parse(showing).let { b -> if (b.firstOrNull() is MdBlock.Heading && (b.first() as MdBlock.Heading).level == 1) b.drop(1) else b }
    }
    val listState = rememberLazyListState()
    val tocState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    var follow by remember { mutableStateOf(true) }
    var summaryOpen by rememberSaveable { mutableStateOf(false) }

    val headerCount = 1
    val sectionIndices = remember(blocks) {
        blocks.mapIndexedNotNull { i, b -> if (b is MdBlock.Heading && b.level == 2) i to b.text else null }
    }
    val expectedSections = 12
    val writtenSections = remember(streamingText) { streamingText.lineSequence().count { it.startsWith("## ") } }

    // 지금 보고 있는 섹션(목차 강조용)
    val currentSection by remember(sectionIndices) {
        derivedStateOf {
            val first = listState.firstVisibleItemIndex - headerCount
            sectionIndices.indexOfLast { it.first <= first + 1 }.coerceAtLeast(0)
        }
    }
    LaunchedEffect(currentSection) { if (sectionIndices.isNotEmpty()) tocState.animateScrollToItem((currentSection - 1).coerceAtLeast(0)) }

    // 스트리밍 중에는 사용자가 위로 올리기 전까지 끝을 따라간다.
    val atBottom by remember { derivedStateOf { !listState.canScrollForward } }
    LaunchedEffect(listState.isScrollInProgress) { if (listState.isScrollInProgress && busy) follow = atBottom }
    LaunchedEffect(blocks.size, busy) {
        if (busy && follow && blocks.isNotEmpty()) listState.scrollToItem(headerCount + blocks.size - 1, Int.MAX_VALUE / 4)
    }

    Column(Modifier.fillMaxSize()) {
        if (sectionIndices.isNotEmpty() && !busy) {
            Box(Modifier.fillMaxWidth().padding(bottom = 6.dp)) {
                LazyRow(
                    state = tocState,
                    contentPadding = PaddingValues(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    itemsIndexed(sectionIndices) { n, (idx, title) ->
                        val active = n == currentSection
                        Text(
                            "${n + 1}. $title",
                            modifier = Modifier
                                .minimumInteractiveComponentSize()
                                .clip(CircleShape)
                                .background(if (active) c.emberSoft else c.surface2)
                                .border(1.dp, if (active) c.ember else androidx.compose.ui.graphics.Color.Transparent, CircleShape)
                                .clickable { scope.launch { listState.animateScrollToItem(headerCount + idx) } }
                                .padding(horizontal = 14.dp, vertical = 9.dp),
                            style = MaterialTheme.typography.labelMedium,
                            color = if (active) c.text else c.textMuted,
                            maxLines = 1,
                        )
                    }
                }
                Box(
                    Modifier.align(Alignment.CenterEnd).size(width = 32.dp, height = 48.dp)
                        .background(androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(c.bg.copy(alpha = 0f), c.bg))),
                )
            }
        }
        Box(Modifier.weight(1f)) {
            if (blocks.isEmpty() && busy) {
                Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    ThinkingIndicator(s.docThinkingLines, title = if (revising) s.revisingTitle else s.writingTitle)
                    Spacer(Modifier.height(20.dp))
                    Text(s.writingNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    Spacer(Modifier.height(8.dp))
                    GhostButton(s.stop, onStop, icon = Icons.Rounded.Stop, color = c.textMuted)
                }
            } else if (blocks.isEmpty() && error != null) {
                Box(Modifier.fillMaxSize().padding(20.dp), contentAlignment = Alignment.Center) {
                    ErrorPanel(error, onRetry, onFixKey)
                }
            } else {
                LazyColumn(state = listState, contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 40.dp)) {
                    item {
                        Column {
                            if (latest != null && !busy) {
                                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 40.dp)) {
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
                                    val decided = design.turns.count { it.answer != null && it.answer.skipped.not() }
                                    if (design.readySummary.isNotBlank() || decided > 0) {
                                        GhostButton(
                                            s.decisionsCount(maxOf(decided, design.readySummary.lines().count { it.trimStart().startsWith("-") })),
                                            { summaryOpen = !summaryOpen },
                                            icon = if (summaryOpen) Icons.Rounded.ExpandLess else Icons.Rounded.Checklist,
                                            color = c.textMuted,
                                        )
                                    }
                                }
                                AnimatedVisibility(summaryOpen) {
                                    Column(Modifier.fillMaxWidth().padding(top = 6.dp).clip(RoundedCornerShape(16.dp)).background(c.surface).padding(horizontal = 14.dp, vertical = 6.dp)) {
                                        if (design.readySummary.isNotBlank()) {
                                            MarkdownParser.parse(design.readySummary).forEach { MarkdownBlockView(it) }
                                        } else {
                                            design.turns.filter { it.answer != null && !it.answer.skipped }.forEach {
                                                MarkdownBlockView(MdBlock.ListBlock(false, listOf(app.ember.ideas.ui.markdown.ListItem(0, "•", "**${it.question.title}** ${it.answerSummary()}"))))
                                            }
                                        }
                                    }
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
                                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(c.emberSoft).padding(start = 14.dp, end = 4.dp, top = 6.dp, bottom = 10.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        CircularProgressIndicator(Modifier.size(16.dp), color = c.ember, strokeWidth = 2.dp)
                                        Spacer(Modifier.width(10.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(if (revising) s.revisingTitle else s.writingTitle, style = MaterialTheme.typography.titleSmall, color = c.text)
                                            Text(
                                                s.sectionProgress(writtenSections.coerceAtMost(expectedSections), expectedSections) + " · " + s.charCount(streamingText.length),
                                                style = MaterialTheme.typography.labelMedium,
                                                color = c.textMuted,
                                            )
                                        }
                                        GhostButton(s.stop, onStop, icon = Icons.Rounded.Stop, color = c.text)
                                    }
                                    Spacer(Modifier.height(8.dp))
                                    Box(Modifier.padding(end = 10.dp)) { EmberProgress(writtenSections / expectedSections.toFloat(), height = 4.dp) }
                                    Spacer(Modifier.height(8.dp))
                                    Text(s.writingNote, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.padding(end = 10.dp))
                                }
                            }
                            if (error != null && blocks.isNotEmpty()) {
                                Spacer(Modifier.height(12.dp))
                                ErrorPanel(error, onRetry, onFixKey, onDismiss = onDismissError)
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
                Modifier.fillMaxWidth().topFade(c.bg).navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp),
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
