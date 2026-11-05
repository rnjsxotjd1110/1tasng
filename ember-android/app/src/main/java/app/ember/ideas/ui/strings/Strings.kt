package app.ember.ideas.ui.strings

import androidx.compose.runtime.staticCompositionLocalOf
import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.LanguageMode
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.data.ThemeMode
import app.ember.ideas.handoff.HandoffGoal
import app.ember.ideas.ui.screens.LibraryFilter
import java.util.Locale

/**
 * 화면 문구. 언어별 구현이 모든 항목을 갖추어야 컴파일되므로 번역 누락이 생기지 않는다.
 */
abstract class Strings {
    abstract val isKorean: Boolean

    // 공통
    abstract val back: String; abstract val next: String; abstract val skip: String; abstract val close: String
    abstract val cancel: String; abstract val save: String; abstract val delete: String; abstract val retry: String
    abstract val copy: String; abstract val copied: String; abstract val share: String; abstract val more: String
    abstract val clear: String; abstract val undo: String; abstract val reset: String; abstract val stop: String
    abstract val sample: String; abstract val working: String; abstract val current: String; abstract val set: String
    abstract val notSet: String; abstract val later: String; abstract val paste: String; abstract val toggleVisibility: String
    abstract fun relativeTime(ts: Long): String
    abstract fun charCount(n: Int): String
    abstract fun compactNumber(n: Long): String
    abstract fun money(usd: Double): String

    // 오류
    abstract fun errorTitle(e: AiError): String
    abstract fun errorBody(e: AiError): String
    abstract val fixKey: String

    // 온보딩
    abstract val onb1Title: String; abstract val onb1Body: String
    abstract val onb2Title: String; abstract val onb2Body: String
    abstract val onb3Title: String; abstract val onb3Body: String
    abstract val getStarted: String

    // API 키
    abstract val keyTitleSettings: String; abstract val keyHeadline: String; abstract val keyBody: String
    abstract fun keyCurrent(hint: String): String
    abstract val keyFormatError: String; abstract val keyModelError: String
    abstract val keySecureNote: String; abstract val keyMemoryNote: String
    abstract val keyGuideTitle: String; abstract val keyGuideSteps: List<String>
    abstract val openConsole: String; abstract val keyCostNote: String
    abstract val keyConnect: String; abstract val keyConnected: String; abstract val removeKey: String

    // 홈
    abstract fun greeting(hour: Int): String
    abstract val homeHeadline: String; abstract val homeSub: String; abstract val pickKind: String
    abstract fun kindLabel(k: ProjectKind): String
    abstract fun defaultProjectTitle(k: ProjectKind): String
    abstract val seedPlaceholder: String; abstract val inspireMe: String; abstract val inspirations: List<String>
    abstract val pickKindFirst: String; abstract val connectToStart: String; abstract val startDiscovery: String
    abstract val noKeyHint: String; abstract val continueSection: String; abstract val recentDocs: String
    abstract val seeAll: String; abstract val setProfileShort: String; abstract val myProfile: String
    abstract val profileTipTitle: String; abstract val profileTipBody: String
    abstract fun stageLabel(stage: ProjectStage): String
    abstract fun answeredN(n: Int): String
    abstract fun ideasCount(n: Int): String

    // 인터뷰
    abstract fun questionN(n: Int): String
    abstract fun answersSoFar(n: Int): String
    abstract val multiHint: String; abstract val singleHint: String
    abstract val customAnswer: String; abstract val customPlaceholder: String
    abstract val previousQuestion: String; abstract val skipped: String
    abstract val firstQuestionTitle: String; abstract val nextQuestionTitle: String
    abstract val questionThinkingLines: List<String>
    abstract val showIdeasNow: String; abstract val backToIdeasShort: String
    abstract val answersTitle: String; abstract val decisionsTitle: String
    abstract val resumeTitle: String; abstract val resumeBody: String; abstract val resume: String

    // 아이디어
    abstract val ideaThinkingTitle: String; abstract val ideaThinkingLines: List<String>
    abstract fun allIdeas(n: Int): String
    abstract fun savedIdeas(n: Int): String
    abstract val latestIdeas: String; abstract val earlierIdeas: String
    abstract fun variationOf(label: String): String
    abstract val noSavedIdeas: String; abstract val ideasFooterHint: String
    abstract val moreQuestions: String; abstract val moreIdeas: String
    abstract val docReadyBanner: String; abstract val chosenIdea: String
    abstract fun difficulty(d: Int): String
    abstract val saveIdea: String; abstract val unsave: String
    abstract val fieldCoreHook: String; abstract val fieldFeatures: String; abstract val fieldUnique: String
    abstract val fieldAudience: String; abstract val fieldMonetization: String; abstract val fieldFit: String
    abstract val fieldScope: String; abstract val fieldDevTime: String; abstract val fieldDifficulty: String
    abstract val designThis: String; abstract val vary: String; abstract val combine: String
    abstract val sendIdeaToClaude: String
    abstract val varyTitle: String; abstract fun varySub(title: String): String
    abstract val varyPresets: List<String>; abstract val varyPlaceholder: String; abstract val makeVariations: String
    abstract val combineTitle: String; abstract fun combineSub(title: String): String

    // 설계
    abstract val designSetupTitle: String; abstract fun designSetupSub(title: String): String
    abstract fun depthTitle(d: DocDepth): String
    abstract fun depthBody(d: DocDepth): String
    abstract val askDesignQuestions: String; abstract val askDesignQuestionsBody: String
    abstract val startDesign: String; abstract val designFirstTitle: String
    abstract val designThinkingLines: List<String>; abstract val writeDocNow: String

    // 설계서
    abstract val writingTitle: String; abstract val revisingTitle: String; abstract val docThinkingLines: List<String>
    abstract fun versionLabel(n: Int): String
    abstract val incompleteDoc: String; abstract val incomplete: String; abstract val regenerate: String
    abstract val regenerateAll: String; abstract val regenerateBody: String
    abstract val followWriting: String; abstract val revise: String; abstract val continueInClaude: String
    abstract val reviseTitle: String; abstract val reviseSub: String; abstract val revisePresets: List<String>
    abstract val revisePlaceholder: String; abstract val applyRevision: String
    abstract val versionsTitle: String; abstract val versionsSub: String; abstract val restore: String
    abstract fun restoredNote(n: Int): String
    abstract val copyDocument: String; abstract val viewIdeas: String; abstract val viewDocument: String

    // Claude 로 넘기기
    abstract val handoffTitle: String; abstract val handoffSubApp: String; abstract val handoffSubWeb: String
    abstract fun goalTitle(g: HandoffGoal): String
    abstract fun goalBody(g: HandoffGoal): String
    abstract val includeLabel: String; abstract val includeAnswers: String; abstract val includeDocument: String
    abstract val includeProfile: String; abstract val handoffExtraPlaceholder: String; abstract val previewPrompt: String
    abstract val openClaudeApp: String; abstract val openClaudeWeb: String; abstract val copyPrompt: String
    abstract val openedClaudeApp: String; abstract val openedClaudeWeb: String; abstract val openedPaste: String
    abstract val openFailed: String

    // 프로젝트 관리
    abstract val rename: String; abstract val renamePlaceholder: String
    abstract val favorite: String; abstract val unfavorite: String
    abstract val deleteTitle: String; abstract fun deleteBody(title: String): String
    abstract fun deletedProject(title: String): String
    abstract val projectMissingTitle: String; abstract val projectMissingBody: String

    // 보관함
    abstract val libraryTitle: String; abstract val searchPlaceholder: String
    abstract fun tabProjects(n: Int): String
    abstract fun tabSavedIdeas(n: Int): String
    abstract fun filterLabel(f: LibraryFilter): String
    abstract val libraryEmptyTitle: String; abstract val libraryEmptyBody: String; abstract val startNew: String
    abstract val noResultsTitle: String; abstract val noResultsBody: String
    abstract val noSavedTitle: String; abstract val noSavedBody: String

    // 설정
    abstract val settingsTitle: String
    abstract val groupClaude: String; abstract val groupPersonal: String; abstract val groupUsage: String
    abstract val groupData: String; abstract val groupAbout: String
    abstract val apiKey: String; abstract val notConnected: String; abstract val model: String
    abstract fun modelName(m: ClaudeModel): String
    abstract fun modelBody(m: ClaudeModel): String
    abstract val deepThinking: String; abstract val deepThinkingBody: String
    abstract val devProfile: String; abstract val devProfileBody: String
    abstract val language: String; abstract val languageBody: String
    abstract fun languageName(l: LanguageMode): String
    abstract val theme: String
    abstract fun themeName(t: ThemeMode): String
    abstract val haptics: String
    abstract val usageRequests: String; abstract val usageTokens: String; abstract val usageCost: String
    abstract val usageNote: String; abstract val resetUsage: String; abstract val resetUsageBody: String
    abstract val exportAll: String; abstract val exportAllBody: String; abstract val addSample: String
    abstract val sampleAdded: String; abstract val deleteAll: String; abstract val deleteAllBody: String
    abstract val deletedAll: String; abstract val about: String; abstract val privacyNote: String
    abstract val aboutBody: String; abstract val licenses: String; abstract val trademarkNote: String

    // 프로필
    abstract val profileIntro: String; abstract val profileExperience: String; abstract val experienceOptions: List<String>
    abstract val profileTools: String; abstract val toolOptions: List<String>; abstract val addToolPlaceholder: String
    abstract val profileTeam: String; abstract val teamOptions: List<String>
    abstract val profileNotes: String; abstract val profileNotesPlaceholder: String


    // 2차 개선
    abstract fun questionOf(n: Int, total: Int): String
    abstract val waitingNote: String
    abstract val doLater: String
    abstract val designThisShort: String
    abstract val details: String
    abstract val tryDifferently: String
    abstract val brainstormWithClaude: String
    abstract fun decisionsCount(n: Int): String
    abstract fun sectionProgress(done: Int, total: Int): String
    abstract val writingNote: String
    abstract val claudeWebNote: String
    abstract fun handoffDocName(title: String): String
    abstract val pin: String
    abstract val unpin: String
    abstract fun costApprox(usd: Double): String
    abstract fun costPerDiscovery(cost: String, model: String): String
    abstract fun depthMeta(d: DocDepth, cost: String, minutes: String): String
    abstract fun reviseCost(cost: String): String
    abstract fun modelShort(m: ClaudeModel): String
    abstract fun modelSetCost(cost: String): String
    abstract val quickIdeas: String
    abstract val demoTry: String
    abstract val demoBanner: String
    abstract val demoConnect: String
    abstract val demoTitle: String
    abstract val keyStoredNote: String
    abstract val profileButton: String
    abstract fun profileSummary(experience: String, tools: List<String>): String
    abstract val recommended: String
    abstract val moreActions: String
    abstract fun minutes(lo: Int, hi: Int): String
    abstract val nextQuestionTag: String
    abstract val newIdeaHeadline: String
    abstract val fieldSimilar: String
    abstract val fieldRisks: String
    abstract val fieldValidation: String
    abstract val easiest: String
    abstract val exportClaudeMdBody: String
    abstract val monthlyBudget: String
    abstract val budgetBody: String
    abstract val budgetOptionsUsd: List<Double>
    abstract fun budgetLabel(usd: Double): String
    abstract fun thisMonth(used: String, budget: String?): String
    abstract fun budgetWarn(pct: Int): String
    abstract fun writingNow(title: String): String
    abstract fun remaining(min: Int): String
    abstract fun yourAnswer(a: String): String
    abstract val previousShort: String
    abstract val compare: String
    abstract val compareTitle: String
    abstract val compareSub: String
    abstract fun openIdea(title: String): String
    abstract fun goalShort(g: HandoffGoal): String
    abstract val exportClaudeMd: String
    abstract val errorSafeNote: String

    // 탭
    abstract val tabHome: String; abstract val tabLibrary: String; abstract val tabSettings: String
}

val LocalStrings = staticCompositionLocalOf<Strings> { KoStrings }

fun stringsFor(mode: LanguageMode): Strings = when (mode) {
    LanguageMode.KO -> KoStrings
    LanguageMode.EN -> EnStrings
    LanguageMode.AUTO -> if (Locale.getDefault().language == "ko") KoStrings else EnStrings
}

internal fun minutesAgo(ts: Long): Long = ((System.currentTimeMillis() - ts) / 60_000L).coerceAtLeast(0)
