package app.ember.ideas.work

import android.app.Activity
import android.app.Application
import android.os.Bundle
import app.ember.ideas.AppContainer
import app.ember.ideas.ui.strings.stringsFor
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 진행 중인 작업이 있으면 포그라운드 서비스를 켜 두고, 앱 밖에 있을 때 작업이 끝나면 알림을 보낸다.
 */
class WorkKeeper(private val app: Application, private val container: AppContainer) {

    @Volatile private var started = 0
    val inForeground: Boolean get() = started > 0
    private var stopJob: Job? = null
    private var lastRunning: Set<String> = emptySet()

    fun install() {
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(a: Activity) { started++ }
            override fun onActivityStopped(a: Activity) { started = (started - 1).coerceAtLeast(0) }
            override fun onActivityCreated(a: Activity, b: Bundle?) = Unit
            override fun onActivityResumed(a: Activity) = Unit
            override fun onActivityPaused(a: Activity) = Unit
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) = Unit
            override fun onActivityDestroyed(a: Activity) = Unit
        })
        val scope = container.scope
        scope.launch {
            container.engine.ops.collect { ops ->
                val running = ops.filterValues { it.running }.keys
                if (running == lastRunning) return@collect
                lastRunning = running
                if (running.isNotEmpty()) {
                    stopJob?.cancel()
                    val s = strings()
                    Notifier.ensureChannels(app, s.notifChannelWork, s.notifChannelDone)
                    val title = container.store.get(running.first())?.title.orEmpty()
                    WorkService.start(app, s.notifWorking(running.size, title), s.notifWorkingBody)
                } else {
                    // 다음 단계 작업이 바로 이어질 수 있으니 잠깐 기다렸다가 끈다.
                    stopJob = scope.launch {
                        delay(1500)
                        WorkService.stop(app)
                    }
                }
            }
        }
        scope.launch {
            container.engine.finished.collect { e ->
                if (inForeground || !container.settings.settings.value.notifyDone) return@collect
                val s = strings()
                Notifier.ensureChannels(app, s.notifChannelWork, s.notifChannelDone)
                val title = container.store.get(e.projectId)?.title.orEmpty()
                if (e.error == null) Notifier.notifyDone(app, e.projectId, s.notifDone(e.kind), title)
                else Notifier.notifyDone(app, e.projectId, s.notifFailed, s.errorTitle(e.error))
            }
        }
    }

    private fun strings() = stringsFor(container.settings.settings.value.language)
}
