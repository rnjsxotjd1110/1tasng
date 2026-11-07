package app.ember.ideas.ui.screens

import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.rounded.Description
import kotlinx.coroutines.launch
import androidx.compose.material.icons.rounded.FileUpload
import androidx.compose.material.icons.rounded.CloudUpload
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.TravelExplore
import androidx.compose.material.icons.rounded.BugReport
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Email
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
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Memory
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
import androidx.compose.material.icons.rounded.Savings
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
    val importScope = androidx.compose.runtime.rememberCoroutineScope()
    val importer = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        // 큰 파일을 화면 스레드에서 읽으면 멈추므로 IO 스레드에서, 크기 상한을 두고 읽는다.
        importScope.launch {
            val n = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                runCatching {
                    ctx.contentResolver.openInputStream(uri)?.use { input ->
                        // readNBytes 는 Android 13 부터라 직접 읽는다.
                        val out = java.io.ByteArrayOutputStream()
                        val buf = ByteArray(64 * 1024)
                        var tooBig = false
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            out.write(buf, 0, n)
                            if (out.size() > MAX_IMPORT_BYTES) { tooBig = true; break }
                        }
                        if (tooBig) null else out.toByteArray().decodeToString()
                    }
                }.getOrNull()
            }?.let { container.store.importJson(it) }
            Toast.makeText(ctx, if (n == null) s.importFailed else s.imported(n), Toast.LENGTH_LONG).show()
        }
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(20.dp))
        Text(s.settingsTitle, style = MaterialTheme.typography.headlineLarge, color = c.text)
        Text(s.settingsSub, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.padding(top = 4.dp))
        Spacer(Modifier.height(12.dp))

        if (app.ember.ideas.BuildConfig.WORKBENCH_ENABLED) Group(s.benchSection) {
            app.ember.ideas.ui.screens.project.WorkbenchSettingsBlock()
        }
        Group(s.groupClaude) {
            NavRow(
                if (app.ember.ideas.account.ServerConfig.creditsEnabled) s.accessTitle else s.apiKey,
                when {
                    settings.usingCredits -> s.creditsAmount(settings.credits.coerceAtLeast(0))
                    settings.hasKey -> settings.keyHint.takeLast(8)
                    else -> s.notConnected
                },
                onOpenKey, icon = Icons.Rounded.Key,
            )
            NavRow(
                s.model, s.modelShort(settings.activeModel), { dialog = "model" }, icon = Icons.Rounded.Memory,
                body = if (settings.freeTier) s.freeTierNote
                else s.modelSetCost(s.estimate(app.ember.ideas.ai.CostEstimate.fullSet(settings.model), app.ember.ideas.ai.CostEstimate.fullSetCredits(settings.model))),
            )
            ToggleRow(s.deepThinking, s.deepThinkingBody, settings.deepThinking, { container.settings.setDeepThinking(it) }, icon = Icons.Rounded.HourglassTop)
            ToggleRow(s.webSearchSetting, s.webSearchBody(s.estimate(app.ember.ideas.ai.WEB_SEARCH_USD)), settings.webSearch, { container.settings.setWebSearch(it) }, icon = Icons.Rounded.TravelExplore)
            if (settings.model == app.ember.ideas.ai.ClaudeModel.OPUS) {
                ToggleRow(s.fastQuestionsSetting, s.fastQuestionsBody, settings.fastQuestions, { container.settings.setFastQuestions(it) }, icon = Icons.Rounded.Speed)
            }
        }
        Group(s.groupPersonal) {
            NavRow(
                s.githubConnect,
                if (settings.hasGithub) "@" + settings.githubUser else s.notConnected,
                { dialog = "github" }, icon = Icons.Rounded.CloudUpload,
            )
            NavRow(s.devProfile, if (settings.profile.isEmpty()) s.notSet else s.profileSummary(settings.profile.experience, settings.profile.tools), onOpenProfile, icon = Icons.Rounded.Person, body = s.devProfileBody)
            NavRow(s.language, s.languageName(settings.language), { dialog = "language" }, icon = Icons.Rounded.Language)
            NavRow(s.theme, s.themeName(settings.theme), { dialog = "theme" }, icon = Icons.Rounded.DarkMode)
            ToggleRow(s.haptics, null, settings.haptics, { container.settings.setHaptics(it) }, icon = Icons.Rounded.Vibration)
            ToggleRow(s.notifyDoneSetting, s.notifyDoneBody, settings.notifyDone, { container.settings.setNotifyDone(it) }, icon = Icons.Rounded.Notifications)
        }
        Group(s.groupUsage) {
            val u = settings.totalUsage
            Column(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 6.dp)) {
                val m = settings.monthUsage
                Text(
                    s.thisMonth(s.money(m.costUsd), settings.monthlyBudgetUsd.takeIf { it > 0 }?.let { s.money(it) }),
                    style = MaterialTheme.typography.titleSmall, color = c.text,
                )
                if (settings.monthlyBudgetUsd > 0) {
                    Spacer(Modifier.height(8.dp))
                    app.ember.ideas.ui.components.EmberProgress((m.costUsd / settings.monthlyBudgetUsd).toFloat(), height = 6.dp)
                }
                Spacer(Modifier.height(14.dp))
                Row(Modifier.fillMaxWidth()) {
                    UsageStat(s.usageRequests, u.requests.toString(), Modifier.weight(1f))
                    UsageStat(s.usageTokens, s.compactNumber(u.inputTokens + u.outputTokens + u.cacheReadTokens), Modifier.weight(1f))
                    UsageStat(s.usageCost, s.money(u.costUsd), Modifier.weight(1f))
                }
                Spacer(Modifier.height(8.dp))
                Text(s.usageNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
            }
            NavRow(s.monthlyBudget, s.budgetLabel(settings.monthlyBudgetUsd), { dialog = "budget" }, icon = Icons.Rounded.Savings, body = s.budgetBody)
            NavRow(s.resetUsage, null, { dialog = "resetUsage" }, icon = Icons.Rounded.RestartAlt, chevron = false)
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
            NavRow(s.importAll, null, chevron = false, onClick = { importer.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }, icon = Icons.Rounded.FileUpload, body = s.importAllBody)
            NavRow(s.addSample, null, {
                container.store.upsert(SampleProject.create(ctx).copy(updatedAt = System.currentTimeMillis()))
                Toast.makeText(ctx, s.sampleAdded, Toast.LENGTH_SHORT).show()
            }, icon = Icons.Rounded.AddCircleOutline)
            val crashes = remember { app.ember.ideas.report.CrashLog.files(ctx).size }
            NavRow(s.crashRow, s.crashCount(crashes), { if (crashes > 0) app.ember.ideas.report.CrashLog.send(ctx, s.crashRow) }, icon = Icons.Rounded.BugReport, chevron = false)
            NavRow(s.deleteAll, null, { dialog = "deleteAll" }, icon = Icons.Rounded.DeleteForever, danger = true)
            NavRow(s.eraseAll, null, { dialog = "eraseAll" }, icon = Icons.Rounded.DeleteForever, danger = true)
            Text(s.backupNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp))
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
                    ChoiceRow(s.modelName(m), s.modelBody(m) + "\n" + s.modelSetCost(s.estimate(app.ember.ideas.ai.CostEstimate.fullSet(m), app.ember.ideas.ai.CostEstimate.fullSetCredits(m))), settings.model == m) { container.settings.setModel(m); dialog = null }
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
        "budget" -> EmberDialog(s.monthlyBudget, s.budgetBody, s.close, { dialog = null }, { dialog = null }, content = {
            Column {
                s.budgetOptionsUsd.forEach { b ->
                    ChoiceRow(s.budgetLabel(b), "", kotlin.math.abs(settings.monthlyBudgetUsd - b) < 0.01) { container.settings.setMonthlyBudget(b); dialog = null }
                    Spacer(Modifier.height(8.dp))
                }
            }
        })
        "github" -> if (settings.hasGithub) {
            EmberDialog(s.githubConnect, s.githubConnected(settings.githubUser), s.githubDisconnect, { container.settings.setGithub(null, ""); dialog = null }, { dialog = null }, danger = true)
        } else {
            EmberDialog(s.githubConnect, null, s.close, { dialog = null }, { dialog = null }, content = {
                app.ember.ideas.ui.screens.project.GitHubConnectForm { dialog = null }
            })
        }
        "eraseAll" -> EmberDialog(s.eraseAll, s.eraseAllBody, s.delete, {
            dialog = null
            container.store.projects.value.forEach { container.engine.cancel(it.id) }
            container.store.deleteAll()
            container.memos.clear()
            container.molds.clear()
            container.settings.clearAll()
            container.images.cleanup(emptySet(), all = true)
            app.ember.ideas.report.CrashLog.clear(ctx)
            ctx.getSharedPreferences("ember_meta", android.content.Context.MODE_PRIVATE).edit().clear().putBoolean("sample_added", true).apply()
            (ctx as? android.app.Activity)?.recreate()
        }, { dialog = null }, danger = true)
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
    Text(title, style = MaterialTheme.typography.labelLarge, color = c.textMuted, modifier = Modifier.padding(vertical = 6.dp))
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(c.surface).padding(horizontal = 12.dp, vertical = 6.dp),
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
fun AboutScreen(onBack: () -> Unit, onOpenPrivacy: () -> Unit = {}, onOpenTerms: () -> Unit = {}) {
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
                Spacer(Modifier.height(16.dp))
                NavRow(s.privacyPolicy, null, onOpenPrivacy, icon = Icons.Rounded.Lock)
                NavRow(s.termsOfService, null, onOpenTerms, icon = Icons.Rounded.Description)
                val email = app.ember.ideas.account.ServerConfig.values.reportEmail
                if (email.isNotBlank()) {
                    val ctx = LocalContext.current
                    NavRow(s.contactUs, email, {
                        runCatching { ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_SENDTO, android.net.Uri.parse("mailto:$email"))) }
                    }, icon = Icons.Rounded.Email, chevron = false)
                }
                Spacer(Modifier.height(20.dp))
                Text(s.licenses, style = MaterialTheme.typography.titleMedium, color = c.text)
                Spacer(Modifier.height(10.dp))
                listOf(
                    "IBM Plex Sans KR" to "SIL Open Font License 1.1 · © IBM Corp.",
                    "Anthropic Java SDK" to "MIT License · © Anthropic",
                    "Jetpack Compose, AndroidX" to "Apache License 2.0 · © The Android Open Source Project",
                    "Kotlin, kotlinx.coroutines, kotlinx.serialization" to "Apache License 2.0 · © JetBrains",
                    "OkHttp" to "Apache License 2.0 · © Square, Inc.",
                    "Google Play Billing Library" to "Android Software Development Kit License · © Google",
                    "Jackson" to "Apache License 2.0 · © FasterXML",
                    "Material Icons" to "Apache License 2.0 · © Google",
                ).forEach { (name, lic) ->
                    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                        Text(name, style = MaterialTheme.typography.titleSmall, color = c.text)
                        Text(lic, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                    }
                }
                // 전자상거래법에 따른 사업자 정보 표시.
                Spacer(Modifier.height(20.dp))
                Text(s.businessInfo, style = MaterialTheme.typography.titleMedium, color = c.text)
                Spacer(Modifier.height(8.dp))
                app.ember.ideas.ui.strings.Legal.businessLines(s.isKorean).forEach { (k, v) ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                        Text(k, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.width(120.dp))
                        Text(v, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.weight(1f))
                    }
                }
                Spacer(Modifier.height(24.dp))
                Text(s.trademarkNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
                Spacer(Modifier.height(40.dp))
            }
        }
    }
}


// ------------------------------------------------------------------ 개인정보처리방침

@Composable
fun PrivacyScreen(onBack: () -> Unit) = LegalScreen(app.ember.ideas.ui.strings.Legal.Doc.PRIVACY, onBack)

@Composable
fun TermsScreen(onBack: () -> Unit) = LegalScreen(app.ember.ideas.ui.strings.Legal.Doc.TERMS, onBack)

/** 약관·방침 화면. assets/legal 의 Markdown 을 그대로 보여 준다(표 포함). */
@Composable
private fun LegalScreen(doc: app.ember.ideas.ui.strings.Legal.Doc, onBack: () -> Unit) {
    val s = LocalStrings.current
    val ctx = LocalContext.current
    val blocks = remember(doc, s.isKorean) {
        app.ember.ideas.ui.markdown.MarkdownParser.parse(app.ember.ideas.ui.strings.Legal.load(ctx, doc, s.isKorean))
            .let { b -> if (b.firstOrNull() is app.ember.ideas.ui.markdown.MdBlock.Heading) b.drop(1) else b }
    }
    EmberBackground {
        Column(Modifier.fillMaxSize()) {
            EmberTopBar(if (doc == app.ember.ideas.ui.strings.Legal.Doc.PRIVACY) s.privacyPolicy else s.termsOfService, onBack)
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
                blocks.forEach { app.ember.ideas.ui.markdown.MarkdownBlockView(it) }
                Spacer(Modifier.height(40.dp))
            }
        }
    }
}


/** 가져올 백업 파일의 최대 크기. */
private const val MAX_IMPORT_BYTES = 20 * 1024 * 1024
