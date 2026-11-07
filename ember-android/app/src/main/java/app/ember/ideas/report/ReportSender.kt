package app.ember.ideas.report

import android.content.Context
import android.content.Intent
import android.net.Uri
import app.ember.ideas.BuildConfig
import app.ember.ideas.account.CreditAccount
import app.ember.ideas.account.ServerConfig
import app.ember.ideas.data.Idea
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectStage

/** 신고 대상 종류. 서버에 그대로 보내는 값이다. */
enum class ReportKind(val wire: String) { QUESTION("question"), IDEA("idea"), DOCUMENT("document"), OTHER("other") }

/** 신고할 내용 묶음. [content] 는 실제로 화면에 보였던 AI 결과 그대로다. */
data class ReportTarget(val kind: ReportKind, val content: String)

object ReportSender {

    /** 프로젝트의 현재 단계에서 사용자가 보고 있던 AI 결과를 고른다. */
    fun targetFor(project: Project, stage: ProjectStage): ReportTarget = when (stage) {
        ProjectStage.INTERVIEW -> ReportTarget(ReportKind.QUESTION, project.turns.lastOrNull()?.let { questionText(it.question) }.orEmpty())
        ProjectStage.DESIGN_INTERVIEW -> ReportTarget(ReportKind.QUESTION, project.design?.turns?.lastOrNull()?.let { questionText(it.question) }.orEmpty())
        ProjectStage.IDEAS -> ReportTarget(ReportKind.IDEA, project.ideaBatches.firstOrNull()?.ideas.orEmpty().joinToString("\n\n") { ideaText(it) })
        ProjectStage.DOCUMENT -> ReportTarget(ReportKind.DOCUMENT, project.design?.latest?.markdown.orEmpty())
    }

    fun forIdea(idea: Idea) = ReportTarget(ReportKind.IDEA, ideaText(idea))

    private fun questionText(q: app.ember.ideas.data.Question): String =
        q.title + "\n" + q.subtitle + "\n" + q.options.joinToString("\n") { "- ${it.label}: ${it.description}" }

    private fun ideaText(i: Idea): String = "${i.title}\n${i.logline}\n${i.coreHook}\n${i.similarWorks.joinToString("; ")}"

    /** 메일로 보낼 수 있는지(서버가 없을 때의 대안). */
    val canEmail: Boolean get() = ServerConfig.values.reportEmail.isNotBlank()

    /**
     * 서버가 있으면 서버로, 없으면 메일 앱으로 보낸다.
     * @return 메일 앱을 열었으면 true(사용자가 직접 보내야 한다), 서버로 보냈으면 false.
     */
    suspend fun send(context: Context, credits: CreditAccount, target: ReportTarget, reason: String, note: String): Boolean {
        // 크레딧 계정에 로그인해 있을 때만 서버로 보낸다(신고하려고 계정을 만들지 않는다). 서버가 받지 않으면 메일로 보낸다.
        if (ServerConfig.creditsEnabled && credits.signedIn) {
            val sent = runCatching { credits.report(target.kind.wire, reason, target.content, note, BuildConfig.VERSION_NAME) }.isSuccess
            if (sent) return false
        }
        val body = buildString {
            appendLine("[Ember ${BuildConfig.VERSION_NAME}] ${target.kind.wire}")
            appendLine("Reason: $reason")
            if (note.isNotBlank()) appendLine("Note: $note")
            appendLine()
            appendLine(target.content.take(6_000))
        }
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:")).apply {
            putExtra(Intent.EXTRA_EMAIL, arrayOf(ServerConfig.values.reportEmail).filter { it.isNotBlank() }.toTypedArray())
            putExtra(Intent.EXTRA_SUBJECT, "Ember AI content report: $reason")
            putExtra(Intent.EXTRA_TEXT, body)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val chooser = Intent.createChooser(intent, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
        return true
    }
}
