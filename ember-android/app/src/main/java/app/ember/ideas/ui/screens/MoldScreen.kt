package app.ember.ideas.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.DepthMode
import app.ember.ideas.data.Mold
import app.ember.ideas.data.MoldCatalog
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStore
import app.ember.ideas.ui.components.EmberBackground
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.EmberTopBar
import app.ember.ideas.ui.components.ForgeTile
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.screens.project.EmberDialog
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape

/**
 * 거푸집 만들기·고치기. 갈래마다 하나씩 미리 골라 두면 그 질문은 건너뛴다.
 * [moldId] 가 null 이면 새 거푸집.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MoldScreen(moldId: String?, onBack: () -> Unit, onStart: (String) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val existing = remember(moldId) { moldId?.let { container.molds.get(it) } }
    val cats = MoldCatalog.categories(s.isKorean)

    var name by rememberSaveable { mutableStateOf(existing?.name ?: "") }
    var picks by rememberSaveable { mutableStateOf(existing?.picks ?: emptyMap()) }
    var kind by rememberSaveable { mutableStateOf(existing?.kind) }
    var depth by rememberSaveable { mutableStateOf(existing?.depth) }
    var customFor by rememberSaveable { mutableStateOf<String?>(null) }
    var customText by rememberSaveable { mutableStateOf("") }
    var nameError by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    fun save(): String? {
        if (name.isBlank()) { nameError = true; return null }
        val id = existing?.id ?: ProjectStore.newId()
        val m = Mold(
            id = id, name = name.trim().take(30), picks = picks, depth = depth, kind = kind,
            createdAt = existing?.createdAt ?: System.currentTimeMillis(), usedCount = existing?.usedCount ?: 0,
        )
        container.molds.upsert(m)
        return id
    }

    EmberBackground {
        Column(Modifier.fillMaxSize().imePadding()) {
            EmberTopBar(s.moldTitle, onBack) {
                SecondaryButton(s.save, { if (save() != null) onBack() }, height = 44.dp, modifier = Modifier.padding(end = 12.dp))
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
                Text(s.moldName, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
                Spacer(Modifier.height(8.dp))
                EmberTextField(name, { name = it; nameError = false }, s.moldNamePlaceholder, singleLine = true, maxLength = 30, isError = nameError)
                if (nameError) Text(s.moldNeedsName, style = MaterialTheme.typography.bodySmall, color = c.danger, modifier = Modifier.padding(top = 6.dp))
                Spacer(Modifier.height(14.dp))

                // 몇 개의 질문을 건너뛰는지 크게 보여 준다.
                Row(
                    Modifier.fillMaxWidth().clip(EmberShape.panel).background(c.gold.copy(alpha = 0.10f)).border(1.dp, c.gold.copy(alpha = 0.5f), EmberShape.panel).padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val n = picks.size + (if (kind != null) 1 else 0)
                    Text("$n", style = MaterialTheme.typography.displayMedium, color = c.gold)
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(s.moldCountLine(n), style = MaterialTheme.typography.bodyMedium, color = c.text)
                        Text(s.moldCountBody, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                    }
                }

                Spacer(Modifier.height(22.dp))
                Text(s.whatToMake, style = MaterialTheme.typography.titleSmall, color = c.text)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(ProjectKind.GAME, ProjectKind.APP, ProjectKind.WEB, ProjectKind.ANY).forEach { k ->
                        ForgeTile(s.kindShort(k), kindIcon(k), kind == k, { kind = if (kind == k) null else k }, Modifier.weight(1f))
                    }
                }

                cats.forEach { cat ->
                    Spacer(Modifier.height(22.dp))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(cat.title, style = MaterialTheme.typography.titleSmall, color = c.text)
                        if (cat.hint.isNotBlank()) {
                            Spacer(Modifier.width(8.dp))
                            Text(cat.hint, style = MaterialTheme.typography.labelSmall, color = c.textFaint)
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    val cur = picks[cat.key]
                    val custom = cur != null && cur !in cat.options
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        cat.options.forEach { o ->
                            PickChip(o, cur == o) { picks = if (cur == o) picks - cat.key else picks + (cat.key to o) }
                        }
                        PickChip(if (custom) cur!! else s.moldCustom, custom || customFor == cat.key) {
                            if (custom) { picks = picks - cat.key } else { customFor = cat.key; customText = "" }
                        }
                    }
                    if (customFor == cat.key) {
                        Spacer(Modifier.height(8.dp))
                        EmberTextField(
                            customText, { customText = it }, s.moldCustomHint, singleLine = true, maxLength = 40,
                            keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = {
                                if (customText.isNotBlank()) picks = picks + (cat.key to customText.trim())
                                customFor = null
                            }),
                        )
                    }
                }

                Spacer(Modifier.height(22.dp))
                Text(s.depthTitle, style = MaterialTheme.typography.titleSmall, color = c.text)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    PickChip(s.depthDefault, depth == null) { depth = null }
                    DepthMode.entries.forEach { d -> PickChip(s.depthLabel(d), depth == d) { depth = d } }
                }
                if (existing != null) {
                    Spacer(Modifier.height(28.dp))
                    Text(
                        s.deleteMold, style = MaterialTheme.typography.labelLarge, color = c.danger,
                        modifier = Modifier.clip(EmberShape.chip).clickable(role = Role.Button) { confirmDelete = true }.padding(vertical = 10.dp),
                    )
                }
                Spacer(Modifier.height(24.dp))
            }
            Box(Modifier.fillMaxWidth().topFade(c.bg).navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                PrimaryButton(s.startWithMold, { save()?.let(onStart) }, Modifier.fillMaxWidth())
            }
        }
    }
    if (confirmDelete && existing != null) {
        EmberDialog(s.deleteMold, existing.name, s.delete, {
            confirmDelete = false
            container.molds.delete(existing.id)
            onBack()
        }, { confirmDelete = false }, danger = true)
    }
}

@Composable
private fun PickChip(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = Ember.colors
    Box(
        Modifier
            .clip(EmberShape.chip)
            .background(if (selected) c.gold.copy(alpha = 0.12f) else c.surface)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.gold else c.outline, EmberShape.chip)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .heightIn(min = 40.dp)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = MaterialTheme.typography.labelMedium.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium), color = if (selected) c.text else c.textMuted, maxLines = 1)
    }
}
