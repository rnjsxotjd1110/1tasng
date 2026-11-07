package app.ember.ideas.handoff

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import app.ember.ideas.ai.Protocol
import app.ember.ideas.data.DevProfile
import app.ember.ideas.data.Idea
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectKind
import java.io.File

/** Claude 로 넘길 때의 목적. 목적에 따라 첫 요청 문장이 달라진다. */
enum class HandoffGoal { CONTINUE_DESIGN, START_BUILD, REVIEW, BRAINSTORM }

data class HandoffOptions(
    val goal: HandoffGoal,
    val includeAnswers: Boolean = true,
    val includeDocument: Boolean = true,
    val includeProfile: Boolean = true,
    val extra: String = "",
)

/** Claude 앱(또는 claude.ai)으로 작업을 이어 가기 위한 프롬프트를 만들고 연다. */
object Handoff {

    const val CLAUDE_PACKAGE = "com.anthropic.claude"
    private const val CLAUDE_NEW_CHAT = "https://claude.ai/new"
    /** URL 쿼리로 넘길 수 있는 안전한 최대 길이(인코딩 후). 넘으면 클립보드로 전달한다. */
    private const val MAX_URL_PROMPT = 6000

    /**
     * Claude 가 이어서 질문할 때 지킬 규칙. 사용자가 "b+e" 처럼 선택지를 섞어 답해도 알아듣게 한다.
     * (Claude 앱·claude.ai 대화와 Claude Code 의 질문 카드 모두에 해당한다.)
     */
    fun questionRules(korean: Boolean): String = if (korean) """
## 질문 규칙
- 결정이 필요하면 한 번에 하나씩 묻고, 선택지마다 A, B, C … 기호를 붙여 주세요(질문 카드를 쓸 때는 선택지 이름 앞에 "A. " 처럼 기호를 붙여 주세요).
- 둘 이상을 함께 고르는 것이 자연스러운 질문은 그렇다고 알려 주고, 질문 카드라면 여러 개 선택(multiSelect)을 켜 주세요.
- 사용자가 "b+e", "B, E", "b와 e", "2 4" 처럼 기호나 번호로 답하면 그 선택지를 모두 고른 것으로 이해하고, 무엇을 골랐는지 한 줄로 확인한 뒤 진행해 주세요.
- "B인데 더 어둡게" 처럼 기호와 설명을 섞어 답하면 그 선택지를 바탕으로 설명을 반영해 주세요.
""".trim() else """
## Question rules
- Ask one decision at a time and label every option A, B, C … (in question cards, start each option label with "A. " and so on).
- When picking several options makes sense, say so, and turn on multi-select in question cards.
- If I answer with letters or numbers such as "b+e", "B, E", "b and e" or "2 4", treat it as choosing all of those options; confirm in one line what you understood, then continue.
- If I mix a letter with a comment ("B but darker"), start from that option and apply the comment.
""".trim()

    fun buildPrompt(project: Project, idea: Idea?, profile: DevProfile, options: HandoffOptions, korean: Boolean): String {
        val doc = project.design?.latest?.markdown
        val sb = StringBuilder()
        val kindText = when (project.kind) {
            ProjectKind.GAME -> if (korean) "게임" else "game"
            ProjectKind.APP -> if (korean) "앱" else "app"
            ProjectKind.WEB -> if (korean) "웹 서비스" else "web service"
            ProjectKind.ANY -> if (korean) "프로젝트" else "project"
        }
        if (korean) {
            sb.appendLine("Ember 앱에서 함께 정리한 $kindText 기획을 이어서 작업하고 싶어요.")
        } else {
            sb.appendLine("I'd like to continue a $kindText concept I developed in the Ember app.")
        }
        sb.appendLine()
        sb.appendLine(goalLine(options.goal, project.kind, doc != null, korean))
        if (options.extra.isNotBlank()) {
            sb.appendLine()
            sb.appendLine((if (korean) "추가 요청: " else "Additional request: ") + options.extra.trim())
        }
        sb.appendLine()
        sb.appendLine(questionRules(korean))
        if (idea != null) {
            sb.appendLine()
            sb.appendLine(if (korean) "## 고른 아이디어" else "## Chosen idea")
            sb.appendLine(Protocol.ideaBrief(idea))
        }
        if (options.includeAnswers && project.turns.any { it.answer != null && !it.answer.skipped }) {
            sb.appendLine()
            sb.appendLine(if (korean) "## 아이디어 탐색 답변" else "## Discovery answers")
            sb.appendLine(Protocol.interviewBrief(project.turns))
            val designTurns = project.design?.turns.orEmpty()
            if (designTurns.any { it.answer != null && !it.answer.skipped }) {
                sb.appendLine()
                sb.appendLine(if (korean) "## 설계 결정" else "## Design decisions")
                sb.appendLine(Protocol.interviewBrief(designTurns))
            }
        }
        if (options.includeProfile && !profile.isEmpty()) {
            sb.appendLine()
            sb.appendLine(Protocol.profileBlock(profile))
        }
        if (options.includeDocument && doc != null) {
            sb.appendLine()
            sb.appendLine(if (korean) "## 설계서" else "## Design document")
            sb.appendLine(doc)
        }
        return sb.toString().trim()
    }

    private fun goalLine(goal: HandoffGoal, kind: ProjectKind, hasDoc: Boolean, korean: Boolean): String = when (goal) {
        HandoffGoal.CONTINUE_DESIGN -> if (korean)
            "아래 ${if (hasDoc) "설계서" else "아이디어"}를 바탕으로 설계를 더 구체적으로 다듬어 주세요. 먼저 빠졌거나 모호한 부분을 짚고, 결정이 필요한 것은 선택지를 주면서 하나씩 질문해 주세요."
        else "Please help me refine the ${if (hasDoc) "design document" else "idea"} below. Start by pointing out gaps or vague parts, then ask me about open decisions one at a time with options."
        HandoffGoal.START_BUILD -> if (korean)
            "아래 설계를 바탕으로 실제 개발을 시작하고 싶어요. 먼저 ${if (kind == ProjectKind.GAME) "엔진과 " else ""}기술 스택을 확인하고, 폴더 구조와 첫 마일스톤의 작업 목록을 만든 뒤, 첫 작업부터 코드로 구현해 주세요."
        else "I want to start building this. First confirm the ${if (kind == ProjectKind.GAME) "engine and " else ""}tech stack, propose a folder structure and a task list for the first milestone, then implement the first task in code."
        HandoffGoal.REVIEW -> if (korean)
            "아래 기획을 출시를 앞둔 프로듀서의 시선으로 냉정하게 검토해 주세요. 시장성, 차별점, 개발 범위의 현실성, 가장 큰 위험 3가지와 각각의 해결책을 알려 주세요."
        else "Review the concept below critically, like a producer before launch: market fit, differentiation, scope realism, and the three biggest risks with mitigations."
        HandoffGoal.BRAINSTORM -> if (korean)
            "아래 아이디어를 출발점으로 자유롭게 브레인스토밍해 주세요. 핵심 재미를 더 강하게 만드는 방법과 의외의 변형 아이디어를 제안해 주세요."
        else "Use the idea below as a starting point for a free brainstorm. Suggest ways to strengthen its core appeal and some surprising variations."
    }

    /** 작업대(PC 브리지)로 보낼 것. */
    enum class BenchWhat { START, NEXT, FILES }

    /**
     * 작업대로 보낼 요청을 만든다. 설계서는 docs/DESIGN.md, 작업 규칙은 CLAUDE.md 로 함께 보낸다.
     * '다음 작업 하나'는 CLAUDE.md 를 덮어쓰지 않으려고 설계서만 보낸다(사용자가 고쳤을 수 있다).
     */
    fun benchRequest(project: Project, idea: Idea?, profile: DevProfile, what: BenchWhat, mode: String, folder: String, korean: Boolean): app.ember.ideas.bridge.BridgeApi.SendRequest {
        val doc = project.design?.latest?.markdown.orEmpty()
        val title = project.design?.latest?.markdown?.let { Protocol.documentTitle(it) } ?: idea?.title ?: project.title
        val design = app.ember.ideas.bridge.BridgeApi.FileEntry("docs/DESIGN.md", doc)
        val claudeMd = app.ember.ideas.bridge.BridgeApi.FileEntry("CLAUDE.md", buildClaudeMd(project, idea, profile, korean).replace(Regex("(?s)\n## (설계서|Design document)\n.*$"), "\n" + if (korean) "## 설계서\n\ndocs/DESIGN.md 를 읽어 주세요.\n" else "## Design document\n\nRead docs/DESIGN.md.\n"))
        val prompt = when (what) {
            BenchWhat.START -> if (korean)
                "이 폴더의 CLAUDE.md 와 docs/DESIGN.md 를 먼저 모두 읽어 주세요. 그다음 ${if (project.kind == ProjectKind.GAME) "엔진과 " else ""}기술 스택을 확인하고, 폴더 구조와 첫 마일스톤의 작업 목록을 만든 뒤 첫 작업부터 구현해 주세요. 설계와 다르게 해야 하면 먼저 물어봐 주세요."
            else "Read CLAUDE.md and docs/DESIGN.md in this folder first. Then confirm the ${if (project.kind == ProjectKind.GAME) "engine and " else ""}tech stack, set up the folder structure and a task list for the first milestone, and implement the first task. Ask before deviating from the design."
            BenchWhat.NEXT -> if (korean)
                "docs/DESIGN.md 의 개발 로드맵과 지금까지 만든 코드를 비교해서, 아직 하지 않은 다음 작업 하나만 골라 구현해 주세요. 끝나면 무엇을 했고 다음에 무엇을 하면 좋을지 짧게 알려 주세요."
            else "Compare the roadmap in docs/DESIGN.md with the code so far, pick the single next task that isn't done yet and implement it. When finished, briefly say what you did and what should come next."
            BenchWhat.FILES -> if (korean)
                "CLAUDE.md 와 docs/DESIGN.md 를 읽고, 이 프로젝트를 어떻게 이해했는지와 첫 마일스톤 계획을 짧게 정리해 주세요. 아직 코드는 쓰지 말아 주세요."
            else "Read CLAUDE.md and docs/DESIGN.md, then summarize how you understand the project and plan the first milestone. Don't write code yet."
        }
        // '다음 작업 하나'는 CLAUDE.md 를 보내지 않으므로 질문 규칙을 프롬프트에 직접 붙인다.
        val fullPrompt = if (what == BenchWhat.NEXT) prompt + "\n\n" + questionRules(korean) else prompt
        val files = when (what) {
            BenchWhat.NEXT -> listOf(design)
            else -> listOf(design, claudeMd)
        }
        return app.ember.ideas.bridge.BridgeApi.SendRequest(title = title, mode = mode, prompt = fullPrompt, files = if (doc.isBlank()) emptyList() else files, folder = folder)
    }

    /** Claude Code 가 저장소 루트에서 읽는 CLAUDE.md 형식으로 설계를 정리한다. */
    fun buildClaudeMd(project: Project, idea: Idea?, profile: DevProfile, korean: Boolean): String = buildString {
        val title = idea?.title ?: project.title
        appendLine("# $title")
        appendLine()
        if (korean) {
            appendLine("이 저장소는 Ember 에서 설계한 프로젝트예요. 작업을 시작하기 전에 아래 설계서를 모두 읽고, 설계서의 '개발 로드맵' 순서대로 진행해 주세요.")
            appendLine()
            appendLine("## 작업 규칙")
            appendLine("- 설계서와 다르게 구현해야 하면 먼저 이유를 설명하고 확인을 받아 주세요.")
            appendLine("- 마일스톤마다 실행 가능한 상태를 유지하고, 끝나면 무엇을 했는지 짧게 보고해 주세요.")
            appendLine("- 정해지지 않은 부분은 설계서의 (제안) 표시를 기본값으로 삼아 주세요.")
            appendLine()
            appendLine(questionRules(true))
        } else {
            appendLine("This repository implements a project designed in Ember. Read the full design doc below before starting, and follow its roadmap in order.")
            appendLine()
            appendLine("## Working rules")
            appendLine("- If you need to deviate from the design, explain why and ask first.")
            appendLine("- Keep every milestone runnable and report briefly when one is done.")
            appendLine("- Treat items marked (suggested) as defaults for open decisions.")
            appendLine()
            appendLine(questionRules(false))
        }
        if (!profile.isEmpty()) {
            appendLine()
            appendLine(Protocol.profileBlock(profile))
        }
        project.design?.latest?.markdown?.let {
            appendLine()
            appendLine(if (korean) "## 설계서" else "## Design document")
            appendLine()
            appendLine(it.replace(Regex("(?m)^#"), "##"))
        }
    }

    fun isClaudeInstalled(context: Context): Boolean = runCatching {
        context.packageManager.getPackageInfo(CLAUDE_PACKAGE, 0); true
    }.getOrDefault(false)

    fun copy(context: Context, label: String, text: String) {
        val cm = context.getSystemService(ClipboardManager::class.java)
        cm?.setPrimaryClip(ClipData.newPlainText(label, text))
    }

    enum class OpenResult { CLAUDE_APP, WEB_WITH_PROMPT, WEB_PASTE, FAILED }

    /**
     * Claude 앱이 있으면 공유 인텐트로 프롬프트를 그대로 넘긴다.
     * 없으면 claude.ai 새 대화를 연다(짧으면 프롬프트를 채워서, 길면 클립보드에 복사한 뒤).
     * 어떤 경우든 프롬프트는 클립보드에도 복사해 둔다.
     */
    fun open(context: Context, prompt: String): OpenResult {
        copy(context, "Ember → Claude", prompt)
        if (isClaudeInstalled(context)) {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, prompt)
                setPackage(CLAUDE_PACKAGE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(send)
                return OpenResult.CLAUDE_APP
            } catch (_: ActivityNotFoundException) {
                context.packageManager.getLaunchIntentForPackage(CLAUDE_PACKAGE)?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    runCatching { context.startActivity(it); return OpenResult.WEB_PASTE }
                }
            }
        }
        val encoded = Uri.encode(prompt)
        val (uri, result) = if (encoded.length <= MAX_URL_PROMPT) {
            Uri.parse("$CLAUDE_NEW_CHAT?q=$encoded") to OpenResult.WEB_WITH_PROMPT
        } else {
            Uri.parse(CLAUDE_NEW_CHAT) to OpenResult.WEB_PASTE
        }
        return try {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result
        } catch (_: ActivityNotFoundException) {
            OpenResult.FAILED
        }
    }

    fun safeFileName(title: String): String =
        title.replace(Regex("[\\\\/:*?\"<>|\\n\\r\\t]"), " ").trim().replace(Regex("\\s+"), "_").take(48).ifEmpty { "ember" }

    /** Markdown 파일을 만들어 공유 시트로 보낸다. */
    fun shareMarkdown(context: Context, title: String, markdown: String, chooserTitle: String, fileName: String? = null) {
        val dir = File(context.cacheDir, "exports").apply { mkdirs() }
        val file = File(dir, fileName ?: (safeFileName(title) + ".md"))
        file.writeText(markdown)
        val uri = FileProvider.getUriForFile(context, context.packageName + ".files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/markdown"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(send, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun shareText(context: Context, text: String, chooserTitle: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(send, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
