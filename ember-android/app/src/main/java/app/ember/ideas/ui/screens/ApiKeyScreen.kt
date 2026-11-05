package app.ember.ideas.ui.screens

import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ContentPaste
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import app.ember.ideas.ui.text.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import app.ember.ideas.ai.AiError
import app.ember.ideas.container
import app.ember.ideas.data.SettingsStore
import app.ember.ideas.ui.components.EmberBackground
import app.ember.ideas.ui.components.EmberCard
import app.ember.ideas.ui.components.EmberTextField
import app.ember.ideas.ui.components.EmberTopBar
import app.ember.ideas.ui.components.GhostButton
import app.ember.ideas.ui.components.IconCircleButton
import app.ember.ideas.ui.components.PrimaryButton
import app.ember.ideas.ui.components.topFade
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.theme.Ember
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun ApiKeyScreen(fromSettings: Boolean, onDone: () -> Unit, onBack: (() -> Unit)?) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    val container = ctx.container
    val settings = container.settings
    val scope = rememberCoroutineScope()
    var key by remember { mutableStateOf("") }
    var visible by remember { mutableStateOf(false) }
    var checking by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var success by remember { mutableStateOf(false) }
    var guideOpen by remember { mutableStateOf(false) }
    val current by settings.settings.collectAsState()

    fun submit() {
        val k = key.trim()
        if (!SettingsStore.looksLikeKey(k)) { error = s.keyFormatError; return }
        error = null
        checking = true
        scope.launch {
            try {
                container.ai.validate(k, settings.settings.value.model)
                settings.setApiKey(k)
                success = true
                delay(700)
                onDone()
            } catch (e: AiError) {
                error = if (e is AiError.ModelUnavailable) s.keyModelError else s.errorBody(e)
            } catch (e: Exception) {
                error = s.errorBody(AiError.Other(e.message ?: ""))
            } finally {
                checking = false
            }
        }
    }

    EmberBackground {
        Column(Modifier.fillMaxSize().imePadding()) {
            EmberTopBar(title = if (fromSettings) s.keyTitleSettings else "", onBack = onBack)
            Column(
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp),
            ) {
                Box(Modifier.size(56.dp).clip(RoundedCornerShape(18.dp)).background(c.emberGradient), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Lock, null, tint = androidx.compose.ui.graphics.Color.White, modifier = Modifier.size(28.dp))
                }
                Spacer(Modifier.height(20.dp))
                Text(s.keyHeadline, style = MaterialTheme.typography.headlineMedium, color = c.text)
                Spacer(Modifier.height(10.dp))
                Text(s.keyBody, style = MaterialTheme.typography.bodyLarge, color = c.textMuted)
                if (current.hasKey) {
                    Spacer(Modifier.height(16.dp))
                    Row(
                        Modifier.clip(RoundedCornerShape(12.dp)).background(c.success.copy(alpha = 0.12f)).padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Rounded.CheckCircle, null, tint = c.success, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(s.keyCurrent(current.keyHint), style = MaterialTheme.typography.labelMedium, color = c.text)
                    }
                }
                Spacer(Modifier.height(24.dp))
                EmberTextField(
                    value = key,
                    onValueChange = { key = it.trim(); error = null },
                    placeholder = "sk-ant-api03-…",
                    singleLine = true,
                    visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done, autoCorrectEnabled = false),
                    isError = error != null,
                    trailing = {
                        Row {
                            IconCircleButton(if (visible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility, s.toggleVisibility, { visible = !visible }, filled = false, tint = c.textMuted)
                            IconCircleButton(Icons.Rounded.ContentPaste, s.paste, {
                                val cm = ctx.getSystemService(ClipboardManager::class.java)
                                val t = cm?.primaryClip?.getItemAt(0)?.coerceToText(ctx)?.toString()?.trim()
                                if (!t.isNullOrEmpty()) { key = t; error = null }
                            }, filled = false, tint = c.textMuted)
                        }
                    },
                )
                AnimatedVisibility(error != null, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                    Text(error ?: "", style = MaterialTheme.typography.bodySmall, color = c.danger, modifier = Modifier.padding(top = 8.dp, start = 4.dp))
                }
                Spacer(Modifier.height(10.dp))
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(start = 4.dp)) {
                    Icon(Icons.Rounded.Lock, null, tint = c.textFaint, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(if (settings.secureStorageAvailable) s.keySecureNote else s.keyStoredNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint)
                }
                Text(s.keyCostNote, style = MaterialTheme.typography.bodySmall, color = c.textFaint, modifier = Modifier.padding(start = 4.dp, top = 6.dp))
                GhostButton(s.openConsole, {
                    runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://console.anthropic.com/settings/keys"))) }
                }, icon = Icons.AutoMirrored.Rounded.OpenInNew, modifier = Modifier.offset(x = (-12).dp).padding(top = 8.dp))
                Spacer(Modifier.height(12.dp))
                EmberCard(Modifier.fillMaxWidth()) {
                    Column {
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { guideOpen = !guideOpen }.padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(s.keyGuideTitle, style = MaterialTheme.typography.titleSmall, color = c.text, modifier = Modifier.weight(1f))
                            Icon(if (guideOpen) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, null, tint = c.textMuted)
                        }
                        AnimatedVisibility(guideOpen) {
                            Column(Modifier.padding(top = 12.dp)) {
                                s.keyGuideSteps.forEachIndexed { i, step ->
                                    Row(Modifier.padding(vertical = 6.dp)) {
                                        Box(Modifier.size(24.dp).clip(CircleShape).background(c.emberSoft), contentAlignment = Alignment.Center) {
                                            Text("${i + 1}", style = MaterialTheme.typography.labelMedium, color = c.ember)
                                        }
                                        Spacer(Modifier.width(12.dp))
                                        Text(step, style = MaterialTheme.typography.bodyMedium, color = c.textMuted, modifier = Modifier.weight(1f))
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(48.dp))
            }
            Column(Modifier.fillMaxWidth().topFade(c.bg).navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                PrimaryButton(
                    text = if (success) s.keyConnected else s.keyConnect,
                    onClick = ::submit,
                    enabled = key.isNotBlank(),
                    loading = checking,
                    modifier = Modifier.fillMaxWidth(),
                    icon = if (success) Icons.Rounded.CheckCircle else null,
                )
                if (!fromSettings) {
                    GhostButton(s.later, onDone, color = c.textMuted)
                } else if (current.hasKey) {
                    GhostButton(s.removeKey, { settings.setApiKey(null); onDone() }, color = c.danger)
                }
            }
        }
    }
}
