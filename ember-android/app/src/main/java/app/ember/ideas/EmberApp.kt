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
    val credits = app.ember.ideas.account.CreditAccount(settings, integrity = { nonce -> app.ember.ideas.account.Integrity.token(context, nonce) })
    val ai: AiService = aiOverride ?: ClaudeAiService {
        val st = settings.settings.value
        when {
            st.usingCredits -> settings.creditToken()?.let { app.ember.ideas.ai.Endpoint(it, app.ember.ideas.account.ServerConfig.serverUrl) }
            else -> settings.apiKey()?.let { app.ember.ideas.ai.Endpoint(it) }
        }
    }
    val engine = ProjectEngine(store, settings, ai, scope)
    val billing = app.ember.ideas.account.BillingManager(context, credits, scope)

    val images = app.ember.ideas.data.ImageStore(context)

    /** 원석함의 메모. */
    val memos = app.ember.ideas.data.ListStore(java.io.File(context.filesDir, "memos.json"), app.ember.ideas.data.Memo.serializer(), scope) { it.id }
    /** 미리 정한 답 묶음(거푸집). */
    val molds = app.ember.ideas.data.ListStore(java.io.File(context.filesDir, "molds.json"), app.ember.ideas.data.Mold.serializer(), scope) { it.id }
    /** 같은 Wi-Fi 의 PC 브리지(작업대). */
    val workbench by lazy { app.ember.ideas.bridge.Workbench(context, settings, scope) }

    init {
        store.loadBlocking()
        memos.load()
        molds.load()
        // 원석(메모)에 붙인 사진도 쓰는 중인 이미지로 친다.
        // 저장 파일이 손상되어 빈 채로 시작했다면 지우지 않는다(나중에 원본을 복구할 때 이미지가 남아 있게).
        if (store.corruptBackup == null && !memos.corrupt) images.cleanup(store.projects.value.flatMap { it.images }.toSet() + memos.items.value.mapNotNull { it.imagePath })
        val prefs = context.getSharedPreferences("ember_meta", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("sample_added", false)) {
            store.upsert(SampleProject.create(context))
            if (store.get("sample_ko") != null) store.upsert(SampleProject.koreanApp())
            prefs.edit().putBoolean("sample_added", true).apply()
        }
    }
}

class EmberApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        app.ember.ideas.report.CrashLog.install(this)
        if (!::container.isInitialized) container = AppContainer(this)
        app.ember.ideas.work.WorkKeeper(this, container).install()
    }

    /** 스크린샷 테스트용: 가짜 AI 로 컨테이너를 교체한다. */
    fun replaceContainer(c: AppContainer) { container = c }
}

val Context.container: AppContainer get() = (applicationContext as EmberApp).container
