package app.ember.ideas.shots

import org.junit.Assert.assertEquals
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.performTouchInput
import app.ember.ideas.data.Memo
import app.ember.ideas.data.Mold
import app.ember.ideas.data.DepthMode
import app.ember.ideas.data.PresetAnswer
import app.ember.ideas.ui.screens.MoldScreen
import app.ember.ideas.ui.screens.TermsScreen
import app.ember.ideas.account.ServerConfig
import app.ember.ideas.data.Reference
import app.ember.ideas.SharedSeed
import app.ember.ideas.Incoming
import app.ember.ideas.ui.screens.PrivacyScreen
import app.ember.ideas.report.CrashLog
import android.app.Application
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.core.app.ApplicationProvider
import app.ember.ideas.AppContainer
import app.ember.ideas.EmberApp
import app.ember.ideas.FakeAi
import app.ember.ideas.MainTabs
import app.ember.ideas.ai.Protocol
import app.ember.ideas.ai.AiError
import app.ember.ideas.data.Usage
import app.ember.ideas.data.Answer
import app.ember.ideas.data.DesignState
import app.ember.ideas.data.DevProfile
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.IdeaBatch
import app.ember.ideas.data.LanguageMode
import app.ember.ideas.data.Project
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.data.SampleProject
import app.ember.ideas.data.ThemeMode
import app.ember.ideas.data.Turn
import app.ember.ideas.ui.screens.ApiKeyScreen
import app.ember.ideas.ui.screens.OnboardingScreen
import app.ember.ideas.ui.screens.ProfileScreen
import app.ember.ideas.ui.screens.project.ProjectScreen
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.strings.stringsFor
import app.ember.ideas.ui.theme.EmberTheme
import com.github.takahirom.roborazzi.captureScreenRoboImage
import kotlinx.coroutines.CompletableDeferred
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowLooper

/**
 * 주요 화면을 실제 Compose 렌더링으로 캡처한다. 결과는 app/build/shots 폴더의 PNG.
 * 사용성 평가 에이전트가 이 이미지를 보고 채점한다.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xhdpi", application = EmberApp::class)
class ScreenshotTest {

    @get:Rule val rule = createComposeRule()

    private lateinit var app: EmberApp
    private lateinit var ai: FakeAi
    private lateinit var c: AppContainer

    @Before fun setUp() {
        app = ApplicationProvider.getApplicationContext<Application>() as EmberApp
        app.filesDir.listFiles()?.forEach { it.deleteRecursively() }
        ai = FakeAi()
        c = AppContainer(app, ai)
        c.store.deleteAll()
        c.settings.setLanguage(LanguageMode.KO)
        app.replaceContainer(c)
    }

    private fun shot(name: String, advanceMs: Long = 1200) {
        if (rule.mainClock.autoAdvance) rule.waitForIdle()
        rule.mainClock.advanceTimeBy(advanceMs)
        ShadowLooper.idleMainLooper()
        rule.mainClock.advanceTimeBy(300)
        captureScreenRoboImage("build/shots/$name.png")
    }

    private fun setContent(theme: ThemeMode = ThemeMode.DARK, lang: LanguageMode = LanguageMode.KO, auto: Boolean = false, body: @Composable () -> Unit) {
        rule.mainClock.autoAdvance = auto
        rule.setContent {
            EmberTheme(theme) {
                CompositionLocalProvider(LocalStrings provides stringsFor(lang)) { body() }
            }
        }
    }

    private fun withKey() = c.settings.setApiKey("sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCD")

    /** 화면 글자에는 한국어 줄바꿈용 WORD JOINER 가 들어 있으므로 빼고 비교한다. */
    private fun hasPlainText(text: String) = androidx.compose.ui.test.SemanticsMatcher("text~$text") { node ->
        node.config.getOrElseNullable(androidx.compose.ui.semantics.SemanticsProperties.Text) { null }
            ?.any { it.text.replace("\u2060", "").contains(text) } == true
    }

    private fun click(text: String) {
        rule.onAllNodes(hasPlainText(text), useUnmergedTree = true).onFirst().performClick()
        if (rule.mainClock.autoAdvance) rule.waitForIdle() else rule.mainClock.advanceTimeBy(600)
    }

    // ------------------------------------------------------------ 데이터

    private fun turn(json: String, answer: Answer? = null): Turn {
        val r = Protocol.parseReply(json)
        return Turn(r.stage, r.progress, r.insight, r.question, answer)
    }

    private val q1 = FakeAi.question("무엇을 만들고 싶으세요?", stage = "종류", progress = 8, options = listOf("게임" to "🎮", "앱" to "📱", "웹 서비스" to "🌐"))
    private val q2 = FakeAi.question("주로 어디서 플레이하나요?", stage = "플랫폼", progress = 20, insight = "게임을 만들고 싶어 하시는군요.")
    private val q3 = """{"kind":"question","stage":"분위기","progress":42,"insight":"모바일에서 짧게 즐기는 게임을 원하고 있어요.","question":{"title":"어떤 분위기에 끌리나요?","subtitle":"아트와 사운드의 방향을 정하는 데 쓰여요.","multi_select":true,"options":[{"id":"a","label":"아늑하고 따뜻한","description":"코지 게임처럼 편안한 분위기","emoji":"🕯️"},{"id":"b","label":"몽환적인","description":"꿈속 같은 색감과 음악","emoji":"🌙"},{"id":"c","label":"긴장감 넘치는","description":"손에 땀을 쥐는 순간들","emoji":"⚡"},{"id":"d","label":"유쾌하고 엉뚱한","description":"웃음이 터지는 상황과 캐릭터","emoji":"🎈"},{"id":"e","label":"어둡고 진지한","description":"무게감 있는 이야기","emoji":"🌑"}],"allow_custom":true,"custom_hint":"예: 지브리 영화 같은 느낌"},"ideas_intro":"","ideas":[]}"""

    private fun interviewProject(): Project {
        val now = System.currentTimeMillis()
        return Project(
            id = "p_interview", title = "비 오는 날 아이디어", kind = ProjectKind.ANY, seed = "비 오는 날 창가에서",
            createdAt = now - 600_000, updatedAt = now - 60_000, stage = ProjectStage.INTERVIEW,
            turns = listOf(turn(q1, Answer(listOf("o1"))), turn(q2, Answer(listOf("o1"))), turn(q3)),
        )
    }

    private fun ideasProject(): Project {
        val r = Protocol.parseReply(
            """{"kind":"ideas","stage":"아이디어","progress":100,"insight":"","question":{"title":"","subtitle":"","multi_select":false,"options":[],"allow_custom":false,"custom_hint":""},"ideas_intro":"아늑하고 짧은 퍼즐을 좋아하는 취향과 혼자 3개월이라는 규모를 함께 고려했어요.","ideas":[
            {"id":"1","title":"지하철 정원사","logline":"한 정거장마다 씨앗 하나를 심어 노선도를 꽃길로 바꾸는 3~5분짜리 퍼즐 게임.","category":"퍼즐","platforms":["Android","iOS"],"genre":"배치 퍼즐","target_audience":"출퇴근하는 20~40대","core_hook":"정거장 사이 짧은 시간 안에 꽃이 피는 조합을 찾는 쾌감","key_features":["노선도 위 타일 배치","정거장 수만큼 남은 턴","계절마다 바뀌는 꽃 조합","오프라인 플레이"],"unique_point":"실제 이동 시간과 한 판 길이가 맞물려요.","monetization":"유료 4,400원","scope":"소형","dev_time":"1인 3개월","difficulty":2,"fit_reason":"짧은 세션, 아늑한 분위기, 혼자 개발 규모를 모두 반영했어요.","similar_works":["Mini Metro — 노선도 위 퍼즐이라는 점은 같지만 경쟁 대신 가꾸기가 중심이에요","Viridi — 식물을 돌보는 아늑함은 같지만 퍼즐 목표가 있어요"],"risks":["퍼즐 깊이가 금방 바닥날 수 있어요","노선도 테마가 낯선 해외 사용자"],"validation":"종이로 노선 3개짜리 퍼즐을 만들어 지인 5명에게 출퇴근길에 풀어 보게 해요."},
            {"id":"2","title":"우산 대여소","logline":"비 오는 도시에서 사람들의 동선을 읽고 우산을 빌려주는 경영 퍼즐.","category":"시뮬레이션","platforms":["Android"],"genre":"경영","target_audience":"코지 게임 팬","core_hook":"날씨 예보를 읽고 미리 준비하는 전략","key_features":["날씨 예보","손님 이야기","가게 꾸미기"],"unique_point":"비가 그치면 하루가 끝나요.","monetization":"무료 + 꾸미기 아이템","scope":"중형","dev_time":"1인 5개월","difficulty":3,"fit_reason":"아늑함과 전략을 함께 원해서 골랐어요.","risks":["경영 요소가 복잡해질 위험","비 오는 날만 하는 단조로움"],"validation":"엑셀로 하루 손님 흐름을 시뮬레이션해 재미를 확인해요."},
            {"id":"3","title":"별빛 배달부","logline":"잠든 마을에 꿈을 배달하는 한 손 리듬 러너.","category":"액션","platforms":["Android","iOS"],"genre":"리듬 러너","target_audience":"캐주얼 게이머","core_hook":"음악에 맞춰 지붕을 건너는 손맛","key_features":["한 손 탭 조작","20곡 수록","꿈 수집"],"unique_point":"배달한 꿈이 다음 곡을 바꿔요.","monetization":"유료","scope":"중형","dev_time":"1인 6개월","difficulty":4,"fit_reason":"몽환적인 분위기를 반영했어요.","risks":["리듬 판정 조정에 시간이 많이 들어요","음악 제작 비용"],"validation":"무료 곡 3개로 한 판짜리 시제품을 만들어 봐요."},
            {"id":"4","title":"고양이 서점","logline":"고양이가 추천하는 책을 손님에게 연결하는 대화형 퍼즐.","category":"퍼즐","platforms":["Android"],"genre":"내러티브","target_audience":"책과 고양이를 좋아하는 사람","core_hook":"손님의 사연에 맞는 책을 찾았을 때의 뿌듯함","key_features":["사연 읽기","책장 정리","고양이 수집"],"unique_point":"실제 고전 문학의 한 구절을 단서로 써요.","monetization":"유료","scope":"소형","dev_time":"1인 4개월","difficulty":2,"fit_reason":"아늑함과 이야기 선호를 반영했어요.","risks":["글 분량이 많아 제작이 오래 걸려요","고전 인용 저작권 확인"],"validation":"사연 5개를 종이 카드로 만들어 지인과 맞혀 봐요."}]}""",
        )
        val now = System.currentTimeMillis()
        val ideas = r.ideas.map { it.copy(id = "b1_" + it.id) }
        return interviewProject().copy(
            id = "p_ideas", title = "출퇴근길 게임", kind = ProjectKind.GAME, seed = "출퇴근길 20분", stage = ProjectStage.IDEAS,
            turns = interviewProject().turns.dropLast(1) + interviewProject().turns.last().copy(answer = Answer(listOf("a", "b"))),
            ideaBatches = listOf(IdeaBatch("b1", now - 120_000, r.ideasIntro, "", ideas)),
            savedIdeaIds = listOf("b1_1"),
        )
    }

    // ------------------------------------------------------------ 캡처

    @Test fun s01_onboarding() {
        setContent { OnboardingScreen(onFinish = {}) }
        shot("01_onboarding_1")
    }

    @Test fun s02_onboarding_last() {
        setContent { OnboardingScreen(onFinish = {}, initialPage = 2) }
        shot("02_onboarding_3")
    }

    @Test fun s03_apikey() {
        setContent { ApiKeyScreen(fromSettings = false, onDone = {}, onBack = null) }
        shot("03_apikey")
    }

    @Test fun s04_home_fresh() {
        c.store.upsert(SampleProject.korean())
        setContent { MainTabs({}, {}, {}, {}) }
        shot("04_home_fresh_nokey")
    }

    @Test fun s05_home_active() {
        withKey()
        c.settings.setProfile(DevProfile("1~3년", listOf("Godot", "Unity"), "혼자", ""))
        c.store.upsert(SampleProject.korean())
        c.store.upsert(interviewProject())
        c.store.upsert(ideasProject())
        setContent { MainTabs({}, {}, {}, {}) }
        click("게임")
        shot("05_home_active")
    }

    @Test fun s06_interview_question() {
        withKey()
        c.store.upsert(interviewProject())
        setContent { ProjectScreen("p_interview", {}, {}) }
        click("아늑하고 따뜻한")
        click("몽환적인")
        shot("06_interview_question")
    }

    @Test fun s07_interview_thinking() {
        withKey()
        ai.gate = CompletableDeferred()
        c.store.upsert(interviewProject())
        setContent { ProjectScreen("p_interview", {}, {}) }
        click("아늑하고 따뜻한")
        click("몽환적인")
        click("두드리기")
        shot("07_interview_thinking", 2000)
    }

    @Test fun s26_compare() {
        withKey()
        c.store.upsert(ideasProject())
        setContent(auto = true) { ProjectScreen("p_ideas", {}, {}) }
        click("비교")
        shot("26_idea_comparison", 1500)
    }

    @Test fun s08_interview_error() {
        withKey()
        ai.turnReplies += Result.failure(AiError.Offline)
        c.store.upsert(interviewProject())
        setContent { ProjectScreen("p_interview", {}, {}) }
        click("아늑하고 따뜻한")
        click("몽환적인")
        click("두드리기")
        ShadowLooper.idleMainLooper()
        shot("08_interview_error")
    }

    @Test fun s09_ideas() {
        withKey()
        c.store.upsert(ideasProject())
        setContent { ProjectScreen("p_ideas", {}, {}) }
        shot("09_ideas")
    }

    @Test fun s10_idea_detail() {
        withKey()
        c.store.upsert(ideasProject())
        setContent(auto = true) { ProjectScreen("p_ideas", {}, {}) }
        click("지하철 정원사")
        shot("10_idea_detail", 1500)
    }

    @Test fun s11_design_setup() {
        withKey()
        c.store.upsert(ideasProject())
        setContent(auto = true) { ProjectScreen("p_ideas", {}, {}) }
        click("지하철 정원사")
        click("설계서 만들기")
        shot("11_design_setup", 1500)
    }

    @Test fun s12_design_question() {
        withKey()
        val dq = """{"kind":"question","stage":"기술","progress":35,"insight":"한 판 3~5분의 노선도 퍼즐로 방향을 정했어요.","question":{"title":"어떤 엔진으로 만들까요?","subtitle":"프로필에 적힌 도구를 기준으로 추천했어요.","multi_select":false,"options":[{"id":"a","label":"Godot 4","description":"추천 · 가볍고 2D 퍼즐에 최적, 무료","emoji":"🤖"},{"id":"b","label":"Unity","description":"에셋이 많지만 빌드가 무거워요","emoji":"🧊"},{"id":"c","label":"Flutter + Flame","description":"앱 UI와 섞기 쉬워요","emoji":"🦋"}],"allow_custom":true,"custom_hint":""},"ready_summary":""}"""
        val base = ideasProject()
        val r = Protocol.parseReply(dq)
        c.settings.setProfile(DevProfile("1~3년", listOf("Godot", "Unity", "Flutter"), "혼자", ""))
        c.store.upsert(base.copy(title = "지하철 정원사", stage = ProjectStage.DESIGN_INTERVIEW, design = DesignState("b1_1", DocDepth.STANDARD, turns = listOf(
            turn(FakeAi.question("한 판의 길이는?", stage = "핵심 루프", progress = 15), Answer(listOf("o2"))),
            Turn(r.stage, r.progress, r.insight, r.question),
        ))))
        setContent { ProjectScreen("p_ideas", {}, {}) }
        shot("12_design_question")
    }

    @Test fun s13_document() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent { ProjectScreen("sample_ko", {}, {}) }
        shot("13_document_top")
    }

    @Test fun s14_document_table() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent { ProjectScreen("sample_ko", {}, {}) }
        rule.onAllNodes(androidx.compose.ui.test.hasScrollToIndexAction())[1].performScrollToIndex(14)
        rule.mainClock.advanceTimeBy(600)
        shot("14_document_section", 1500)
    }

    @Test fun s15_handoff() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent(auto = true) { ProjectScreen("sample_ko", {}, {}) }
        click("Claude로 이어가기")
        shot("15_handoff", 1500)
    }

    @Test fun s16_revise() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent(auto = true) { ProjectScreen("sample_ko", {}, {}) }
        click("수정 요청")
        click("MVP 범위 줄이기")
        shot("16_revise", 1500)
    }

    @Test fun s17_library() {
        withKey()
        c.store.upsert(SampleProject.korean())
        c.store.upsert(SampleProject.koreanApp())
        c.store.upsert(interviewProject())
        c.store.upsert(ideasProject().copy(favorite = true))
        setContent { MainTabs({}, {}, {}, {}, initialTab = 2) }
        shot("17_library")
    }

    @Test fun s18_settings() {
        withKey()
        c.settings.setProfile(DevProfile("1~3년", listOf("Godot", "Unity", "Unreal Engine"), "혼자", ""))
        c.settings.addUsage(Usage(48_200, 21_400, 9_000, 3_000, 0.71, 23))
        c.settings.setMonthlyBudget(10000 / 1400.0)
        setContent { MainTabs({}, {}, {}, {}, initialTab = 3) }
        shot("18_settings")
    }

    @Test fun s19_profile() {
        c.settings.setProfile(DevProfile("1~3년", listOf("Godot", "Unity", "Unreal Engine"), "혼자", "픽셀아트를 직접 그릴 수 있어요."))
        setContent { ProfileScreen {} }
        shot("19_profile")
    }

    @Test fun s20_home_light() {
        withKey()
        c.store.upsert(SampleProject.korean())
        c.store.upsert(interviewProject())
        setContent(theme = ThemeMode.LIGHT) { MainTabs({}, {}, {}, {}) }
        shot("20_home_light")
    }

    @Test fun s21_home_english() {
        c.store.upsert(SampleProject.english())
        setContent(lang = LanguageMode.EN) { MainTabs({}, {}, {}, {}) }
        shot("21_home_english")
    }

    @Test fun s22_document_writing() {
        withKey()
        ai.gate = CompletableDeferred()
        ai.docMarkdown = SUBWAY_DOC
        ai.streamBeforeGate = 22
        val base = ideasProject()
        c.store.upsert(base.copy(title = "지하철 정원사", stage = ProjectStage.DOCUMENT, design = DesignState("b1_1", DocDepth.STANDARD)))
        c.engine.generateDocument("p_ideas")
        setContent { ProjectScreen("p_ideas", {}, {}) }
        shot("22_document_writing", 2000)
    }

    @Test fun s23_document_light() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent(theme = ThemeMode.LIGHT) { ProjectScreen("sample_ko", {}, {}) }
        shot("23_document_light")
    }

    @Test fun s24_demo_interview() {
        val p = c.engine.createDemoProject("체험 프로젝트")
        ShadowLooper.idleMainLooper(3, java.util.concurrent.TimeUnit.SECONDS)
        setContent { ProjectScreen(p.id, {}, {}) }
        shot("24_demo_interview")
    }

    @Test fun s25_library_menu() {
        withKey()
        c.store.upsert(SampleProject.korean())
        c.store.upsert(SampleProject.koreanApp())
        c.store.upsert(interviewProject())
        c.store.upsert(ideasProject().copy(favorite = true))
        setContent(auto = true) { MainTabs({}, {}, {}, {}, initialTab = 2) }
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("더 많은 동작")).onFirst().performClick()
        shot("25_library_menu")
    }

    @Test fun s27_app_document() {
        withKey()
        c.store.upsert(SampleProject.koreanApp())
        setContent { ProjectScreen("sample_ko_app", {}, {}) }
        shot("27_app_document")
    }

    @Test fun s28_edit_document() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent(auto = true) { ProjectScreen("sample_ko", {}, {}) }
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("더 보기")).onFirst().performClick()
        rule.waitForIdle()
        click("직접 편집")
        shot("28_edit_document", 1500)
    }

    // ------------------------------------------------------------ 출시 기능

    private fun withServer() {
        ServerConfig.override = ServerConfig.Values(serverUrl = "https://ember.example", reportEmail = "support@example.com", privacyUrl = "", creditMarkup = 2.5, freeCredits = 20)
    }

    @org.junit.After fun resetServer() { ServerConfig.override = null }

    @Test fun s29_credits_start() {
        withServer()
        setContent { ApiKeyScreen(fromSettings = false, onDone = {}, onBack = null) }
        shot("29_credits_start")
    }

    @Test fun s30_credits_balance() {
        withServer()
        c.settings.setCreditAccount("tok_test", 1234)
        c.settings.setPurchased(true)
        setContent { ApiKeyScreen(fromSettings = true, onDone = {}, onBack = {}) }
        shot("30_credits_balance")
    }

    @Test fun s54_credits_free_balance() {
        withServer()
        c.settings.setCreditAccount("tok_test", 20)
        setContent { ApiKeyScreen(fromSettings = true, onDone = {}, onBack = {}) }
        shot("54_credits_free_balance")
    }

    @Test fun s31_report() {
        withKey()
        c.store.upsert(ideasProject())
        setContent(auto = true) { ProjectScreen("p_ideas", {}, {}) }
        click("지하철 정원사")
        rule.onAllNodes(hasPlainText("AI 결과 신고"), useUnmergedTree = true).onFirst().performScrollTo()
        click("AI 결과 신고")
        shot("31_report", 1500)
    }

    @Test fun s32_github() {
        withKey()
        c.settings.setGithub("ghp_test", "octo")
        c.store.upsert(SampleProject.korean())
        setContent(auto = true) { ProjectScreen("sample_ko", {}, {}) }
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("더 보기")).onFirst().performClick()
        rule.waitForIdle()
        click("GitHub로 보내기")
        shot("32_github", 1500)
    }

    @Test fun s33_diff() {
        withKey()
        val sample = SampleProject.korean()
        c.store.upsert(sample)
        val md = sample.design!!.latest!!.markdown
        c.engine.saveManualEdit(sample.id, md.replace("한 판 3~5분", "한 판 3분 안팎").replace("1인, 3개월", "1인, 4개월(사운드 외주)"), "직접 편집")
        setContent(auto = true) { ProjectScreen("sample_ko", {}, {}) }
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("더 보기")).onFirst().performClick()
        rule.waitForIdle()
        click("버전 기록")
        click("바뀐 부분")
        shot("33_diff", 1500)
    }

    @Test fun s34_edit_section() {
        withKey()
        c.store.upsert(SampleProject.korean())
        setContent(auto = true) { ProjectScreen("sample_ko", {}, {}) }
        rule.onAllNodes(androidx.compose.ui.test.hasContentDescription("편집")).onFirst().performClick()
        rule.waitForIdle()
        click("미리 보기")
        shot("34_edit_section", 1500)
    }

    @Test fun s35_partial_question() {
        withKey()
        ai.gate = CompletableDeferred()
        ai.partialFraction = 0.62
        ai.turnReplies += Result.success(FakeAi.question("한 판은 얼마나 걸리면 좋을까요?", stage = "핵심 경험", progress = 55, options = listOf("1~2분" to "", "3~5분" to "", "10분 이상" to "", "정해 두지 않음" to "")))
        c.store.upsert(interviewProject())
        setContent { ProjectScreen("p_interview", {}, {}) }
        click("아늑하고 따뜻한")
        click("두드리기")
        shot("35_partial_question", 1500)
    }

    @Test fun s36_idea_references() {
        withKey()
        val p = ideasProject()
        val first = p.ideaBatches.first().ideas.first().copy(references = listOf(
            Reference("Mini Metro - Dinosaur Polo Club", "https://dinopoloclub.com/games/mini-metro/"),
            Reference("Viridi on Steam", "https://store.steampowered.com/app/375950/Viridi/"),
        ))
        c.store.upsert(p.copy(ideaBatches = listOf(p.ideaBatches.first().copy(ideas = listOf(first) + p.ideaBatches.first().ideas.drop(1)))))
        setContent(auto = true) { ProjectScreen("p_ideas", {}, {}) }
        click("지하철 정원사")
        rule.onAllNodes(hasPlainText("store.steampowered.com"), useUnmergedTree = true).onFirst().performScrollTo()
        shot("36_idea_references", 1500)
    }

    @Test fun s37_home_image() {
        withKey()
        val f = java.io.File(app.cacheDir, "sketch.png")
        val bmp = android.graphics.Bitmap.createBitmap(400, 300, android.graphics.Bitmap.Config.ARGB_8888)
        android.graphics.Canvas(bmp).apply {
            drawColor(0xFF2A3A5C.toInt())
            val paint = android.graphics.Paint().apply { color = 0xFFFFC46B.toInt() }
            drawCircle(300f, 80f, 40f, paint)
            paint.color = 0xFF16213A.toInt()
            drawRect(0f, 200f, 400f, 300f, paint)
        }
        f.outputStream().use { bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        SharedSeed.shared = Incoming.Shared("밤 기차 창밖 풍경", android.net.Uri.fromFile(f))
        setContent(auto = true) { MainTabs({}, {}, {}, {}) }
        Thread.sleep(800)
        rule.waitForIdle()
        shot("37_home_image", 1500)
    }

    @Test fun s38_privacy() {
        setContent { PrivacyScreen {} }
        shot("38_privacy")
    }

    @Test fun s39_settings_data() {
        withKey()
        c.settings.setGithub("ghp_test", "octo")
        setContent(auto = true) { MainTabs({}, {}, {}, {}, initialTab = 3) }
        rule.onAllNodes(hasPlainText("Android 백업을 켜 두면"), useUnmergedTree = true).onFirst().performScrollTo()
        shot("39_settings_data", 1500)
    }

    @Test fun s40_crash_prompt() {
        withKey()
        CrashLog.write(app, Thread.currentThread(), IllegalStateException("test"))
        setContent { MainTabs({}, {}, {}, {}) }
        shot("40_crash_prompt")
    }

    @Test fun s42_orebox() {
        withKey()
        val now = System.currentTimeMillis()
        c.memos.upsert(Memo("m3", "노트에 그린 등대 지도 스케치", listOf("게임"), createdAt = now - 7 * 86_400_000L))
        c.memos.upsert(Memo("m2", "퇴근길 1분 회고 앱에 날씨 기록을 붙이면? #앱", listOf("앱"), createdAt = now - 3 * 86_400_000L))
        c.memos.upsert(Memo("m1", "막차를 놓친 사람들이 정류장에서 서로 이야기를 나누는 장면. 대사보다 불빛으로. #게임 #밤", listOf("게임", "밤"), pinned = true, createdAt = now - 86_400_000L))
        c.molds.upsert(Mold("k1", "주말 바이브 코딩", mapOf("purpose" to "바이브 코딩", "method" to "AI에게 맡김", "platform" to "웹", "scope" to "주말", "engine" to "웹(JS)"), createdAt = now))
        setContent { MainTabs({}, {}, {}, {}, initialTab = 1) }
        shot("42_orebox")
    }

    @Test fun s43_mold_editor() {
        val now = System.currentTimeMillis()
        c.molds.upsert(Mold("k1", "주말 바이브 코딩", mapOf("purpose" to "바이브 코딩", "method" to "AI에게 맡김", "platform" to "웹", "scope" to "주말", "engine" to "웹(JS)"), depth = DepthMode.SHORT, kind = ProjectKind.GAME, createdAt = now))
        setContent { MoldScreen("k1", {}, {}) }
        shot("43_mold_editor")
    }

    @Test fun s44_home_mold() {
        withKey()
        val now = System.currentTimeMillis()
        c.molds.upsert(Mold("k2", "1인 모바일 3개월", mapOf("purpose" to "출시·수익", "platform" to "모바일", "scope" to "3개월", "method" to "AI와 함께"), createdAt = now))
        c.molds.upsert(Mold("k1", "주말 바이브 코딩", mapOf("purpose" to "바이브 코딩", "method" to "AI에게 맡김", "platform" to "웹", "scope" to "주말", "engine" to "웹(JS)"), createdAt = now, usedCount = 3))
        c.store.upsert(interviewProject())
        setContent { MainTabs({}, {}, {}, {}) }
        click("주말 바이브 코딩")
        click("게임")
        shot("44_home_mold")
    }

    @Test fun s45_interview_mold() {
        withKey()
        c.store.upsert(interviewProject().copy(
            presets = listOf(PresetAnswer("목적", "바이브 코딩"), PresetAnswer("플랫폼", "모바일")),
            moldName = "주말 바이브 코딩", depthMode = DepthMode.LONG,
        ))
        setContent { ProjectScreen("p_interview", {}, {}) }
        shot("45_interview_mold")
    }

    @Test fun s46_ideas_select() {
        withKey()
        c.store.upsert(ideasProject())
        setContent(auto = true) { ProjectScreen("p_ideas", {}, {}) }
        rule.onAllNodes(hasPlainText("지하철 정원사"), useUnmergedTree = true).onFirst().performTouchInput { longClick() }
        rule.waitForIdle()
        click("우산 대여소")
        shot("46_ideas_select")
        click("삭제 2")
        shot("47_ideas_delete_confirm")
    }

    @Test fun s48_library_select() {
        withKey()
        c.store.upsert(SampleProject.korean())
        c.store.upsert(interviewProject())
        c.store.upsert(ideasProject())
        setContent(auto = true) { MainTabs({}, {}, {}, {}, initialTab = 2) }
        rule.onAllNodes(hasPlainText("출퇴근길 게임"), useUnmergedTree = true).onFirst().performTouchInput { longClick() }
        rule.waitForIdle()
        click("비 오는 날 아이디어")
        shot("48_library_select")
        click("삭제 2")
        // 확인 창의 '삭제'(창이 목록 위에 뜨므로 마지막 노드)를 누른다.
        rule.onAllNodes(hasPlainText("삭제"), useUnmergedTree = true).onLast().performClick()
        rule.waitForIdle()
        rule.onAllNodes(hasPlainText("프로젝트 2개를 지웠어요"), useUnmergedTree = true).onFirst().assertExists()
        assertEquals(1, c.store.projects.value.size)
        shot("49_library_deleted_undo")
    }

    @Test fun s50_home_select() {
        withKey()
        c.store.upsert(interviewProject())
        c.store.upsert(ideasProject())
        setContent(auto = true) { MainTabs({}, {}, {}, {}) }
        val list = rule.onAllNodes(androidx.compose.ui.test.hasScrollToNodeAction()).onFirst()
        list.performScrollToNode(hasPlainText("비 오는 날 아이디어"))
        rule.waitForIdle()
        rule.onAllNodes(hasPlainText("출퇴근길 게임"), useUnmergedTree = true).onFirst().performTouchInput { longClick() }
        rule.waitForIdle()
        click("비 오는 날 아이디어")
        shot("50_home_select")
        click("삭제 2")
        rule.onAllNodes(hasPlainText("삭제"), useUnmergedTree = true).onLast().performClick()
        rule.waitForIdle()
        rule.onAllNodes(hasPlainText("프로젝트 2개를 지웠어요"), useUnmergedTree = true).onFirst().assertExists()
        assertEquals(0, c.store.projects.value.count { !it.isSample })
    }

    @Test fun s51_concept_sheet() {
        withKey()
        setContent(auto = true) { MainTabs({}, {}, {}, {}) }
        click("컨셉 적고 바로 받기")
        shot("51_concept_sheet", 1500)
    }

    @Test fun s52_transfer_notice() {
        withKey()
        setContent(auto = true) { MainTabs({}, {}, {}, {}) }
        click("게임")
        rule.onAllNodes(androidx.compose.ui.test.hasScrollToNodeAction()).onFirst().performScrollToNode(hasPlainText("질문 받으며 시작"))
        rule.waitForIdle()
        click("질문 받으며 시작")
        rule.onAllNodes(hasPlainText("미국으로 전송돼요"), useUnmergedTree = true).onFirst().assertExists()
        shot("52_transfer_notice", 1500)
        // 확인하기 전에는 프로젝트를 만들지 않는다.
        assertEquals(0, c.store.projects.value.count { !it.isSample })
    }

    @Test fun s53_terms() {
        setContent { TermsScreen {} }
        shot("53_terms")
    }

    @Suppress("unused") private fun unusedRefs() = listOf(hasText(""), rule.onNodeWithTag(""))
    @Suppress("unused") private fun scroll() = rule.onAllNodesWithText("").onFirst().performScrollToNode(hasText(""))

    private val SUBWAY_DOC = """
# 지하철 정원사

> 한 정거장마다 씨앗 하나를 심어 노선도를 꽃길로 바꾸는 3~5분짜리 퍼즐 게임이에요.

## 한눈에 보기

| 항목 | 내용 |
|---|---|
| 장르 | 배치 퍼즐 |
| 플랫폼 | Android, iOS |
| 엔진 | Godot 4 |

## 핵심 재미와 게임 루프

- 30초 루프: 씨앗 타일을 정거장에 놓고 이웃 꽃과 조합해 피워요.
- 5분 루프: 노선 하나를 꽃길로 채우면 다음 노선이 열려요.

## 조작과 핵심 메커닉

- 탭으로 씨앗을 고르고 정거장에 끌어다 놓아요.
""".trimIndent()
}
