package app.ember.ideas.ui.screens

import androidx.compose.foundation.combinedClickable
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.AddPhotoAlternate
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Savings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ember.ideas.container
import app.ember.ideas.data.DailySpark
import app.ember.ideas.data.DepthMode
import app.ember.ideas.data.Memo
import app.ember.ideas.data.Mold
import app.ember.ideas.data.MoldCatalog
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.ui.components.EmberCard
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.ForgeIcons
import app.ember.ideas.ui.components.ForgeTile
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.Heat
import app.ember.ideas.ui.components.HeatGauge
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.SecondaryButton
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape
import kotlinx.coroutines.launch

/**
 * 화로(홈). 오늘의 불씨, 새로 단련하기(종류·거푸집·떠오른 생각·단련 깊이), 화로 위에 있는 것.
 */
@Composable
fun HomeScreen(
    onOpenProject: (String) -> Unit,
    onNeedKey: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenLibrary: () -> Unit,
    onOpenMold: (String?) -> Unit = {},
    onManageMolds: () -> Unit = {},
    /** 화로 위 목록에서 여러 프로젝트를 한 번에 지웠을 때(되돌리기 알림용). */
    onDeletedMany: (List<Project>) -> Unit = {},
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val projects by container.store.projects.collectAsState()
    val settings by container.settings.settings.collectAsState()
    val ops by container.engine.ops.collectAsState()
    val molds by container.molds.items.collectAsState()
    val memos by container.memos.items.collectAsState()
    val focus = LocalFocusManager.current

    var kind by rememberSaveable { mutableStateOf<ProjectKind?>(null) }
    var seed by rememberSaveable { mutableStateOf("") }
    var images by rememberSaveable { mutableStateOf(listOf<String>()) }
    var moldId by rememberSaveable { mutableStateOf<String?>(null) }
    var memoId by rememberSaveable { mutableStateOf<String?>(null) }
    var depth by rememberSaveable { mutableStateOf(settings.depth) }
    var sparkOffset by rememberSaveable { mutableIntStateOf(0) }
    var memoSheet by remember { mutableStateOf(false) }
    var pickMemo by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    // 화로 위 목록에서 꾹 눌러 고른 프로젝트 id. 하나라도 있으면 고르기 상태.
    var picked by rememberSaveable { mutableStateOf(listOf<String>()) }
    var confirmDelete by remember { mutableStateOf(false) }
    val selecting = picked.isNotEmpty()
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    fun togglePick(id: String) { picked = if (id in picked) picked - id else picked + id }
    androidx.activity.compose.BackHandler(selecting) { picked = emptyList() }
    LaunchedEffect(projects) { picked = picked.filter { id -> projects.any { it.id == id } } }
    val mold = molds.firstOrNull { it.id == moldId }

    fun addImage(uri: android.net.Uri) {
        if (images.size >= app.ember.ideas.data.ImageStore.MAX_IMAGES) return
        scope.launch {
            val path = container.images.import(uri)
            if (path == null) android.widget.Toast.makeText(ctx, s.imageFailed, android.widget.Toast.LENGTH_SHORT).show()
            else images = images + path
        }
    }
    val picker = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia(),
    ) { uri -> if (uri != null) addImage(uri) }

    // 다른 앱에서 공유받은 글·이미지를 한 번만 가져온다.
    val shared = app.ember.ideas.SharedSeed.value.value
    LaunchedEffect(shared) {
        val sh = shared ?: return@LaunchedEffect
        app.ember.ideas.SharedSeed.shared = null
        if (sh.text.isNotBlank()) seed = sh.text.take(400)
        if (kind == null) kind = ProjectKind.ANY
        sh.image?.let { addImage(it) }
    }
    // 원석함에서 '이 원석으로 단련'을 누르면 그 원석을 가져온다.
    val oreSeed = OreSeed.value.value
    LaunchedEffect(oreSeed) {
        val m = oreSeed ?: return@LaunchedEffect
        OreSeed.value.value = null
        seed = m.text.take(400)
        memoId = m.id
        images = listOfNotNull(m.imagePath)
        if (kind == null) kind = kindFromTags(m.tags) ?: ProjectKind.ANY
    }
    // 원석함·거푸집 화면에서 '이 거푸집으로 시작'을 누르면 그 거푸집을 고른다.
    val moldSeed = MoldSeed.value.value
    LaunchedEffect(moldSeed) {
        val id = moldSeed ?: return@LaunchedEffect
        MoldSeed.value.value = null
        val m = container.molds.get(id) ?: return@LaunchedEffect
        moldId = m.id
        m.kind?.let { kind = it }
        m.depth?.let { depth = it }
    }

    val onFire = projects.filter { !it.isSample }.take(6)

    fun start(quick: Boolean = false, overrideSeed: String? = null) {
        val k = kind ?: ProjectKind.ANY
        if (!settings.ready) { onNeedKey(); return }
        focus.clearFocus()
        val presets = mold?.let { MoldCatalog.presets(it, s.isKorean) }.orEmpty()
        val p = container.engine.createProject(
            k, overrideSeed ?: seed, s.defaultProjectTitle(k), quick, images,
            presets = presets, moldName = mold?.name.orEmpty(), depth = depth, memoId = memoId,
        )
        mold?.let { m -> container.molds.update(m.id) { it.copy(usedCount = it.usedCount + 1) } }
        memoId?.let { id -> container.memos.update(id) { it.copy(projectIds = it.projectIds + p.id) } }
        if (depth != settings.depth) container.settings.setDepth(depth)
        seed = ""
        images = emptyList()
        kind = null
        memoId = null
        onOpenProject(p.id)
    }

    Box(Modifier.fillMaxSize()) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = if (selecting) 96.dp else 32.dp)) {
        item {
            Row(
                Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(androidx.compose.ui.res.painterResource(app.ember.ideas.R.drawable.ic_ember_mark), null, tint = Color.Unspecified, modifier = Modifier.size(width = 18.dp, height = 26.dp))
                Spacer(Modifier.width(10.dp))
                Text("Ember", style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = c.text, modifier = Modifier.weight(1f))
                Box(
                    Modifier.size(44.dp).clip(EmberShape.control).border(1.dp, c.outline, EmberShape.control)
                        .clickable(role = Role.Button) { memoSheet = true }
                        .semantics { contentDescription = s.memoQuick },
                    contentAlignment = Alignment.Center,
                ) { Icon(ForgeIcons.Ore, null, tint = c.text, modifier = Modifier.size(20.dp)) }
            }
        }
        if (settings.monthlyBudgetUsd > 0 && settings.monthUsage.costUsd >= settings.monthlyBudgetUsd * 0.8) {
            item {
                val pct = (settings.monthUsage.costUsd / settings.monthlyBudgetUsd * 100).toInt()
                Row(
                    Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(c.gold.copy(alpha = 0.14f)).padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.Savings, null, tint = c.gold, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(10.dp))
                    Text(s.budgetWarn(pct), style = MaterialTheme.typography.bodySmall, color = c.text)
                }
            }
        }

        // ------------------------------------------------ 오늘의 불씨
        item {
            val spark = DailySpark.today(s.isKorean, sparkOffset)
            SparkCard(spark, onStart = {
                if (!settings.ready) onNeedKey() else start(overrideSeed = spark)
            }, onOther = { sparkOffset++ })
        }

        // ------------------------------------------------ 새로 단련하기
        item {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Spacer(Modifier.height(28.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(s.forgeNew, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = c.text, modifier = Modifier.weight(1f))
                    Text(s.whatToMake, style = MaterialTheme.typography.labelMedium, color = c.textMuted)
                }
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(ProjectKind.GAME, ProjectKind.APP, ProjectKind.WEB, ProjectKind.ANY).forEach { k ->
                        ForgeTile(s.kindShort(k), kindIcon(k), kind == k, { kind = if (kind == k) null else k }, Modifier.weight(1f))
                    }
                }

                Spacer(Modifier.height(20.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(s.moldsSkip, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted, modifier = Modifier.weight(1f))
                    Text(
                        s.manage, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.ember,
                        modifier = Modifier.clip(EmberShape.chip).clickable(role = Role.Button, onClick = onManageMolds).padding(horizontal = 6.dp, vertical = 8.dp),
                    )
                }
                Spacer(Modifier.height(6.dp))
            }
        }
        item {
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                molds.sortedByDescending { it.usedCount }.forEach { m ->
                    MoldChip(m, m.id == moldId, s.moldSkips(m.picks.size)) {
                        if (moldId == m.id) moldId = null else {
                            moldId = m.id
                            m.kind?.let { kind = it }
                            m.depth?.let { depth = it }
                        }
                    }
                }
                NewMoldChip(s.newMold) { onOpenMold(null) }
            }
        }

        item {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Spacer(Modifier.height(16.dp))
                EmberTextField(
                    value = seed,
                    onValueChange = { seed = it; if (it.isBlank()) memoId = null },
                    placeholder = s.seedForgePlaceholder,
                    minHeight = 56.dp,
                    maxLength = 400,
                    leading = ForgeIcons.OreSimple,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (memos.isNotEmpty()) GhostButton(s.fromOreBox, { pickMemo = true }, icon = ForgeIcons.Ore, color = c.textMuted, modifier = Modifier.offset(x = (-14).dp))
                    if (images.size < app.ember.ideas.data.ImageStore.MAX_IMAGES) {
                        GhostButton(s.attachImage, {
                            picker.launch(androidx.activity.result.PickVisualMediaRequest(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }, icon = Icons.Rounded.AddPhotoAlternate, color = c.textMuted, modifier = Modifier.offset(x = (-14).dp))
                    }
                    Spacer(Modifier.weight(1f))
                    if (seed.isNotEmpty()) Text("${seed.length}/400", style = MaterialTheme.typography.labelSmall, color = c.textFaint)
                }
                if (images.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        images.forEach { path ->
                            ImageThumb(path, s.removeImage) {
                                images = images - path
                                // 원석에 붙은 사진은 원석함에 남아 있어야 하므로 지우지 않는다.
                                if (memos.none { it.imagePath == path }) container.images.delete(path)
                            }
                        }
                    }
                    Text(s.imageHint, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(top = 8.dp))
                }

                AnimatedVisibility(kind != null || mold != null || seed.isNotBlank(), enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                    Column {
                        Spacer(Modifier.height(14.dp))
                        Text(s.depthTitle, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.textMuted)
                        Spacer(Modifier.height(8.dp))
                        DepthPicker(depth) { depth = it }
                        Spacer(Modifier.height(14.dp))
                        if (settings.ready) {
                            PrimaryButton(s.startDiscovery, { start() }, Modifier.fillMaxWidth())
                            Text(
                                s.costPerDiscovery(s.estimate(app.ember.ideas.ai.CostEstimate.discovery(settings.model)), s.modelShort(settings.model)),
                                style = MaterialTheme.typography.bodySmall, color = c.textFaint, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                            )
                            Spacer(Modifier.height(4.dp))
                            GhostButton(s.quickIdeas, { start(quick = true) }, icon = Icons.Rounded.FastForward, color = c.textMuted, modifier = Modifier.align(Alignment.CenterHorizontally))
                        } else {
                            PrimaryButton(s.connectToStart, onNeedKey, Modifier.fillMaxWidth(), icon = Icons.Rounded.Key)
                        }
                    }
                }
                if (!settings.ready) {
                    Spacer(Modifier.height(12.dp))
                    SecondaryButton(s.demoTry, {
                        val p = container.engine.createDemoProject(s.demoTitle)
                        onOpenProject(p.id)
                    }, Modifier.fillMaxWidth(), icon = Icons.Rounded.PlayArrow)
                    Text(s.noKeyHint, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(top = 10.dp))
                }
            }
        }

        // ------------------------------------------------ 화로 위에 있는 것
        if (onFire.isNotEmpty()) {
            item {
                if (selecting) {
                    Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 32.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(s.selectedN(picked.size), style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = c.text, modifier = Modifier.weight(1f))
                        GhostButton(s.selectAll, { picked = onFire.map { it.id } }, color = c.textMuted)
                        GhostButton(s.cancel, { picked = emptyList() }, color = c.textMuted)
                    }
                } else {
                    Row(Modifier.padding(start = 20.dp, end = 20.dp, top = 32.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(s.onTheFire, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = c.text, modifier = Modifier.weight(1f))
                        Text(
                            s.countN(projects.count { !it.isSample }), style = MaterialTheme.typography.labelMedium, color = c.textMuted,
                            modifier = Modifier.clip(EmberShape.chip).clickable(role = Role.Button, onClick = onOpenLibrary).padding(horizontal = 6.dp, vertical = 8.dp),
                        )
                    }
                    if (onFire.size >= 2) {
                        Text(s.longPressProjectsHint, style = MaterialTheme.typography.labelSmall, color = c.textFaint, modifier = Modifier.padding(start = 20.dp))
                    }
                }
            }
            items(onFire, key = { "fire_" + it.id }) { p ->
                val op = ops[p.id]
                FireRow(
                    p, busy = op?.running == true, opKind = op?.kind,
                    selecting = selecting, selected = p.id in picked,
                    onLongClick = {
                        haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                        togglePick(p.id)
                    },
                ) { if (selecting) togglePick(p.id) else onOpenProject(p.id) }
            }
        }

        if (settings.profile.isEmpty()) {
            item {
                Spacer(Modifier.height(24.dp))
                EmberCard(Modifier.padding(horizontal = 20.dp).fillMaxWidth(), onClick = onOpenProfile) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Person, null, tint = c.ember)
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(s.profileTipTitle, style = MaterialTheme.typography.titleSmall, color = c.text)
                            Spacer(Modifier.height(2.dp))
                            Text(s.profileTipBody, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
                        }
                        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = c.textFaint, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }

    if (selecting) {
        Row(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(c.bg).padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            SecondaryButton(s.cancel, { picked = emptyList() }, Modifier.weight(1f))
            app.ember.ideas.ui.screens.project.DangerButton(s.delete + " " + picked.size, { confirmDelete = true }, Modifier.weight(1f))
        }
    }
    }

    if (confirmDelete) {
        app.ember.ideas.ui.screens.project.EmberDialog(s.deleteProjectsTitle(picked.size), s.deleteProjectsBody, s.delete, {
            confirmDelete = false
            val gone = picked.mapNotNull { container.engine.delete(it) }
            picked = emptyList()
            if (gone.isNotEmpty()) onDeletedMany(gone)
        }, { confirmDelete = false }, danger = true)
    }
    if (memoSheet) QuickMemoSheet { memoSheet = false }
    if (pickMemo) MemoPickerSheet(memos, onDismiss = { pickMemo = false }) { m ->
        pickMemo = false
        seed = m.text.take(400)
        memoId = m.id
        images = listOfNotNull(m.imagePath)
        if (kind == null) kind = kindFromTags(m.tags)
    }
}

/** 원석의 태그로 만들 것의 종류를 짐작한다. */
private fun kindFromTags(tags: List<String>): ProjectKind? {
    val t = tags.map { it.lowercase() }
    return when {
        t.any { it == "게임" || it == "game" } -> ProjectKind.GAME
        t.any { it == "앱" || it == "app" } -> ProjectKind.APP
        t.any { it == "웹" || it == "web" } -> ProjectKind.WEB
        else -> null
    }
}

/** 원석함에서 고른 원석을 화로로 넘기는 곳. */
object OreSeed { val value = mutableStateOf<Memo?>(null) }

/** 거푸집 화면에서 고른 거푸집 id 를 화로로 넘기는 곳. */
object MoldSeed { val value = mutableStateOf<String?>(null) }

@Composable
private fun SparkCard(spark: String, onStart: () -> Unit, onOther: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Box(
        Modifier
            .padding(start = 20.dp, end = 20.dp, top = 18.dp)
            .fillMaxWidth()
            .clip(EmberShape.panel)
            .background(c.surface)
            .border(1.dp, c.outline, EmberShape.panel),
    ) {
        // 오른쪽 위에서 화로 불빛이 번진다(움직이지 않는 장식 한 곳).
        Canvas(Modifier.matchParentSize()) {
            drawRect(
                Brush.radialGradient(
                    listOf(c.ember.copy(alpha = if (c.isDark) 0.30f else 0.16f), Color.Transparent),
                    center = Offset(size.width * 0.82f, size.height * 0.12f),
                    radius = size.width * 0.42f,
                ),
            )
        }
        Column(Modifier.padding(20.dp)) {
            Text(s.dailySpark, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold), color = c.ember)
            Spacer(Modifier.height(8.dp))
            Text(spark, style = MaterialTheme.typography.headlineMedium, color = c.text)
            Spacer(Modifier.height(8.dp))
            Text(s.dailySparkBody, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PrimaryButton(s.startWithSpark, onStart, Modifier.weight(1f), height = 48.dp)
                SecondaryButton(s.otherSpark, onOther, height = 48.dp)
            }
        }
    }
}

@Composable
private fun MoldChip(m: Mold, selected: Boolean, sub: String, onClick: () -> Unit) {
    val c = Ember.colors
    Column(
        Modifier
            .clip(EmberShape.control)
            .background(if (selected) c.gold.copy(alpha = 0.12f) else c.surface)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) c.gold else c.outline, EmberShape.control)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .heightIn(min = 52.dp)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(m.name, style = MaterialTheme.typography.labelLarge, color = c.text, maxLines = 1)
        Text(sub, style = MaterialTheme.typography.labelSmall, color = if (selected) c.gold else c.textMuted, maxLines = 1)
    }
}

@Composable
private fun NewMoldChip(label: String, onClick: () -> Unit) {
    val c = Ember.colors
    Box(
        Modifier
            .clip(EmberShape.control)
            .clickable(role = Role.Button, onClick = onClick)
            .heightIn(min = 52.dp)
            .drawDashedBorder(c.outline)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = c.textMuted, maxLines = 1)
    }
}

/** 아직 없는 것을 만드는 자리: 점선 테두리. */
fun Modifier.drawDashedBorder(color: Color): Modifier = this.then(
    Modifier.drawBehind {
        drawRoundRect(
            color = color,
            style = Stroke(width = 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(10.dp.toPx()),
        )
    },
)

/** 단련 깊이: 짧게·보통·길게. */
@Composable
fun DepthPicker(depth: DepthMode, onPick: (DepthMode) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        DepthMode.entries.forEach { d ->
            val on = d == depth
            Column(
                Modifier
                    .weight(1f)
                    .clip(EmberShape.control)
                    .background(if (on) c.emberSoft else c.surface)
                    .border(if (on) 1.5.dp else 1.dp, if (on) c.ember else c.outline, EmberShape.control)
                    .clickable(role = Role.RadioButton) { onPick(d) }
                    .heightIn(min = 56.dp)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.Center,
            ) {
                Text(s.depthLabel(d), style = MaterialTheme.typography.labelLarge, color = c.text, maxLines = 1)
                Text(s.depthHint(d), style = MaterialTheme.typography.labelSmall, color = c.textMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
private fun FireRow(
    p: Project, busy: Boolean, opKind: app.ember.ideas.data.OpKind?,
    selecting: Boolean = false, selected: Boolean = false, onLongClick: () -> Unit = {},
    onClick: () -> Unit,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val heat = Heat.of(p, if (busy) opKind else null)
    Column(
        Modifier.fillMaxWidth()
            .background(if (selected) c.emberSoft else Color.Transparent)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = 20.dp),
    ) {
        Row(Modifier.padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            if (selecting) {
                app.ember.ideas.ui.components.SelectMark(selected, multi = true)
                Spacer(Modifier.width(14.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(p.title, style = MaterialTheme.typography.titleMedium, color = c.text, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(8.dp))
                HeatGauge(heat, Modifier.width(170.dp), flowing = busy)
            }
            Spacer(Modifier.width(12.dp))
            Text(
                when {
                    busy -> s.working
                    heat.tempered -> s.blueprintDone
                    else -> s.stageLabel(p.stage)
                },
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                color = when {
                    heat.tempered -> c.steel
                    busy -> c.ember
                    p.stage == ProjectStage.IDEAS -> c.gold
                    else -> c.heat
                },
            )
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline.copy(alpha = 0.6f)))
    }
}

fun kindIcon(k: ProjectKind): ImageVector = when (k) {
    ProjectKind.GAME -> ForgeIcons.Game
    ProjectKind.APP -> ForgeIcons.Phone
    ProjectKind.WEB -> ForgeIcons.Globe
    ProjectKind.ANY -> ForgeIcons.Unknown
}

/** 분야별 색 아이콘으로 프로젝트를 구분한다. 바탕 타일 없이 아이콘만 둔다. */
@Composable
fun KindBadge(kind: ProjectKind, sizeDp: Int) {
    val c = Ember.colors
    val tint = when (kind) {
        ProjectKind.GAME -> c.ember
        ProjectKind.APP -> c.heat
        ProjectKind.WEB -> c.gold
        ProjectKind.ANY -> c.textMuted
    }
    Box(Modifier.size(sizeDp.dp), contentAlignment = Alignment.Center) {
        Icon(kindIcon(kind), null, tint = tint, modifier = Modifier.size((sizeDp * 0.62f).dp))
    }
}

/** 첨부한 참고 이미지의 작은 미리 보기. 오른쪽 위 버튼으로 뺀다. */
@Composable
fun ImageThumb(path: String, removeLabel: String?, size: androidx.compose.ui.unit.Dp = 72.dp, onRemove: (() -> Unit)? = null) {
    val c = Ember.colors
    val bmp = remember(path) {
        runCatching {
            android.graphics.BitmapFactory.decodeFile(path, android.graphics.BitmapFactory.Options().apply { inSampleSize = 4 })?.asImageBitmap()
        }.getOrNull()
    }
    Box(Modifier.size(size).clip(EmberShape.chip).background(c.surface2)) {
        if (bmp != null) {
            androidx.compose.foundation.Image(bmp, null, Modifier.fillMaxSize(), contentScale = androidx.compose.ui.layout.ContentScale.Crop)
        }
        if (onRemove != null) {
            Box(
                Modifier.align(Alignment.TopEnd).size(28.dp).clip(EmberShape.tag)
                    .background(Color.Black.copy(alpha = 0.55f))
                    .clickable(role = Role.Button, onClick = onRemove)
                    .semantics { contentDescription = removeLabel ?: "" },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Close, null, tint = Color.White, modifier = Modifier.size(16.dp)) }
        }
    }
}
