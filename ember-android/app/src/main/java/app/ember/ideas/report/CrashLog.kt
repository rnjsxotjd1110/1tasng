package app.ember.ideas.report

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import app.ember.ideas.BuildConfig
import app.ember.ideas.account.ServerConfig
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

/**
 * 앱이 갑자기 꺼졌을 때 오류 내용을 휴대폰에만 남기고, 사용자가 원할 때 메일·공유로 보내게 한다.
 * 외부 수집 서비스를 쓰지 않으며 프로젝트 내용·키는 기록하지 않는다.
 */
object CrashLog {
    private const val DIR = "crash"
    private const val MAX_FILES = 5

    fun install(context: Context) {
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            runCatching { write(app, thread, error) }
            previous?.uncaughtException(thread, error)
        }
    }

    private fun dir(context: Context) = File(context.filesDir, DIR).apply { mkdirs() }

    internal fun write(context: Context, thread: Thread, error: Throwable) {
        val sw = StringWriter()
        error.printStackTrace(PrintWriter(sw))
        val text = buildString {
            appendLine("Ember ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            appendLine("Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Thread: ${thread.name}")
            appendLine("Time: ${java.time.Instant.now()}")
            appendLine()
            append(sw.toString().take(30_000))
        }
        val d = dir(context)
        File(d, "crash-${System.currentTimeMillis()}.txt").writeText(text)
        d.listFiles()?.sortedByDescending { it.name }?.drop(MAX_FILES)?.forEach { it.delete() }
    }

    fun files(context: Context): List<File> = dir(context).listFiles()?.filter { it.name.startsWith("crash-") }?.sortedByDescending { it.name }.orEmpty()

    /** 아직 사용자에게 알리지 않은 오류가 있는지. */
    fun hasUnseen(context: Context): Boolean {
        val seen = context.getSharedPreferences("ember_meta", Context.MODE_PRIVATE).getString("crash_seen", "") ?: ""
        return files(context).firstOrNull()?.name?.let { it > seen } == true
    }

    fun markSeen(context: Context) {
        val latest = files(context).firstOrNull()?.name ?: return
        context.getSharedPreferences("ember_meta", Context.MODE_PRIVATE).edit().putString("crash_seen", latest).apply()
    }

    /** 최근 오류 기록을 한 파일로 묶어 메일(설정된 경우) 또는 공유 화면으로 보낸다. */
    fun send(context: Context, chooserTitle: String) {
        val logs = files(context)
        if (logs.isEmpty()) return
        val out = File(File(context.cacheDir, "exports").apply { mkdirs() }, "ember-crash-report.txt")
        out.writeText(logs.joinToString("\n\n==========\n\n") { it.readText() })
        val uri = FileProvider.getUriForFile(context, context.packageName + ".files", out)
        val email = ServerConfig.values.reportEmail
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Ember ${BuildConfig.VERSION_NAME} crash report")
            putExtra(Intent.EXTRA_TEXT, logs.first().readText().take(4_000))
            if (email.isNotBlank()) putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        markSeen(context)
    }

    fun clear(context: Context) {
        files(context).forEach { it.delete() }
    }
}
