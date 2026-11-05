package app.ember.ideas.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.Protocol
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable

@Serializable
enum class ThemeMode { SYSTEM, LIGHT, DARK }

/** 답변 언어: 앱 언어를 따르거나 고정. */
@Serializable
enum class LanguageMode { AUTO, KO, EN }

data class Settings(
    val hasKey: Boolean = false,
    val keyHint: String = "",
    val model: ClaudeModel = ClaudeModel.OPUS,
    val deepThinking: Boolean = false,
    val theme: ThemeMode = ThemeMode.SYSTEM,
    val language: LanguageMode = LanguageMode.AUTO,
    val onboarded: Boolean = false,
    val profile: DevProfile = DevProfile(),
    val totalUsage: Usage = Usage(),
    val monthUsage: Usage = Usage(),
    val monthlyBudgetUsd: Double = 0.0,
    val haptics: Boolean = true,
)

/**
 * 일반 설정은 SharedPreferences, API 키는 Android Keystore 로 암호화한 EncryptedSharedPreferences 에 둔다.
 * 암호화 저장소를 열 수 없는 기기에서는 앱 전용 저장소에 둔다.
 */
class SettingsStore(context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences("ember_settings", Context.MODE_PRIVATE)
    private val secure: SharedPreferences? = runCatching {
        val master = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        EncryptedSharedPreferences.create(
            context,
            "ember_secure",
            master,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }.getOrNull()

    /** 암호화 저장소를 열 수 없는 기기에서는 앱 전용(다른 앱이 읽을 수 없는) 저장소에 둔다. */
    private val keyPrefs: SharedPreferences = secure ?: context.getSharedPreferences("ember_key", Context.MODE_PRIVATE)

    private val _settings = MutableStateFlow(read())
    val settings: StateFlow<Settings> = _settings.asStateFlow()

    val secureStorageAvailable: Boolean get() = secure != null

    fun apiKey(): String? = keyPrefs.getString(KEY_API, null)

    fun setApiKey(key: String?) {
        val k = key?.trim()?.takeIf { it.isNotEmpty() }
        keyPrefs.edit(commit = true) { if (k == null) remove(KEY_API) else putString(KEY_API, k) }
        refresh()
    }

    fun setModel(m: ClaudeModel) = put { putString("model", m.id) }
    fun setDeepThinking(v: Boolean) = put { putBoolean("deep", v) }
    fun setTheme(t: ThemeMode) = put { putString("theme", t.name) }
    fun setLanguage(l: LanguageMode) = put { putString("language", l.name) }
    fun setOnboarded(v: Boolean) = put { putBoolean("onboarded", v) }
    fun setHaptics(v: Boolean) = put { putBoolean("haptics", v) }
    fun setProfile(p: DevProfile) = put { putString("profile", Protocol.json.encodeToString(DevProfile.serializer(), p)) }

    fun addUsage(u: Usage) {
        val total = _settings.value.totalUsage + u
        val month = currentMonth()
        val prevMonth = if (prefs.getString("usage_month_key", null) == month) _settings.value.monthUsage else Usage()
        put {
            putString("usage", Protocol.json.encodeToString(Usage.serializer(), total))
            putString("usage_month", Protocol.json.encodeToString(Usage.serializer(), prevMonth + u))
            putString("usage_month_key", month)
        }
    }

    fun setMonthlyBudget(usd: Double) = put { putFloat("budget", usd.toFloat()) }

    /** 월 예산을 넘었으면 true. 예산이 없으면 항상 false. */
    fun overBudget(): Boolean {
        val st = _settings.value
        return st.monthlyBudgetUsd > 0 && st.monthUsage.costUsd >= st.monthlyBudgetUsd
    }

    private fun currentMonth(): String {
        val c = java.util.Calendar.getInstance()
        return "${c.get(java.util.Calendar.YEAR)}-${c.get(java.util.Calendar.MONTH) + 1}"
    }

    fun resetUsage() = put { remove("usage"); remove("usage_month"); remove("usage_month_key") }

    fun clearAll() {
        prefs.edit { clear() }
        keyPrefs.edit { clear() }
        refresh()
    }

    private inline fun put(block: SharedPreferences.Editor.() -> Unit) {
        prefs.edit(commit = true) { block() }
        refresh()
    }

    private fun refresh() { _settings.value = read() }

    private fun read(): Settings {
        val key = apiKey()
        return Settings(
            hasKey = !key.isNullOrBlank(),
            keyHint = key?.let { maskKey(it) } ?: "",
            model = ClaudeModel.fromId(prefs.getString("model", null)),
            deepThinking = prefs.getBoolean("deep", false),
            theme = runCatching { ThemeMode.valueOf(prefs.getString("theme", "SYSTEM")!!) }.getOrDefault(ThemeMode.SYSTEM),
            language = runCatching { LanguageMode.valueOf(prefs.getString("language", "AUTO")!!) }.getOrDefault(LanguageMode.AUTO),
            onboarded = prefs.getBoolean("onboarded", false),
            profile = prefs.getString("profile", null)?.let { runCatching { Protocol.json.decodeFromString(DevProfile.serializer(), it) }.getOrNull() } ?: DevProfile(),
            totalUsage = prefs.getString("usage", null)?.let { runCatching { Protocol.json.decodeFromString(Usage.serializer(), it) }.getOrNull() } ?: Usage(),
            haptics = prefs.getBoolean("haptics", true),
            monthUsage = if (prefs.getString("usage_month_key", null) == currentMonth()) {
                prefs.getString("usage_month", null)?.let { runCatching { Protocol.json.decodeFromString(Usage.serializer(), it) }.getOrNull() } ?: Usage()
            } else Usage(),
            monthlyBudgetUsd = prefs.getFloat("budget", 0f).toDouble(),
        )
    }

    companion object {
        private const val KEY_API = "anthropic_api_key"

        fun maskKey(key: String): String {
            val k = key.trim()
            if (k.length <= 12) return "••••"
            return k.take(10) + "••••" + k.takeLast(4)
        }

        fun looksLikeKey(key: String): Boolean {
            val k = key.trim()
            return k.startsWith("sk-ant-") && k.length >= 40 && k.none { it.isWhitespace() }
        }
    }
}
