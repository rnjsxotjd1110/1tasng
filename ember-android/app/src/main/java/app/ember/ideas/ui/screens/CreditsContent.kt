package app.ember.ideas.ui.screens

import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import app.ember.ideas.ai.AiError
import androidx.compose.foundation.layout.offset
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.ember.ideas.account.CreditPack
import app.ember.ideas.account.PurchaseState
import app.ember.ideas.account.ServerConfig
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.CostEstimate
import app.ember.ideas.container
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.Settings
import app.ember.ideas.ui.components.ToggleRow
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.text.Text
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberShape

// 결제한 계정은 Opus(기본 모델), 무료 크레딧만 있는 동안은 Haiku 기준으로 안내한다(서버가 그 모델로 답한다).
private fun discoveryCredits(m: ClaudeModel) = CostEstimate.discoveryCredits(m)
private fun docCredits(m: ClaudeModel) = CostEstimate.designCredits(m, DocDepth.STANDARD, true)

/** 무료 크레딧으로 탐색 + 표준 설계서를 몇 번씩 할 수 있는지(Haiku 기준). */
internal fun freeSets(free: Int): Int = free / (discoveryCredits(ClaudeModel.HAIKU) + docCredits(ClaudeModel.HAIKU))

/** 크레딧 탭의 본문: 소개 또는 잔액, 충전 상품, 결제 상태. */
@Composable
fun CreditsBody(st: Settings, error: String?, onOpenTerms: () -> Unit = {}) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val billing = ctx.container.billing
    val packs by billing.packs.collectAsState()
    val purchase by billing.state.collectAsState()
    LaunchedEffect(st.creditsReady) { if (st.creditsReady) billing.start() }

    if (!st.creditsReady) {
        Text(s.creditsHeadline, style = MaterialTheme.typography.headlineMedium, color = c.text)
        Spacer(Modifier.height(10.dp))
        Text(s.creditsBody(ServerConfig.values.freeCredits, freeSets(ServerConfig.values.freeCredits)), style = MaterialTheme.typography.bodyLarge, color = c.textMuted)
        Spacer(Modifier.height(12.dp))
        Text(s.freeTierNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
        Spacer(Modifier.height(8.dp))
        // 구매한 뒤 기본 모델(Opus)로 쓸 때의 크레딧
        Text(s.creditsUnit(discoveryCredits(ClaudeModel.OPUS), docCredits(ClaudeModel.OPUS), s.modelShort(ClaudeModel.OPUS)), style = MaterialTheme.typography.bodySmall, color = c.textFaint)
    } else {
        // 잔액은 이 화면의 주인공이라 크게 보여 준다.
        Text(s.creditsBalance, style = MaterialTheme.typography.titleSmall, color = c.textMuted)
        Spacer(Modifier.height(4.dp))
        Text("%,d".format(st.credits.coerceAtLeast(0)), style = MaterialTheme.typography.displayMedium, color = if (st.credits > 0) c.text else c.danger)
        Text(
            s.creditsWorth(st.credits.coerceAtLeast(0) / discoveryCredits(st.activeModel), st.credits.coerceAtLeast(0) / docCredits(st.activeModel)),
            style = MaterialTheme.typography.bodyMedium, color = c.textMuted,
        )
        if (st.paidCredits >= 0 && st.freeCredits >= 0 && st.credits >= 0) {
            Text(s.creditsSplit(st.paidCredits, st.freeCredits), style = MaterialTheme.typography.bodySmall, color = c.textMuted)
        }
        if (st.expiringCredits > 0 && st.expiringAt > 0) {
            val date = java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM).format(java.util.Date(st.expiringAt))
            Text(s.creditsExpiring(st.expiringCredits, date), style = MaterialTheme.typography.bodySmall, color = c.gold, modifier = Modifier.padding(top = 4.dp))
        }
        Spacer(Modifier.height(8.dp))
        Text(s.creditsUnit(discoveryCredits(st.activeModel), docCredits(st.activeModel), s.modelShort(st.activeModel)), style = MaterialTheme.typography.bodySmall, color = c.textFaint)
        if (st.freeTier) Text(s.freeTierNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(top = 4.dp))
        if (st.hasKey) {
            Spacer(Modifier.height(12.dp))
            ToggleRow(s.creditsPrefer, s.creditsPreferBody, st.preferCredits, { ctx.container.settings.setPreferCredits(it) })
        }
        Spacer(Modifier.height(16.dp))
        GoogleAccountBlock(st)
        // 크레딧 모드는 Google 계정이 있어야 충전할 수 있다(예전 버전에서 만든 계정은 먼저 연결).
        val linked = st.googleEmail.isNotBlank() || !app.ember.ideas.account.GoogleSignIn.configured
        Spacer(Modifier.height(24.dp))
        Text(s.creditsPacks, style = MaterialTheme.typography.titleSmall, color = c.textMuted)
        Spacer(Modifier.height(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            packs.forEach { pack -> PackRow(pack, enabled = linked && purchase !is PurchaseState.Working) { ctx.findActivity()?.let { billing.buy(it, pack.productId) } } }
        }
        if (!linked) Text(s.packsNeedGoogle, style = MaterialTheme.typography.bodySmall, color = c.gold, modifier = Modifier.padding(top = 8.dp))
        // 전자상거래법·콘텐츠이용자보호지침: 구매 화면에 청약철회·환불·유효기간·미성년자 취소권을 미리 알린다.
        Spacer(Modifier.height(14.dp))
        Column(Modifier.fillMaxWidth().clip(EmberShape.panel).background(c.surface).padding(14.dp)) {
            Text(s.purchaseNoticeTitle, style = MaterialTheme.typography.titleSmall, color = c.text)
            Spacer(Modifier.height(6.dp))
            s.purchaseNotice.forEach { line ->
                Row(Modifier.padding(vertical = 2.dp)) {
                    Text("·", style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.width(12.dp))
                    Text(line, style = MaterialTheme.typography.bodySmall, color = c.textMuted, modifier = Modifier.weight(1f))
                }
            }
            app.ember.ideas.ui.components.GhostButton(s.readTerms, onOpenTerms, color = c.ember, modifier = Modifier.offset(x = (-14).dp))
        }
        val message = when (val p = purchase) {
            PurchaseState.Pending -> s.creditsPending to c.gold
            is PurchaseState.Done -> s.creditsAdded(p.credits) to c.success
            is PurchaseState.Failed -> (p.error?.let { s.errorBody(it) } ?: s.creditsFailed) to c.danger
            PurchaseState.Unavailable -> s.creditsUnavailable to c.textMuted
            else -> null
        }
        AnimatedVisibility(message != null) {
            Text(message?.first ?: "", style = MaterialTheme.typography.bodySmall, color = message?.second ?: c.textMuted, modifier = Modifier.padding(top = 12.dp))
        }
        Spacer(Modifier.height(10.dp))
        Text(s.creditsNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
    }
    if (error != null) {
        Text(error, style = MaterialTheme.typography.bodySmall, color = c.danger, modifier = Modifier.padding(top = 12.dp))
    }
}

@Composable
private fun PackRow(pack: CreditPack, enabled: Boolean, onClick: () -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .clip(EmberShape.control)
            .background(c.surface)
            .border(1.dp, c.outline, EmberShape.control)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(s.creditsAmount(pack.credits), style = MaterialTheme.typography.titleSmall, color = c.text)
            // 산 뒤에는 결제 계정이라 Opus 로 답한다.
            Text(s.creditsWorth(pack.credits / discoveryCredits(ClaudeModel.OPUS), pack.credits / docCredits(ClaudeModel.OPUS)), style = MaterialTheme.typography.bodySmall, color = c.textMuted)
        }
        Spacer(Modifier.width(12.dp))
        Text(
            pack.price ?: s.creditsPriceLoading,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
            color = if (pack.price != null) c.ember else c.textFaint,
        )
    }
}

fun Context.findActivity(): Activity? {
    var cur: Context? = this
    while (cur is ContextWrapper) {
        if (cur is Activity) return cur
        cur = cur.baseContext
    }
    return null
}


/** 연결한 Google 계정과 로그아웃·계정 삭제. 예전 계정이면 연결 버튼을 보여 준다. */
@Composable
private fun GoogleAccountBlock(st: Settings) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var busy by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(false) }
    var message by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<String?>(null) }
    var confirmDelete by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(false) }
    var confirmSignOut by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(false) }

    Column(Modifier.fillMaxWidth().clip(EmberShape.panel).background(c.surface).padding(14.dp)) {
        if (st.googleEmail.isNotBlank()) {
            Text(s.googleLinked(st.googleEmail), style = MaterialTheme.typography.bodyMedium, color = c.text)
        } else if (app.ember.ideas.account.GoogleSignIn.configured) {
            Text(s.googleLinkNeeded, style = MaterialTheme.typography.bodySmall, color = c.textMuted)
            Spacer(Modifier.height(8.dp))
            app.ember.ideas.ui.components.PrimaryButton(s.googleLink, {
                busy = true
                message = null
                scope.launch {
                    try {
                        val g = app.ember.ideas.account.GoogleSignIn.signIn(ctx.findActivity() ?: ctx)
                        container.credits.linkGoogle(g)
                    } catch (e: app.ember.ideas.account.GoogleSignInError) {
                        message = googleErrorText(e, s)
                    } catch (e: AiError) {
                        message = if (e is AiError.Other && e.detail.startsWith("409")) s.googleInUse else s.errorBody(e)
                    } finally { busy = false }
                }
            }, Modifier.fillMaxWidth(), loading = busy, height = 48.dp)
        }
        Row {
            app.ember.ideas.ui.components.GhostButton(s.signOutHere, { confirmSignOut = true }, color = c.textMuted, modifier = Modifier.offset(x = (-14).dp))
            Spacer(Modifier.weight(1f))
            app.ember.ideas.ui.components.GhostButton(s.deleteAccount, { confirmDelete = true }, color = c.danger, modifier = Modifier.offset(x = 14.dp))
        }
        message?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = c.danger) }
    }
    if (confirmSignOut) {
        app.ember.ideas.ui.screens.project.EmberDialog(s.signOutHere, s.signOutHereBody, s.signOutHere, {
            confirmSignOut = false
            container.credits.signOutHere()
            scope.launch { app.ember.ideas.account.GoogleSignIn.signOut(ctx) }
        }, { confirmSignOut = false })
    }
    if (confirmDelete) {
        app.ember.ideas.ui.screens.project.EmberDialog(s.deleteAccount, s.deleteAccountBody(st.credits.coerceAtLeast(0)), s.delete, {
            confirmDelete = false
            busy = true
            scope.launch {
                try {
                    container.credits.deleteAccount()
                    app.ember.ideas.account.GoogleSignIn.signOut(ctx)
                    android.widget.Toast.makeText(ctx, s.accountDeleted, android.widget.Toast.LENGTH_SHORT).show()
                } catch (e: AiError) {
                    message = s.errorBody(e)
                } finally { busy = false }
            }
        }, { confirmDelete = false }, danger = true)
    }
}
