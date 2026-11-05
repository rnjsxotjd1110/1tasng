package app.ember.ideas.ui.screens.project

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.bridge.BridgeApi
import app.ember.ideas.bridge.BridgeError
import app.ember.ideas.bridge.Workbench
import app.ember.ideas.container
import app.ember.ideas.data.Project
import app.ember.ideas.handoff.Handoff
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.ForgeIcons
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.reduceMotion
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.strings.Strings
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape
import kotlinx.coroutines.launch

/** 작업대 상태를 한 줄로: 연결됨(초록 점), 꺼짐, 연결 안 함. */
@Composable
fun WorkbenchStatusLine(modifier: Modifier = Modifier) {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val settings by container.settings.settings.collectAsState()
    val status by container.workbench.status.collectAsState()
    LaunchedEffect(settings.workbenchName) { container.workbench.refreshStatus() }
    val paired = settings.workbenchName.isNotEmpty()
    val (dot, text) = when {
        !paired -> c.textFaint to s.benchNone
        status == Workbench.Status.ONLINE -> c.success to s.benchConnected(settings.workbenchName)
        status == Workbench.Status.CHECKING -> c.gold to s.benchChecking
        status == Workbench.Status.UNPAIRED -> c.danger to s.benchUnpaired
        else -> c.danger to s.benchOffline
    }
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(dot))
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.labelMedium, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

internal fun benchErrorText(e: Throwable, s: Strings): String = when (e) {
    is BridgeError.BadCode -> s.benchBadCode
    is BridgeError.RateLimited -> s.benchRateLimited
    is BridgeError.Unauthorized -> s.benchUnpaired
    is BridgeError.Unreachable -> s.benchUnreachable
    // 브리지가 보낸 설명은 한국어로만 오므로 한국어 화면에서만 그대로 보여 준다.
    is BridgeError.Rejected -> if (s.isKorean && e.detail.isNotBlank()) e.detail else s.benchRejected
    else -> s.benchUnreachable
}

/**
 * PC 와 연결하기: 같은 Wi‑Fi 에서 브리지를 찾고(직접 주소 입력도 가능), 6자리 코드로 연결한다.
 */
@Composable
fun PairPanel(onPaired: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val bench = container.workbench
    val found by bench.found.collectAsState()
    val searching by bench.searching.collectAsState()
    val scope = rememberCoroutineScope()
    var target by remember { mutableStateOf<Pair<String, Int>?>(null) }
    var targetName by remember { mutableStateOf("") }
    var manual by rememberSaveable { mutableStateOf(false) }
    var address by rememberSaveable { mutableStateOf("") }
    var code by rememberSaveable { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    DisposableEffect(Unit) {
        bench.startDiscovery()
        onDispose { bench.stopDiscovery() }
    }
    // 하나만 찾으면 바로 고른다.
    LaunchedEffect(found) { if (target == null && found.size == 1) { target = found[0].host to found[0].port; targetName = found[0].name } }

    Column(Modifier.fillMaxWidth()) {
        if (target == null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (searching) {
                    CircularProgressIndicator(Modifier.size(14.dp), color = c.ember, strokeWidth = 2.dp)
                    Spacer(Modifier.width(8.dp))
                }
                Text(if (found.isEmpty() && !searching) s.benchNoneFound else s.benchSearching, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
            found.forEach { f ->
                Row(
                    Modifier.fillMaxWidth().clip(EmberShape.control).border(1.dp, c.outline, EmberShape.control)
                        .clickable(role = Role.Button) { target = f.host to f.port; targetName = f.name; error = null }
                        .heightIn(min = 56.dp).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(ForgeIcons.Monitor, null, tint = c.textMuted, modifier = Modifier.size(24.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(f.name, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text("${f.host}:${f.port}", style = MaterialTheme.typography.labelSmall, color = c.textFaint)
                    }
                }
                Spacer(Modifier.height(6.dp))
            }
            if (!manual) {
                GhostButton(s.benchManual, { manual = true }, color = c.textMuted)
            } else {
                EmberTextField(address, { address = it; error = null }, s.benchAddressHint, singleLine = true, maxLength = 60,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri))
                Spacer(Modifier.height(8.dp))
                PrimaryButton(s.next, {
                    val a = Workbench.parseAddress(address)
                    if (a == null) { error = s.benchUnreachable; return@PrimaryButton }
                    working = true
                    scope.launch {
                        runCatching { bench.info(a.first, a.second) }
                            .onSuccess { info -> target = a; targetName = info.name.ifBlank { a.first }; error = null }
                            .onFailure { error = benchErrorText(it, s) }
                        working = false
                    }
                }, Modifier.fillMaxWidth(), enabled = address.isNotBlank(), loading = working, height = 48.dp)
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(ForgeIcons.Monitor, null, tint = c.textMuted, modifier = Modifier.size(24.dp))
                Spacer(Modifier.width(12.dp))
                Text(targetName, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                GhostButton(s.changeShort, { target = null; code = ""; error = null }, color = c.textMuted)
            }
            Spacer(Modifier.height(8.dp))
            Text(s.benchCodeTitle, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
            Spacer(Modifier.height(8.dp))
            EmberTextField(
                code, { v -> code = v.filter { it.isDigit() }.take(6); error = null }, "000000", singleLine = true, maxLength = 6,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            )
            Spacer(Modifier.height(10.dp))
            PrimaryButton(s.benchPair, {
                val t = target ?: return@PrimaryButton
                working = true
                scope.launch {
                    runCatching { bench.pair(t.first, t.second, code) }
                        .onSuccess { onPaired() }
                        .onFailure { error = benchErrorText(it, s) }
                    working = false
                }
            }, Modifier.fillMaxWidth(), enabled = code.length == 6, loading = working, height = 48.dp)
        }
        error?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, style = MaterialTheme.typography.bodySmall, color = c.danger)
        }
        Spacer(Modifier.height(12.dp))
        Text(s.benchPrivacy, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
    }
}

/**
 * 작업대로 보내기 시트: 무엇을(개발 시작·다음 작업·도면 파일) 어떻게(Claude Code 실행·클립보드·파일) 보낼지 고른다.
 * 연결한 PC 가 없으면 연결부터 한다. 아래에는 Claude 앱·GitHub·파일 공유로 넘기는 길도 둔다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkbenchSheet(project: Project, onDismiss: () -> Unit, onClaudeApp: () -> Unit, onGitHub: () -> Unit, onShareFile: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val settings by container.settings.settings.collectAsState()
    val status by container.workbench.status.collectAsState()
    val scope = rememberCoroutineScope()
    var what by rememberSaveable { mutableStateOf(Handoff.BenchWhat.START) }
    var how by rememberSaveable { mutableStateOf(BridgeApi.MODE_CODE) }
    var sending by remember { mutableStateOf(false) }
    var sent by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val paired = settings.workbenchName.isNotEmpty() && status != Workbench.Status.UNPAIRED
    var repair by remember { mutableStateOf(false) }
    val folder = settings.workbenchFolder.ifBlank { Handoff.safeFileName(documentTitleOf(project)).lowercase().replace(' ', '-').take(40) }

    EmberSheet(onDismiss) {
        SheetTitle(s.sendToBench, onClose = onDismiss)
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            if (!paired || repair) {
                PairPanel(onPaired = { repair = false })
            } else {
                Row(
                    Modifier.fillMaxWidth().clip(EmberShape.panel).background(c.bg).border(1.dp, c.outline, EmberShape.panel).padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(ForgeIcons.Monitor, null, tint = c.textMuted, modifier = Modifier.size(28.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(settings.workbenchName, style = MaterialTheme.typography.titleSmall, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        WorkbenchStatusDetail(status)
                    }
                    Box(
                        Modifier.clip(EmberShape.chip).border(1.dp, c.outline, EmberShape.chip).clickable(role = Role.Button) { repair = true }
                            .heightIn(min = 36.dp).padding(horizontal = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) { Text(s.changeShort, style = MaterialTheme.typography.labelMedium, color = c.text) }
                }

                Spacer(Modifier.height(18.dp))
                Text(s.whatToSend, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf(Handoff.BenchWhat.START to s.sendStart, Handoff.BenchWhat.NEXT to s.sendNext, Handoff.BenchWhat.FILES to s.sendFiles).forEach { (w, label) ->
                        val on = what == w
                        Box(
                            Modifier.weight(1f).clip(EmberShape.chip)
                                .background(if (on) c.emberSoft else c.bg)
                                .border(if (on) 1.5.dp else 1.dp, if (on) c.ember else c.outline, EmberShape.chip)
                                .clickable(role = Role.RadioButton) { what = w; sent = null }
                                .heightIn(min = 44.dp).padding(horizontal = 6.dp),
                            contentAlignment = Alignment.Center,
                        ) { Text(label, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = if (on) c.text else c.textMuted, textAlign = TextAlign.Center, maxLines = 2) }
                    }
                }

                Spacer(Modifier.height(18.dp))
                Text(s.howToOpen, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
                Spacer(Modifier.height(8.dp))
                listOf(
                    Triple(BridgeApi.MODE_CODE, s.howCode, s.howCodeDesc(folder)),
                    Triple(BridgeApi.MODE_CLIPBOARD, s.howClip, s.howClipDesc),
                    Triple(BridgeApi.MODE_FILE, s.howFile, "docs/DESIGN.md, CLAUDE.md"),
                ).forEach { (mode, label, desc) ->
                    val on = how == mode
                    Row(
                        Modifier.fillMaxWidth().clip(EmberShape.control)
                            .background(if (on) c.ember.copy(alpha = 0.10f) else c.bg)
                            .border(if (on) 1.5.dp else 1.dp, if (on) c.ember else c.outline, EmberShape.control)
                            .clickable(role = Role.RadioButton) { how = mode; sent = null }
                            .heightIn(min = 56.dp).padding(horizontal = 14.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(label, style = MaterialTheme.typography.titleSmall, color = c.text)
                            Text(desc, style = MaterialTheme.typography.bodySmall, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        app.ember.ideas.ui.components.SelectMark(on, multi = false)
                    }
                    Spacer(Modifier.height(6.dp))
                }

                if (sending || sent != null) {
                    Spacer(Modifier.height(8.dp))
                    SendTrack(sending, sent)
                }
                error?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(it, style = MaterialTheme.typography.bodySmall, color = c.danger)
                }
                Spacer(Modifier.height(12.dp))
                PrimaryButton(if (sent != null) s.sendAgain else s.sendToBench, {
                    sending = true
                    error = null
                    sent = null
                    val req = Handoff.benchRequest(project, project.selectedIdea, settings.profile, what, how, settings.workbenchFolder, s.isKorean)
                    scope.launch {
                        runCatching { container.workbench.send(req) }
                            .onSuccess { r ->
                                // 브리지는 실제로 한 일(터미널 실행 실패 후 클립보드 대체 등)을 한국어로 알려 준다.
                                sent = if (s.isKorean && r.message.isNotBlank()) r.message.trimEnd('.') + "." else when (r.mode) {
                                    BridgeApi.MODE_CODE -> s.sentCode(r.claudeFound)
                                    BridgeApi.MODE_CLIPBOARD -> if (r.saved.isEmpty()) s.sentClip else s.sentClip + " " + s.sentFiles(r.saved.size, r.folder)
                                    else -> s.sentFiles(r.saved.size, r.folder)
                                }
                            }
                            .onFailure { error = benchErrorText(it, s) }
                        sending = false
                    }
                }, Modifier.fillMaxWidth(), loading = sending, height = 54.dp)
            }
            Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.Center) {
                GhostButton(s.claudeAppShort, onClaudeApp, color = c.textMuted)
                GhostButton(s.github, onGitHub, color = c.textMuted)
                GhostButton(s.shareAsFile, onShareFile, color = c.textMuted)
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun WorkbenchStatusDetail(status: Workbench.Status) {
    val s = LocalStrings.current
    val c = Ember.colors
    val (dot, text) = when (status) {
        Workbench.Status.ONLINE -> c.success to s.benchOnlineLine
        Workbench.Status.CHECKING, Workbench.Status.NONE -> c.gold to s.benchChecking
        else -> c.danger to s.benchOfflineBody
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(7.dp).clip(CircleShape).background(dot))
        Spacer(Modifier.width(6.dp))
        Text(text, style = MaterialTheme.typography.labelSmall, color = c.textMuted, maxLines = 2)
    }
}

/** 휴대폰에서 작업대로 쇳물 한 조각이 건너가는 줄. 정수 픽셀 단위로 14칸에 나눠 움직인다. */
@Composable
private fun SendTrack(sending: Boolean, result: String?) {
    val s = LocalStrings.current
    val c = Ember.colors
    val still = reduceMotion()
    val t = if (sending && !still) {
        rememberInfiniteTransition(label = "packet").animateFloat(0f, 1f, infiniteRepeatable(tween(1100, easing = LinearEasing), RepeatMode.Restart), label = "p").value
    } else if (result != null) 1f else 0f
    val stepped = kotlin.math.floor(t * 14f) / 14f
    Column(Modifier.fillMaxWidth().clip(EmberShape.panel).background(c.bg).border(1.dp, c.outline, EmberShape.panel).padding(horizontal = 14.dp, vertical = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(s.phoneShort, style = MaterialTheme.typography.labelSmall, color = c.textMuted, modifier = Modifier.width(52.dp))
            Canvas(Modifier.weight(1f).height(10.dp)) {
                val y = size.height / 2
                drawRect(c.outline, topLeft = Offset(0f, y - 1f), size = Size(size.width, 2f))
                val sq = 8.dp.toPx()
                val x = kotlin.math.floor((size.width - sq) * stepped)
                drawRect(if (result != null) c.success else c.gold, topLeft = Offset(x, y - sq / 2), size = Size(sq, sq))
            }
            Text(s.benchShort, style = MaterialTheme.typography.labelSmall, color = c.textMuted, textAlign = TextAlign.End, modifier = Modifier.width(52.dp))
        }
        if (result != null) {
            Spacer(Modifier.height(8.dp))
            Text(result, style = MaterialTheme.typography.bodyMedium, color = c.text)
        }
    }
}

/** 대장간(설정) 화면의 작업대 칸. */
@Composable
fun WorkbenchSettingsBlock() {
    val s = LocalStrings.current
    val c = Ember.colors
    val container = LocalContext.current.container
    val settings by container.settings.settings.collectAsState()
    var connecting by rememberSaveable { mutableStateOf(false) }
    var folder by rememberSaveable(settings.workbenchFolder) { mutableStateOf(settings.workbenchFolder) }
    Column(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 8.dp)) {
        WorkbenchStatusLine()
        Spacer(Modifier.height(12.dp))
        if (settings.workbenchName.isEmpty() || connecting) {
            if (connecting) PairPanel(onPaired = { connecting = false })
            else PrimaryButton(s.benchConnect, { connecting = true }, Modifier.fillMaxWidth(), icon = ForgeIcons.Monitor, height = 48.dp)
            Spacer(Modifier.height(12.dp))
            Text(s.benchHowTo, style = MaterialTheme.typography.titleSmall, color = c.text)
            Spacer(Modifier.height(4.dp))
            Text(s.benchHowToBody, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
        } else {
            Text(s.benchFolder, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
            Spacer(Modifier.height(6.dp))
            EmberTextField(folder, { folder = it.take(40); container.settings.setWorkbenchFolder(folder) }, s.benchFolderHint, singleLine = true, maxLength = 40)
            Row {
                GhostButton(s.changeShort, { connecting = true }, color = c.textMuted)
                GhostButton(s.benchDisconnect, { container.workbench.unpair() }, color = c.danger)
            }
        }
    }
}
