package app.ember.ideas

import android.app.Application
import android.content.Context
import app.ember.ideas.ai.AiService
import app.ember.ideas.ai.ClaudeAiService
import app.ember.ideas.data.ProjectEngine
import app.ember.ideas.data.ProjectStore
import app.ember.ideas.data.SampleProject
import app.ember.ideas.data.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** 앱 전역 의존성. 테스트에서는 AiService 를 가짜로 바꿔 끼운다. */
class AppContainer(context: Context, aiOverride: AiService? = null) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val settings = SettingsStore(context)
    val store = ProjectStore(context.filesDir, scope)
    val ai: AiService = aiOverride ?: ClaudeAiService { settings.apiKey() }
    val engine = ProjectEngine(store, settings, ai, scope)

    init {
        store.loadBlocking()
        val prefs = context.getSharedPreferences("ember_meta", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("sample_added", false)) {
            store.upsert(SampleProject.create(context))
            prefs.edit().putBoolean("sample_added", true).apply()
        }
    }
}

class EmberApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        if (!::container.isInitialized) container = AppContainer(this)
    }

    /** 스크린샷 테스트용: 가짜 AI 로 컨테이너를 교체한다. */
    fun replaceContainer(c: AppContainer) { container = c }
}

val Context.container: AppContainer get() = (applicationContext as EmberApp).container
