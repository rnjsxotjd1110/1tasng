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
    /** Ember 크레딧 계정이 이 기기에 등록되어 있다. */
    val creditsReady: Boolean = false,
    /** 마지막으로 확인한 크레딧 잔액(서버 확인 전에는 사용량으로 추정해 줄인다). */
    val credits: Int = 0,
    /** 키와 크레딧이 모두 있을 때 크레딧을 쓰기로 골랐다. */
    val preferCredits: Boolean = false,
    /** 아이디어를 낼 때 웹에서 실제 작품을 찾아 참고한다. */
    val webSearch: Boolean = true,
    /** 질문 단계만 빠른 모델(Sonnet)로 처리한다. */
    val fastQuestions: Boolean = false,
    /** 작업이 끝나면 알림을 보낸다. */
    val notifyDone: Boolean = true,
    /** GitHub 토큰이 연결되어 있다. */
    val hasGithub: Boolean = false,
    val githubUser: String = "",
) {
    /** 지금 요청을 Ember 크레딧(중계 서버)으로 보낸다. */
    val usingCredits: Boolean get() = app.ember.ideas.account.ServerConfig.creditsEnabled && creditsReady && (preferCredits || !hasKey)

    /** Claude 를 부를 수 있는 상태(내 키 또는 크레딧). */
    val ready: Boolean get() = hasKey || usingCredits
}

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
    fun setWebSearch(v: Boolean) = put { putBoolean("web_search", v) }
    fun setFastQuestions(v: Boolean) = put { putBoolean("fast_questions", v) }
    fun setNotifyDone(v: Boolean) = put { putBoolean("notify_done", v) }
    fun setPreferCredits(v: Boolean) = put { putBoolean("prefer_credits", v) }

    // ------------------------------------------------------------ Ember 크레딧

    /** 기기 설치마다 한 번 만드는 익명 ID. 서버 등록에만 쓴다. */
    fun installId(): String = prefs.getString("install_id", null) ?: java.util.UUID.randomUUID().toString().also {
        prefs.edit(commit = true) { putString("install_id", it) }
    }

    fun creditToken(): String? = keyPrefs.getString(KEY_CREDIT, null)

    fun setCreditAccount(token: String?, credits: Int) {
        keyPrefs.edit(commit = true) { if (token == null) remove(KEY_CREDIT) else putString(KEY_CREDIT, token) }
        put { putInt("credits", credits) }
    }

    fun setCredits(credits: Int) = put { putInt("credits", credits) }

    // ------------------------------------------------------------ GitHub

    fun githubToken(): String? = keyPrefs.getString(KEY_GITHUB, null)

    fun setGithub(token: String?, user: String) {
        keyPrefs.edit(commit = true) { if (token == null) remove(KEY_GITHUB) else putString(KEY_GITHUB, token) }
        put { if (token == null) remove("github_user") else putString("github_user", user) }
    }

    fun setProfile(p: DevProfile) = put { putString("profile", Protocol.json.encodeToString(DevProfile.serializer(), p)) }

    fun addUsage(u: Usage) {
        val total = _settings.value.totalUsage + u
        val month = currentMonth()
        val prevMonth = if (prefs.getString("usage_month_key", null) == month) _settings.value.monthUsage else Usage()
        put {
            putString("usage", Protocol.json.encodeToString(Usage.serializer(), total))
            putString("usage_month", Protocol.json.encodeToString(Usage.serializer(), prevMonth + u))
            putString("usage_month_key", month)
            // 크레딧으로 쓴 요청은 서버 확인 전까지 잔액을 미리 줄여 보여 준다.
            if (_settings.value.usingCredits && u.costUsd > 0) {
                putInt("credits", _settings.value.credits - app.ember.ideas.account.ServerConfig.creditsFor(u.costUsd))
            }
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
            creditsReady = !creditToken().isNullOrBlank(),
            credits = prefs.getInt("credits", 0),
            preferCredits = prefs.getBoolean("prefer_credits", false),
            webSearch = prefs.getBoolean("web_search", true),
            fastQuestions = prefs.getBoolean("fast_questions", false),
            notifyDone = prefs.getBoolean("notify_done", true),
            hasGithub = !githubToken().isNullOrBlank(),
            githubUser = prefs.getString("github_user", "") ?: "",
        )
    }

    companion object {
        private const val KEY_API = "anthropic_api_key"
        private const val KEY_CREDIT = "ember_credit_token"
        private const val KEY_GITHUB = "github_token"

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
