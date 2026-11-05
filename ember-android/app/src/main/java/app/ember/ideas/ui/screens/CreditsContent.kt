package app.ember.ideas.ui.screens

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

private val discoveryCredits get() = ServerConfig.creditsFor(CostEstimate.discovery(ClaudeModel.OPUS))
private val docCredits get() = ServerConfig.creditsFor(CostEstimate.design(ClaudeModel.OPUS, DocDepth.STANDARD, true))

/** 크레딧 탭의 본문: 소개 또는 잔액, 충전 상품, 결제 상태. */
@Composable
fun CreditsBody(st: Settings, error: String?) {
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
        Text(s.creditsBody(ServerConfig.values.freeCredits, ServerConfig.values.freeCredits / discoveryCredits), style = MaterialTheme.typography.bodyLarge, color = c.textMuted)
        Spacer(Modifier.height(12.dp))
        Text(s.creditsUnit(discoveryCredits, docCredits), style = MaterialTheme.typography.bodySmall, color = c.textFaint)
    } else {
        // 잔액은 이 화면의 주인공이라 크게 보여 준다.
        Text(s.creditsBalance, style = MaterialTheme.typography.titleSmall, color = c.textMuted)
        Spacer(Modifier.height(4.dp))
        Text("%,d".format(st.credits.coerceAtLeast(0)), style = MaterialTheme.typography.displayMedium, color = if (st.credits > 0) c.text else c.danger)
        Text(
            s.creditsWorth(st.credits.coerceAtLeast(0) / discoveryCredits, st.credits.coerceAtLeast(0) / docCredits),
            style = MaterialTheme.typography.bodyMedium, color = c.textMuted,
        )
        Spacer(Modifier.height(8.dp))
        Text(s.creditsUnit(discoveryCredits, docCredits), style = MaterialTheme.typography.bodySmall, color = c.textFaint)
        if (st.hasKey) {
            Spacer(Modifier.height(12.dp))
            ToggleRow(s.creditsPrefer, s.creditsPreferBody, st.preferCredits, { ctx.container.settings.setPreferCredits(it) })
        }
        Spacer(Modifier.height(24.dp))
        Text(s.creditsPacks, style = MaterialTheme.typography.titleSmall, color = c.textMuted)
        Spacer(Modifier.height(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            packs.forEach { pack -> PackRow(pack, enabled = purchase !is PurchaseState.Working) { ctx.findActivity()?.let { billing.buy(it, pack.productId) } } }
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
            Text(s.creditsWorth(pack.credits / discoveryCredits, pack.credits / docCredits), style = MaterialTheme.typography.bodySmall, color = c.textMuted)
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
