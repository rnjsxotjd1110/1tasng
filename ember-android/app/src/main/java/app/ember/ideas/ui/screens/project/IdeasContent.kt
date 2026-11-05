package app.ember.ideas.ui.screens.project

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.QuestionAnswer
import androidx.compose.material.icons.rounded.TableChart
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import app.ember.ideas.ui.text.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.ai.AiError
import app.ember.ideas.data.Idea
import app.ember.ideas.data.IdeaBatch
import app.ember.ideas.data.Project
import app.ember.ideas.ui.components.EmberCard
import app.ember.ideas.ui.components.EmberChip
import app.ember.ideas.ui.components.ErrorPanel
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.components.Tag
import app.ember.ideas.ui.components.ThinkingIndicator
import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun IdeasContent(
    project: Project,
    busy: Boolean,
    error: AiError?,
    onOpenIdea: (Idea) -> Unit,
    onDesignIdea: (Idea) -> Unit,
    onCompare: () -> Unit,
    onToggleSave: (Idea) -> Unit,
    onMoreIdeas: () -> Unit,
    onMoreQuestions: () -> Unit,
    onOpenDocument: () -> Unit,
    onRetry: () -> Unit,
    onFixKey: () -> Unit,
    onDismissError: () -> Unit,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    var savedOnly by rememberSaveable { mutableStateOf(false) }
    val batches = project.ideaBatches.reversed()
    val listState = rememberLazyListState()
    val total = project.allIdeas.size

    // 새 아이디어 묶음이 오면 맨 위로 올린다.
    LaunchedEffect(project.ideaBatches.size) { if (project.ideaBatches.isNotEmpty()) listState.animateScrollToItem(0) }

    Column(Modifier.fillMaxSize()) {
        LazyColumn(Modifier.weight(1f), state = listState, contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 32.dp)) {
            item {
                Spacer(Modifier.height(8.dp))
                if (project.design?.latest != null) {
                    EmberCard(Modifier.fillMaxWidth(), onClick = onOpenDocument, highlight = true) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.Description, null, tint = c.ember)
                            Spacer(Modifier.width(12.dp))
                            Text(s.docReadyBanner, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f))
                            Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = c.textMuted, modifier = Modifier.size(20.dp))
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    EmberChip(s.allIdeas(total), !savedOnly, { savedOnly = false })
                    Spacer(Modifier.width(8.dp))
                    EmberChip(s.savedIdeas(project.savedIdeaIds.size), savedOnly, { savedOnly = true }, icon = Icons.Rounded.Favorite)
                    Spacer(Modifier.weight(1f))
                    if (total >= 2) GhostButton(s.compare, onCompare, icon = Icons.Rounded.TableChart, color = c.textMuted, modifier = Modifier.offset(x = 12.dp))
                }
                Spacer(Modifier.height(8.dp))
                AnimatedVisibility(busy, enter = fadeIn() + expandVertically()) {
                    EmberCard(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                        ThinkingIndicator(s.ideaThinkingLines, Modifier.fillMaxWidth(), title = s.ideaThinkingTitle)
                    }
                }
                if (error != null) {
                    Spacer(Modifier.height(8.dp))
                    ErrorPanel(error, onRetry, onFixKey, onDismiss = onDismissError)
                }
            }
            batches.forEachIndexed { bi, batch ->
                val list = if (savedOnly) batch.ideas.filter { it.id in project.savedIdeaIds } else batch.ideas
                if (list.isNotEmpty()) {
                    item(key = "batch_" + batch.id) { BatchHeader(batch, latest = bi == 0) }
                    items(list, key = { it.id }) { idea ->
                        IdeaCard(
                            idea = idea,
                            saved = idea.id in project.savedIdeaIds,
                            chosen = project.design?.ideaId == idea.id,
                            onClick = { onOpenIdea(idea) },
                            onToggleSave = { onToggleSave(idea) },
                            onDesign = if (busy) null else ({ onDesignIdea(idea) }),
                        )
                        Spacer(Modifier.height(12.dp))
                    }
                }
            }
            if (savedOnly && project.savedIdeaIds.isEmpty()) {
                item {
                    Text(s.noSavedIdeas, style = MaterialTheme.typography.bodyMedium, color = c.textMuted, modifier = Modifier.padding(vertical = 32.dp, horizontal = 8.dp))
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().topFade(c.bg).navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            SecondaryButton(s.moreQuestions, onMoreQuestions, Modifier.weight(1f), icon = Icons.Rounded.QuestionAnswer, enabled = !busy)
            SecondaryButton(s.moreIdeas, onMoreIdeas, Modifier.weight(1f), icon = Icons.Rounded.Add, enabled = !busy)
        }
    }
}

@Composable
private fun BatchHeader(batch: IdeaBatch, latest: Boolean) {
    val s = LocalStrings.current
    val c = Ember.colors
    Column(Modifier.padding(top = 18.dp, bottom = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                when {
                    batch.label.contains(" + ") -> s.combinedOf(batch.label)
                    batch.label.isNotBlank() -> s.variationOf(batch.label)
                    batch.fromExtraQuestions -> s.extraIdeasHeader
                    latest -> s.latestIdeas
                    else -> s.earlierIdeas
                },
                style = MaterialTheme.typography.titleMedium,
                color = c.text,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(s.relativeTime(batch.createdAt), style = MaterialTheme.typography.labelSmall, color = c.textFaint)
        }
        if (batch.intro.isNotBlank()) {
            Spacer(Modifier.height(4.dp))
            Text(batch.intro, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun IdeaCard(idea: Idea, saved: Boolean, chosen: Boolean, onClick: () -> Unit, onToggleSave: () -> Unit, projectTitle: String? = null, onDesign: (() -> Unit)? = null) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberCard(Modifier.fillMaxWidth().animateContentSize(), onClick = onClick, highlight = chosen, padding = PaddingValues(start = 16.dp, end = 4.dp, top = 12.dp, bottom = 8.dp)) {
        Column {
            if (projectTitle != null || chosen) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp, bottom = 6.dp)) {
                    if (chosen) { Tag(s.chosenIdea, color = c.ember, strong = true); Spacer(Modifier.width(8.dp)) }
                    if (projectTitle != null) Text(projectTitle, style = MaterialTheme.typography.labelSmall, color = c.textFaint, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(idea.title, style = MaterialTheme.typography.titleLarge, color = c.text, modifier = Modifier.weight(1f), maxLines = 2, overflow = TextOverflow.Ellipsis)
                HeartButton(saved, onToggleSave)
            }
            Column(Modifier.padding(end = 12.dp)) {
                Text(idea.logline, style = MaterialTheme.typography.bodyMedium, color = c.text.copy(alpha = 0.88f), maxLines = 3, overflow = TextOverflow.Ellipsis)
                if (idea.coreHook.isNotBlank()) {
                    Spacer(Modifier.height(8.dp))
                    // 핵심 재미는 왼쪽 선으로 본문과 구분한다.
                    Row(Modifier.height(IntrinsicSize.Min)) {
                        Box(Modifier.width(2.dp).fillMaxHeight().background(c.gold.copy(alpha = 0.8f)))
                        Spacer(Modifier.width(10.dp))
                        Text(idea.coreHook, style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                }
                Spacer(Modifier.height(10.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf(idea.genre.ifBlank { idea.category }, idea.scope, idea.devTime).filter { it.isNotBlank() }.forEach { Tag(it) }
                    Tag(s.difficulty(idea.difficulty), color = difficultyColor(idea.difficulty), strong = true)
                }
            }
            if (onDesign != null) {
                Row(Modifier.fillMaxWidth().padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                    GhostButton(s.details, onClick, color = c.textMuted, modifier = Modifier.offset(x = (-12).dp))
                    Spacer(Modifier.weight(1f))
                    GhostButton(s.designThisShort, onDesign, icon = Icons.AutoMirrored.Rounded.ArrowForward)
                }
            }
        }
    }
}

@Composable
fun difficultyColor(d: Int) = when {
    d <= 2 -> Ember.colors.success
    d == 3 -> Ember.colors.gold
    else -> Ember.colors.danger
}

@Composable
fun HeartButton(saved: Boolean, onToggle: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val haptic = LocalHapticFeedback.current
    val scale by animateFloatAsState(if (saved) 1f else 0.92f, spring(Spring.DampingRatioMediumBouncy), label = "heart")
    Box(
        Modifier
            .size(44.dp)
            .clip(CircleShape)
            .clickable {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                onToggle()
            }
            .semantics { contentDescription = if (saved) s.unsave else s.saveIdea },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            if (saved) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
            null,
            tint = if (saved) c.ember else c.textFaint,
            modifier = Modifier.size(24.dp).scale(scale),
        )
    }
}
