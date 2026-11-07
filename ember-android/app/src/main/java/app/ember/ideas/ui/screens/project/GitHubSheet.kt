package app.ember.ideas.ui.screens.project

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.Project
import app.ember.ideas.handoff.GitHubClient
import app.ember.ideas.handoff.GitHubError
import app.ember.ideas.handoff.GitHubRepo
import app.ember.ideas.handoff.Handoff
import app.ember.ideas.handoff.RepoFile
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.ToggleRow
import app.ember.ideas.ui.components.UnderlineTab
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape
import kotlinx.coroutines.launch

/** 토큰 연결 양식. 설정 화면과 GitHub 시트에서 함께 쓴다. */
@Composable
fun GitHubConnectForm(onConnected: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var token by remember { mutableStateOf("") }
    var checking by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    Column {
        Text(s.githubTokenBody, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
        Spacer(Modifier.height(12.dp))
        s.githubTokenSteps.forEachIndexed { i, step ->
            Row(Modifier.padding(vertical = 4.dp)) {
                Text("${i + 1}", style = MaterialTheme.typography.titleSmall, color = c.ember, modifier = Modifier.width(20.dp))
                Spacer(Modifier.width(6.dp))
                Text(step, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.weight(1f))
            }
        }
        GhostButton(s.githubOpenTokens, {
            runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/settings/personal-access-tokens/new"))) }
        }, icon = Icons.AutoMirrored.Rounded.OpenInNew, modifier = Modifier.offset(x = (-12).dp))
        EmberTextField(
            value = token,
            onValueChange = { token = it.trim(); error = null },
            placeholder = "github_pat_…",
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrectEnabled = false),
            isError = error != null,
        )
        if (error != null) Text(error ?: "", style = MaterialTheme.typography.bodySmall, color = c.danger, modifier = Modifier.padding(top = 8.dp))
        Spacer(Modifier.height(12.dp))
        PrimaryButton(s.githubConnect, {
            checking = true
            scope.launch {
                try {
                    val user = GitHubClient().verify(token)
                    ctx.container.settings.setGithub(token, user)
                    onConnected()
                } catch (e: GitHubError) {
                    error = s.githubError(e)
                } catch (e: kotlinx.coroutines.CancellationException) {
                    throw e
                } catch (e: Exception) {
                    // 토큰에 헤더로 보낼 수 없는 글자(한글, …)가 섞이면 여기로 온다.
                    error = s.githubError(GitHubError.BadToken)
                } finally {
                    checking = false
                }
            }
        }, Modifier.fillMaxWidth(), enabled = token.length >= 20, loading = checking)
    }
}

/** 설계서를 GitHub 새 저장소나 기존 저장소의 이슈로 보낸다. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun GitHubSheet(project: Project, onDismiss: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val settings by container.settings.settings.collectAsState()
    val scope = rememberCoroutineScope()
    val doc = project.design?.latest?.markdown.orEmpty()
    val sections = remember(doc) { GitHubClient.sections(doc) }
    var tab by remember { mutableStateOf(0) }
    var name by remember { mutableStateOf(GitHubClient.repoNameFor(project.title, project.id)) }
    var private by remember { mutableStateOf(true) }
    var repos by remember { mutableStateOf<List<GitHubRepo>?>(null) }
    var chosen by remember { mutableStateOf<String?>(null) }
    var perSection by remember { mutableStateOf(sections.size > 1) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var doneUrl by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(settings.hasGithub, tab) {
        if (settings.hasGithub && tab == 1 && repos == null) {
            try {
                val token = container.settings.githubToken() ?: throw GitHubError.BadToken
                repos = GitHubClient().repos(token).filter { it.hasIssues }
                chosen = repos?.firstOrNull()?.fullName
            } catch (e: GitHubError) {
                error = s.githubError(e)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                error = s.githubError(GitHubError.Other(e.message ?: e.javaClass.simpleName))
            }
        }
    }

    fun run(block: suspend (String) -> String) {
        busy = true
        error = null
        scope.launch {
            try {
                val token = container.settings.githubToken() ?: throw GitHubError.BadToken
                doneUrl = block(token)
            } catch (e: GitHubError) {
                error = s.githubError(e)
                if (e is GitHubError.BadToken) container.settings.setGithub(null, "")
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                // 예상하지 못한 응답(형식 오류 등)도 앱을 멈추지 않고 안내한다.
                error = s.githubError(GitHubError.Other(e.message ?: e.javaClass.simpleName))
            } finally {
                busy = false
            }
        }
    }

    EmberSheet(onDismiss) {
        SheetTitle(s.github, if (settings.hasGithub) s.githubConnected(settings.githubUser) else null, onDismiss)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            when {
                doneUrl != null -> {
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 12.dp)) {
                        Icon(Icons.Rounded.CheckCircle, null, tint = c.success)
                        Spacer(Modifier.width(10.dp))
                        Text(s.githubDone, style = MaterialTheme.typography.titleMedium, color = c.text)
                    }
                    Text(doneUrl ?: "", style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                }
                !settings.hasGithub -> GitHubConnectForm { }
                else -> {
                    Row(Modifier.fillMaxWidth()) {
                        UnderlineTab(s.githubNewRepo, tab == 0, Modifier.weight(1f)) { tab = 0 }
                        UnderlineTab(s.githubIssue, tab == 1, Modifier.weight(1f)) { tab = 1 }
                    }
                    Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline))
                    Spacer(Modifier.height(16.dp))
                    if (tab == 0) {
                        Text(s.githubRepoName, style = MaterialTheme.typography.labelLarge, color = c.textMuted, modifier = Modifier.padding(bottom = 8.dp))
                        EmberTextField(name, { v -> name = v.filter { it.isLetterOrDigit() || it == '-' || it == '_' || it == '.' }.take(100) }, placeholder = "my-game", singleLine = true)
                        Spacer(Modifier.height(8.dp))
                        ToggleRow(s.githubPrivate, s.githubPrivateBody, private, { private = it }, icon = Icons.Rounded.Lock)
                        Text(s.githubRepoFiles, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(top = 8.dp))
                    } else {
                        val list = repos
                        if (list != null && list.isEmpty()) {
                            Text(s.githubNoRepos, style = MaterialTheme.typography.bodyMedium, color = c.textMuted)
                        } else if (list != null) {
                            Text(s.githubPickRepo, style = MaterialTheme.typography.labelLarge, color = c.textMuted, modifier = Modifier.padding(bottom = 8.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                list.take(12).forEach { r ->
                                    val sel = r.fullName == chosen
                                    Row(
                                        Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(EmberShape.control)
                                            .background(if (sel) c.emberSoft else c.surface2)
                                            .border(1.dp, if (sel) c.ember else c.surface2, EmberShape.control)
                                            .clickable(role = Role.RadioButton) { chosen = r.fullName }
                                            .padding(horizontal = 14.dp, vertical = 10.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Text(r.fullName, style = MaterialTheme.typography.bodyMedium, color = c.text, modifier = Modifier.weight(1f), maxLines = 1)
                                        if (r.private) Icon(Icons.Rounded.Lock, null, tint = c.textFaint, modifier = Modifier.size(16.dp))
                                    }
                                }
                            }
                            if (sections.size > 1) {
                                Spacer(Modifier.height(8.dp))
                                ToggleRow(s.githubPerSection, s.githubPerSectionBody(sections.size), perSection, { perSection = it })
                            }
                        }
                    }
                    GhostButton(s.githubDisconnect, { container.settings.setGithub(null, "") }, color = c.textFaint, modifier = Modifier.offset(x = (-12).dp).padding(top = 8.dp))
                }
            }
            if (error != null) Text(error ?: "", style = MaterialTheme.typography.bodySmall, color = c.danger, modifier = Modifier.padding(top = 8.dp))
            Spacer(Modifier.height(12.dp))
        }
        if (settings.hasGithub || doneUrl != null) {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 10.dp)) {
                when {
                    doneUrl != null -> PrimaryButton(s.githubOpen, {
                        runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(doneUrl))) }
                    }, Modifier.fillMaxWidth(), icon = Icons.AutoMirrored.Rounded.OpenInNew)
                    tab == 0 -> PrimaryButton(s.githubCreateRepo, {
                        val idea = project.selectedIdea
                        val files = listOf(
                            RepoFile("README.md", readmeFor(project, s.isKorean)),
                            RepoFile("CLAUDE.md", Handoff.buildClaudeMd(project, idea, settings.profile, s.isKorean)),
                            RepoFile("docs/DESIGN.md", doc),
                        )
                        run { t -> GitHubClient().createRepo(t, name, idea?.logline ?: project.title, private, files) }
                    }, Modifier.fillMaxWidth(), enabled = name.isNotBlank() && doc.isNotBlank(), loading = busy)
                    else -> {
                        val count = if (perSection) sections.size else 1
                        PrimaryButton(s.githubSendIssues(count), {
                            val repo = chosen ?: return@PrimaryButton
                            run { t ->
                                val api = GitHubClient()
                                if (perSection) {
                                    var first = ""
                                    sections.forEach { (title, body) ->
                                        val url = api.createIssue(t, repo, "[${project.title}] $title", body + "\n\n---\n_Ember_")
                                        if (first.isEmpty()) first = url
                                    }
                                    first.substringBeforeLast("/issues/") + "/issues"
                                } else {
                                    api.createIssue(t, repo, project.title, doc)
                                }
                            }
                        }, Modifier.fillMaxWidth(), enabled = chosen != null && doc.isNotBlank(), loading = busy)
                    }
                }
            }
        }
    }
}

private fun readmeFor(project: Project, korean: Boolean): String = buildString {
    val idea = project.selectedIdea
    appendLine("# ${project.title}")
    appendLine()
    if (idea != null) {
        appendLine(idea.logline)
        appendLine()
    }
    if (korean) {
        appendLine("이 저장소는 Ember에서 만든 설계서로 시작했어요.")
        appendLine()
        appendLine("- 설계서: [docs/DESIGN.md](docs/DESIGN.md)")
        appendLine("- Claude Code 작업 안내: [CLAUDE.md](CLAUDE.md)")
    } else {
        appendLine("This repository started from a design doc made in Ember.")
        appendLine()
        appendLine("- Design doc: [docs/DESIGN.md](docs/DESIGN.md)")
        appendLine("- Claude Code guide: [CLAUDE.md](CLAUDE.md)")
    }
}
