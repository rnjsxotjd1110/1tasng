package app.ember.ideas.ui.screens

import android.widget.Toast
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AddCircleOutline
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.FileDownload
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.RestartAlt
import androidx.compose.material.icons.rounded.Vibration
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import app.ember.ideas.BuildConfig
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.container
import app.ember.ideas.data.DevProfile
import app.ember.ideas.data.LanguageMode
import app.ember.ideas.data.SampleProject
import app.ember.ideas.data.ThemeMode
import app.ember.ideas.handoff.Handoff
import app.ember.ideas.ui.components.EmberChip
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.EmberTopBar
import app.ember.ideas.ui.components.NavRow
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.ToggleRow
import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.components.EmberBackground
import app.ember.ideas.ui.screens.project.ChoiceRow
import app.ember.ideas.ui.screens.project.EmberDialog
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import java.io.File

@Composable
fun SettingsScreen(onOpenKey: () -> Unit, onOpenProfile: () -> Unit, onOpenAbout: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val settings by container.settings.settings.collectAsState()
    var dialog by remember { mutableStateOf<String?>(null) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(20.dp))
        Text(s.settingsTitle, style = MaterialTheme.typography.headlineLarge, color = c.text, modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(12.dp))

        Group(s.groupClaude) {
            NavRow(s.apiKey, if (settings.hasKey) settings.keyHint.takeLast(8) else s.notConnected, onOpenKey, icon = Icons.Rounded.Key)
            NavRow(s.model, s.modelShort(settings.model), { dialog = "model" }, icon = Icons.Rounded.Psychology, body = s.modelSetCost(s.costApprox(app.ember.ideas.ai.CostEstimate.fullSet(settings.model))))
            ToggleRow(s.deepThinking, s.deepThinkingBody, settings.deepThinking, { container.settings.setDeepThinking(it) }, icon = Icons.Rounded.Bolt)
        }
        Group(s.groupPersonal) {
            NavRow(s.devProfile, if (settings.profile.isEmpty()) s.notSet else s.profileSummary(settings.profile.experience, settings.profile.tools), onOpenProfile, icon = Icons.Rounded.Person, body = s.devProfileBody)
            NavRow(s.language, s.languageName(settings.language), { dialog = "language" }, icon = Icons.Rounded.Language)
            NavRow(s.theme, s.themeName(settings.theme), { dialog = "theme" }, icon = Icons.Rounded.DarkMode)
            ToggleRow(s.haptics, null, settings.haptics, { container.settings.setHaptics(it) }, icon = Icons.Rounded.Vibration)
        }
        Group(s.groupUsage) {
            val u = settings.totalUsage
            Column(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 6.dp)) {
                Row(Modifier.fillMaxWidth()) {
                    UsageStat(s.usageRequests, u.requests.toString(), Modifier.weight(1f))
                    UsageStat(s.usageTokens, s.compactNumber(u.inputTokens + u.outputTokens + u.cacheReadTokens), Modifier.weight(1f))
                    UsageStat(s.usageCost, s.money(u.costUsd), Modifier.weight(1f))
                }
                Spacer(Modifier.height(8.dp))
                Text(s.usageNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
            }
            NavRow(s.resetUsage, null, { dialog = "resetUsage" }, icon = Icons.Rounded.RestartAlt)
        }
        Group(s.groupData) {
            NavRow(s.exportAll, null, chevron = false, onClick = {
                val dir = File(ctx.cacheDir, "exports").apply { mkdirs() }
                val f = File(dir, "ember-backup.json").apply { writeText(container.store.exportJson()) }
                val uri = androidx.core.content.FileProvider.getUriForFile(ctx, ctx.packageName + ".files", f)
                val send = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                    type = "application/json"
                    putExtra(android.content.Intent.EXTRA_STREAM, uri)
                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                ctx.startActivity(android.content.Intent.createChooser(send, s.exportAll))
            }, icon = Icons.Rounded.FileDownload, body = s.exportAllBody)
            NavRow(s.addSample, null, {
                container.store.upsert(SampleProject.create(ctx).copy(updatedAt = System.currentTimeMillis()))
                Toast.makeText(ctx, s.sampleAdded, Toast.LENGTH_SHORT).show()
            }, icon = Icons.Rounded.AddCircleOutline)
            NavRow(s.deleteAll, null, { dialog = "deleteAll" }, icon = Icons.Rounded.DeleteForever, danger = true)
        }
        Group(s.groupAbout) {
            NavRow(s.about, "v${BuildConfig.VERSION_NAME}", onOpenAbout, icon = Icons.Rounded.Info)
            Text(s.privacyNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp))
        }
        Spacer(Modifier.height(64.dp))
    }

    when (dialog) {
        "model" -> EmberDialog(s.model, null, s.close, { dialog = null }, { dialog = null }, content = {
            Column {
                ClaudeModel.entries.forEach { m ->
                    ChoiceRow(s.modelName(m), s.modelBody(m) + "\n" + s.modelSetCost(s.costApprox(app.ember.ideas.ai.CostEstimate.fullSet(m))), settings.model == m) { container.settings.setModel(m); dialog = null }
                    Spacer(Modifier.height(8.dp))
                }
            }
        })
        "language" -> EmberDialog(s.language, s.languageBody, s.close, { dialog = null }, { dialog = null }, content = {
            Column {
                LanguageMode.entries.forEach { l ->
                    ChoiceRow(s.languageName(l), "", settings.language == l) { container.settings.setLanguage(l); dialog = null }
                    Spacer(Modifier.height(8.dp))
                }
            }
        })
        "theme" -> EmberDialog(s.theme, null, s.close, { dialog = null }, { dialog = null }, content = {
            Column {
                ThemeMode.entries.forEach { t ->
                    ChoiceRow(s.themeName(t), "", settings.theme == t) { container.settings.setTheme(t); dialog = null }
                    Spacer(Modifier.height(8.dp))
                }
            }
        })
        "resetUsage" -> EmberDialog(s.resetUsage, s.resetUsageBody, s.reset, { container.settings.resetUsage(); dialog = null }, { dialog = null })
        "deleteAll" -> EmberDialog(s.deleteAll, s.deleteAllBody, s.delete, {
            container.store.projects.value.forEach { container.engine.cancel(it.id) }
            container.store.deleteAll()
            dialog = null
            Toast.makeText(ctx, s.deletedAll, Toast.LENGTH_SHORT).show()
        }, { dialog = null }, danger = true)
    }
    @Suppress("UNUSED_VARIABLE") val unused = Handoff.CLAUDE_PACKAGE
}

@Composable
private fun Group(title: String, content: @Composable ColumnScope.() -> Unit) {
    val c = Ember.colors
    Spacer(Modifier.height(18.dp))
    Text(title, style = MaterialTheme.typography.labelLarge, color = c.ember, modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp))
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(c.surface).padding(horizontal = 12.dp, vertical = 6.dp),
        content = content,
    )
}

@Composable
private fun UsageStat(label: String, value: String, modifier: Modifier = Modifier) {
    val c = Ember.colors
    Column(modifier) {
        Text(value, style = MaterialTheme.typography.titleLarge, color = c.text)
        Text(label, style = MaterialTheme.typography.labelSmall, color = c.textMuted)
    }
}

// ------------------------------------------------------------------ 개발자 프로필

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ProfileScreen(onBack: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val initial = remember { container.settings.settings.value.profile }
    var experience by rememberSaveable { mutableStateOf(initial.experience) }
    var tools by rememberSaveable { mutableStateOf(initial.tools) }
    var team by rememberSaveable { mutableStateOf(initial.team) }
    var notes by rememberSaveable { mutableStateOf(initial.notes) }
    var customTool by rememberSaveable { mutableStateOf("") }

    EmberBackground {
        Column(Modifier.fillMaxSize().imePadding()) {
            EmberTopBar(s.devProfile, onBack)
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
                Text(s.profileIntro, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
                Spacer(Modifier.height(24.dp))
                Label(s.profileExperience)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    s.experienceOptions.forEach { o -> EmberChip(o, experience == o, { experience = if (experience == o) "" else o }) }
                }
                Spacer(Modifier.height(24.dp))
                Label(s.profileTools)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    (s.toolOptions + tools.filter { it !in s.toolOptions }).forEach { o ->
                        EmberChip(o, o in tools, { tools = if (o in tools) tools - o else tools + o })
                    }
                }
                Spacer(Modifier.height(10.dp))
                EmberTextField(
                    customTool, { customTool = it }, s.addToolPlaceholder, singleLine = true, maxLength = 40,
                    keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = {
                        val t = customTool.trim()
                        if (t.isNotEmpty() && t !in tools) tools = tools + t
                        customTool = ""
                    }),
                )
                Spacer(Modifier.height(24.dp))
                Label(s.profileTeam)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    s.teamOptions.forEach { o -> EmberChip(o, team == o, { team = if (team == o) "" else o }) }
                }
                Spacer(Modifier.height(24.dp))
                Label(s.profileNotes)
                EmberTextField(notes, { notes = it }, s.profileNotesPlaceholder, minHeight = 96.dp, maxLength = 600)
                Spacer(Modifier.height(56.dp))
            }
            Column(Modifier.topFade(c.bg).navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                PrimaryButton(s.save, {
                    val extra = customTool.trim()
                    val finalTools = if (extra.isNotEmpty() && extra !in tools) tools + extra else tools
                    container.settings.setProfile(DevProfile(experience, finalTools, team, notes.trim()))
                    onBack()
                }, Modifier.fillMaxWidth())
            }
        }
    }
}

@Composable
private fun Label(t: String) {
    Text(t, style = MaterialTheme.typography.titleSmall, color = Ember.colors.text, modifier = Modifier.padding(bottom = 10.dp))
}

// ------------------------------------------------------------------ 정보

@Composable
fun AboutScreen(onBack: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    EmberBackground {
        Column(Modifier.fillMaxSize()) {
            EmberTopBar(s.about, onBack)
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
                Text("Ember", style = MaterialTheme.typography.displaySmall, color = c.text)
                Text("v${BuildConfig.VERSION_NAME}", style = MaterialTheme.typography.labelMedium, color = c.textFaint)
                Spacer(Modifier.height(12.dp))
                Text(s.aboutBody, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
                Spacer(Modifier.height(28.dp))
                Text(s.licenses, style = MaterialTheme.typography.titleMedium, color = c.text)
                Spacer(Modifier.height(10.dp))
                listOf(
                    "Pretendard" to "SIL Open Font License 1.1 · © 2021 Kil Hyung-jin",
                    "Anthropic Java SDK" to "MIT License · © Anthropic",
                    "Jetpack Compose, AndroidX" to "Apache License 2.0 · © The Android Open Source Project",
                    "Kotlin, kotlinx.coroutines, kotlinx.serialization" to "Apache License 2.0 · © JetBrains",
                    "OkHttp" to "Apache License 2.0 · © Square, Inc.",
                    "Jackson" to "Apache License 2.0 · © FasterXML",
                    "Material Icons" to "Apache License 2.0 · © Google",
                ).forEach { (name, lic) ->
                    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                        Text(name, style = MaterialTheme.typography.titleSmall, color = c.text)
                        Text(lic, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                    }
                }
                Spacer(Modifier.height(24.dp))
                Text(s.trademarkNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
                Spacer(Modifier.height(40.dp))
            }
        }
    }
}
