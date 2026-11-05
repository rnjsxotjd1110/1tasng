package app.ember.ideas.work

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import app.ember.ideas.R

/**
 * AI 작업이 진행되는 동안 앱 프로세스가 정리되지 않도록 붙잡아 두는 포그라운드 서비스.
 * 작업 자체는 ProjectEngine 이 하고, 이 서비스는 '진행 중' 알림만 띄운다.
 */
class WorkService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        val body = intent?.getStringExtra(EXTRA_BODY).orEmpty()
        val n = Notifier.workingNotification(this, title, body)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0
        runCatching { ServiceCompat.startForeground(this, Notifier.ID_WORKING, n, type) }
            .onFailure { stopSelf() }
        return START_NOT_STICKY
    }

    // Android 15 의 dataSync 시간 제한에 걸리면 조용히 멈춘다. 작업은 앱이 살아 있는 동안 계속된다.
    override fun onTimeout(startId: Int, fgsType: Int) { stopSelf() }

    companion object {
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"

        fun start(context: Context, title: String, body: String) {
            val i = Intent(context, WorkService::class.java).putExtra(EXTRA_TITLE, title).putExtra(EXTRA_BODY, body)
            // 앱이 백그라운드에서 서비스를 새로 시작할 수 없는 경우(Android 12+)는 무시한다.
            runCatching { ContextCompat.startForegroundService(context, i) }
        }

        fun stop(context: Context) {
            runCatching { context.stopService(Intent(context, WorkService::class.java)) }
        }
    }
}

/** 알림 채널과 알림 모양을 한곳에서 관리한다. */
object Notifier {
    const val ID_WORKING = 41
    const val CH_WORK = "work"
    const val CH_DONE = "done"
    const val EXTRA_PROJECT = "open_project"

    fun ensureChannels(context: Context, workName: String, doneName: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(android.app.NotificationManager::class.java) ?: return
        nm.createNotificationChannel(android.app.NotificationChannel(CH_WORK, workName, android.app.NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(android.app.NotificationChannel(CH_DONE, doneName, android.app.NotificationManager.IMPORTANCE_DEFAULT))
    }

    private fun openIntent(context: Context, projectId: String?): android.app.PendingIntent {
        val i = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .apply { if (projectId != null) putExtra(EXTRA_PROJECT, projectId) }
        return android.app.PendingIntent.getActivity(
            context, projectId?.hashCode() ?: 0, i,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun workingNotification(context: Context, title: String, body: String): Notification =
        NotificationCompat.Builder(context, CH_WORK)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFFF6A3D.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(0, 0, true)
            .setContentIntent(openIntent(context, null))
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()

    fun notifyDone(context: Context, projectId: String, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) return
        val n = NotificationCompat.Builder(context, CH_DONE)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFFF6A3D.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(openIntent(context, projectId))
            .build()
        runCatching { androidx.core.app.NotificationManagerCompat.from(context).notify(projectId.hashCode(), n) }
    }
}
