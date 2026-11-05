package app.ember.ideas.logic

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import app.ember.ideas.AppContainer
import app.ember.ideas.FakeAi
import app.ember.ideas.ai.AiError
import app.ember.ideas.data.Answer
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.handoff.Handoff
import app.ember.ideas.handoff.HandoffGoal
import app.ember.ideas.handoff.HandoffOptions
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLooper

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class EngineTest {
    private lateinit var ai: FakeAi
    private lateinit var c: AppContainer

    @Before fun setUp() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        app.filesDir.listFiles()?.forEach { it.deleteRecursively() }
        ai = FakeAi()
        c = AppContainer(app, ai)
        c.store.deleteAll()
        c.settings.setApiKey("sk-ant-test-0000000000000000000000000000000000")
    }

    private fun idle() = repeat(5) { ShadowLooper.idleMainLooper() }

    @Test fun fullFlow() {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        ai.turnReplies += Result.success(FakeAi.question("Q2"))
        ai.turnReplies += Result.success(FakeAi.ideas("A", "B", "C", "D"))
        val p = c.engine.createProject(ProjectKind.GAME, "고양이", "새 게임")
        idle()
        assertEquals("Q1", c.store.get(p.id)!!.currentTurn!!.question.title)

        c.engine.answer(p.id, Answer(listOf("o1")))
        idle()
        assertEquals("Q2", c.store.get(p.id)!!.currentTurn!!.question.title)

        c.engine.requestIdeasNow(p.id)
        idle()
        val after = c.store.get(p.id)!!
        assertEquals(ProjectStage.IDEAS, after.stage)
        assertEquals(4, after.allIdeas.size)
        assertNull(after.currentTurn)
        // 기록: 시작, Q1, A1, Q2, 요청, 아이디어 = 6
        assertEquals(6, after.messages.size)
        assertTrue(after.usage.costUsd > 0)

        val idea = after.allIdeas.first()
        ai.turnReplies += Result.success(FakeAi.question("엔진은?", stage = "기술"))
        ai.turnReplies += Result.success(FakeAi.ready())
        c.engine.startDesign(p.id, idea.id, DocDepth.STANDARD, askQuestions = true)
        idle()
        assertEquals(ProjectStage.DESIGN_INTERVIEW, c.store.get(p.id)!!.stage)
        c.engine.designAnswer(p.id, Answer(listOf("o1")))
        idle()
        val done = c.store.get(p.id)!!
        assertEquals(ProjectStage.DOCUMENT, done.stage)
        assertNotNull(done.design!!.latest)
        assertEquals("제목", done.title)
        assertTrue(idea.id in done.savedIdeaIds)

        c.engine.reviseDocument(p.id, "더 간단하게")
        idle()
        assertEquals(2, c.store.get(p.id)!!.design!!.versions.size)
        assertEquals("더 간단하게", c.store.get(p.id)!!.design!!.latest!!.note)
    }

    @Test fun undoRestoresPreviousQuestionAndDraft() {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        ai.turnReplies += Result.success(FakeAi.question("Q2"))
        val p = c.engine.createProject(ProjectKind.APP, "", "새 앱")
        idle()
        c.engine.answer(p.id, Answer(listOf("o2"), "메모"))
        idle()
        val draft = c.engine.undo(p.id)
        assertEquals(listOf("o2"), draft!!.selectedIds)
        val proj = c.store.get(p.id)!!
        assertEquals("Q1", proj.currentTurn!!.question.title)
        assertEquals(2, proj.messages.size)
    }

    @Test fun failureKeepsStateAndRetryWorks() {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        val p = c.engine.createProject(ProjectKind.WEB, "", "새 웹")
        idle()
        ai.turnReplies += Result.failure(AiError.Overloaded)
        c.engine.answer(p.id, Answer(listOf("o1")))
        idle()
        assertEquals(AiError.Overloaded, c.engine.ops.value[p.id]!!.error)
        assertEquals("Q1", c.store.get(p.id)!!.currentTurn!!.question.title)
        ai.turnReplies += Result.success(FakeAi.question("Q2"))
        c.engine.retry(p.id)
        idle()
        assertNull(c.engine.ops.value[p.id])
        assertEquals("Q2", c.store.get(p.id)!!.currentTurn!!.question.title)
    }

    @Test fun streamErrorKeepsPartialAsIncomplete() {
        ai.turnReplies += Result.success(FakeAi.ideas("A"))
        val p = c.engine.createProject(ProjectKind.GAME, "", "새 게임")
        idle()
        ai.docError = AiError.Offline
        c.engine.startDesign(p.id, c.store.get(p.id)!!.allIdeas.first().id, DocDepth.BRIEF, askQuestions = false)
        idle()
        assertEquals(AiError.Offline, c.engine.ops.value[p.id]!!.error)
        assertNull(c.store.get(p.id)!!.design!!.latest)
    }

    @Test fun handoffPromptContainsDocAndGoal() {
        val p = app.ember.ideas.data.SampleProject.korean()
        val prompt = Handoff.buildPrompt(p, p.selectedIdea, c.settings.settings.value.profile, HandoffOptions(HandoffGoal.START_BUILD), korean = true)
        assertTrue(prompt.contains("개발을 시작"))
        assertTrue(prompt.contains("## 설계서"))
        assertTrue(prompt.contains("등불지기"))
        val noDoc = Handoff.buildPrompt(p, p.selectedIdea, c.settings.settings.value.profile, HandoffOptions(HandoffGoal.REVIEW, includeDocument = false), korean = true)
        assertFalse(noDoc.contains("## 설계서"))
    }

    @Test fun persistenceRoundTrip() {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        val p = c.engine.createProject(ProjectKind.GAME, "", "새 게임")
        idle()
        val app = ApplicationProvider.getApplicationContext<Application>()
        val file = java.io.File(app.filesDir, "projects.json")
        var waited = 0
        while ((!file.exists() || !file.readText().contains("Q1")) && waited < 5000) { Thread.sleep(50); waited += 50; idle() }
        val c2 = AppContainer(app, FakeAi())
        assertEquals("Q1", c2.store.get(p.id)?.currentTurn?.question?.title)
    }

    @Test fun searchOnlyForIdeasAndReferencesAreVerified() {
        ai.turnReplies += Result.success(FakeAi.question("Q1", progress = 20))
        val withRefs = FakeAi.ideas("A", "B").replaceFirst(
            "\"fit_reason\":\"이유\"",
            "\"fit_reason\":\"이유\",\"references\":[{\"title\":\"\",\"url\":\"https://example.com/mini-metro/\"},{\"title\":\"가짜\",\"url\":\"https://made-up.example/x\"}]",
        )
        ai.turnReplies += Result.success(withRefs)
        ai.sources = listOf(app.ember.ideas.data.Reference("Mini Metro", "https://example.com/mini-metro"))
        val p = c.engine.createProject(ProjectKind.GAME, "", "새 게임")
        idle()
        assertFalse("질문 단계에서는 검색하지 않아요", ai.turnRequests.last().webSearch)
        c.engine.requestIdeasNow(p.id)
        idle()
        assertTrue(ai.turnRequests.last().webSearch)
        val refs = c.store.get(p.id)!!.allIdeas.first().references
        // 검색 결과에 없던 주소는 지우고, 빈 제목은 검색 결과 제목으로 채운다.
        assertEquals(listOf("https://example.com/mini-metro"), refs.map { it.url })
        assertEquals("Mini Metro", refs.first().title)

        c.settings.setWebSearch(false)
        ai.turnReplies += Result.success(FakeAi.ideas("C"))
        c.engine.moreIdeas(p.id)
        idle()
        assertFalse(ai.turnRequests.last().webSearch)
    }

    @Test fun imagesGoWithFirstMessageOnly() {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        ai.turnReplies += Result.success(FakeAi.question("Q2"))
        val p = c.engine.createProject(ProjectKind.APP, "메모", "새 앱", images = listOf("/data/img1.jpg"))
        idle()
        c.engine.answer(p.id, Answer(listOf("o1")))
        idle()
        val msgs = ai.turnRequests.last().messages
        assertEquals(listOf("/data/img1.jpg"), msgs.first().images)
        assertTrue(msgs.first().text.contains("참고 이미지: 1장"))
        assertTrue(msgs.drop(1).all { it.images.isEmpty() })
    }

    @Test fun fastQuestionsUseSonnetForQuestionsOnly() {
        c.settings.setFastQuestions(true)
        val models = mutableListOf<app.ember.ideas.ai.ClaudeModel>()
        val spy = object : app.ember.ideas.ai.AiService by ai {
            override suspend fun turn(model: app.ember.ideas.ai.ClaudeModel, request: app.ember.ideas.ai.TurnRequest): app.ember.ideas.ai.TurnResult {
                models += model
                return ai.turn(model, request)
            }
            override suspend fun turnStreaming(model: app.ember.ideas.ai.ClaudeModel, request: app.ember.ideas.ai.TurnRequest, onText: (String) -> Unit) = turn(model, request)
        }
        val app2 = ApplicationProvider.getApplicationContext<Application>()
        val c2 = AppContainer(app2, spy)
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        ai.turnReplies += Result.success(FakeAi.ideas("A"))
        val p = c2.engine.createProject(ProjectKind.GAME, "", "새 게임")
        idle()
        c2.engine.requestIdeasNow(p.id)
        idle()
        assertEquals(listOf(app.ember.ideas.ai.ClaudeModel.SONNET, app.ember.ideas.ai.ClaudeModel.OPUS), models)
    }

    @Test fun importMergesNewerProjects() {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        val p = c.engine.createProject(ProjectKind.GAME, "", "원래 제목")
        idle()
        val exported = c.store.exportJson()
        c.engine.rename(p.id, "바뀐 제목")
        // 예전 백업을 가져와도 더 최근에 고친 프로젝트는 그대로 둔다.
        assertEquals(0, c.store.importJson(exported))
        assertEquals("바뀐 제목", c.store.get(p.id)!!.title)
        c.store.deleteAll()
        assertEquals(1, c.store.importJson(exported))
        assertEquals("원래 제목", c.store.get(p.id)!!.title)
        assertNull(c.store.importJson("not a backup"))
    }

    // ------------------------------------------------------------ 질문 더 받기·중복 아이디어

    private fun toIdeas(): String {
        ai.turnReplies += Result.success(FakeAi.question("Q1"))
        ai.turnReplies += Result.success(FakeAi.ideas("A", "B", "C", "D"))
        val p = c.engine.createProject(ProjectKind.GAME, "", "새 게임")
        idle()
        c.engine.requestIdeasNow(p.id)
        idle()
        assertEquals(ProjectStage.IDEAS, c.store.get(p.id)!!.stage)
        return p.id
    }

    @Test fun moreQuestionsAsksThreeConceptQuestionsThenNewIdeas() {
        val id = toIdeas()
        ai.turnReplies += Result.success(FakeAi.question("X1", stage = "핵심 경험"))
        c.engine.moreQuestions(id)
        idle()
        val req = ai.turnRequests.last().messages.last().text
        assertTrue(req.startsWith(app.ember.ideas.ai.Protocol.TAG_MORE_QUESTIONS))
        assertTrue("사업 질문을 피하라고 알려야 해요", req.contains("수익·판매·마케팅·출시 계획"))
        assertTrue("이미 한 질문을 알려야 해요", req.contains("Q1"))
        assertTrue("이전 아이디어를 알려야 해요", req.contains("A, B, C, D"))
        var p = c.store.get(id)!!
        assertEquals(ProjectStage.INTERVIEW, p.stage)
        assertEquals(2, p.extraQuestionsLeft)
        assertFalse("요청으로 시작된 질문은 이전으로 돌아갈 수 없어요", c.engine.canUndo(p))

        ai.turnReplies += Result.success(FakeAi.question("X2"))
        c.engine.answer(id, Answer(listOf("o1")))
        idle()
        assertTrue(ai.turnRequests.last().messages.last().text.contains("(추가 질문 2개 남음"))
        p = c.store.get(id)!!
        assertEquals(1, p.extraQuestionsLeft)
        assertTrue(c.engine.canUndo(p))

        ai.turnReplies += Result.success(FakeAi.question("X3"))
        c.engine.answer(id, Answer(listOf("o2")))
        idle()
        assertEquals(0, c.store.get(id)!!.extraQuestionsLeft)

        ai.turnReplies += Result.success(FakeAi.ideas("E", "F", "G", "H"))
        c.engine.answer(id, Answer(listOf("o1")))
        idle()
        val last = ai.turnRequests.last()
        assertTrue(last.messages.last().text.contains(app.ember.ideas.ai.Protocol.TAG_FRESH_IDEAS))
        assertTrue("새 아이디어를 낼 차례라 검색을 켜요", last.webSearch)
        p = c.store.get(id)!!
        assertEquals(ProjectStage.IDEAS, p.stage)
        assertEquals(-1, p.extraQuestionsLeft)
        assertEquals(listOf("E", "F", "G", "H"), p.ideaBatches.last().ideas.map { it.title })
        assertTrue(p.ideaBatches.last().fromExtraQuestions)
        // 대화 기록은 user/assistant 가 번갈아 있어야 해요.
        p.messages.zipWithNext().forEach { (a, b) -> assertTrue(a.role != b.role) }
    }

    @Test fun undoInsideExtraRoundRestoresCount() {
        val id = toIdeas()
        ai.turnReplies += Result.success(FakeAi.question("X1"))
        c.engine.moreQuestions(id)
        idle()
        ai.turnReplies += Result.success(FakeAi.question("X2"))
        c.engine.answer(id, Answer(listOf("o1")))
        idle()
        assertEquals(1, c.store.get(id)!!.extraQuestionsLeft)
        assertNotNull(c.engine.undo(id))
        val p = c.store.get(id)!!
        assertEquals("X1", p.currentTurn!!.question.title)
        assertEquals(2, p.extraQuestionsLeft)
        // 첫 추가 질문에서는 더 돌아갈 수 없어요(아이디어 화면에서 시작했으니까요).
        assertNull(c.engine.undo(id))
    }

    @Test fun stoppingExtraRoundEarlyAsksForFreshIdeas() {
        val id = toIdeas()
        ai.turnReplies += Result.success(FakeAi.question("X1"))
        c.engine.moreQuestions(id)
        idle()
        ai.turnReplies += Result.success(FakeAi.ideas("E", "F", "G", "H"))
        c.engine.requestIdeasNow(id)
        idle()
        assertTrue(ai.turnRequests.last().messages.last().text.startsWith(app.ember.ideas.ai.Protocol.TAG_FRESH_IDEAS))
        val p = c.store.get(id)!!
        assertEquals(-1, p.extraQuestionsLeft)
        assertTrue(p.turns.last().answer!!.skipped)
        assertTrue(p.ideaBatches.last().fromExtraQuestions)
    }

    @Test fun duplicateIdeasAreRequestedAgain() {
        val id = toIdeas()
        ai.turnReplies += Result.success(FakeAi.ideas("A", "B", " c ", "Z"))
        ai.turnReplies += Result.success(FakeAi.ideas("E", "F", "G", "A"))
        c.engine.moreIdeas(id)
        idle()
        assertTrue(ai.turnRequests[ai.turnRequests.size - 2].messages.last().text.contains("A, B, C, D"))
        val dupReq = ai.turnRequests.last().messages.last().text
        assertTrue(dupReq.startsWith(app.ember.ideas.ai.Protocol.TAG_DUPLICATE))
        val p = c.store.get(id)!!
        // 다시 받은 묶음에서도 겹치는 A 는 빼요.
        assertEquals(listOf("E", "F", "G"), p.ideaBatches.last().ideas.map { it.title })
        assertEquals(2, p.ideaBatches.size)
        p.messages.zipWithNext().forEach { (a, b) -> assertTrue(a.role != b.role) }
    }

    @Test fun oneDuplicateIsDroppedWithoutAsking() {
        val id = toIdeas()
        ai.turnReplies += Result.success(FakeAi.ideas("A", "E", "F", "G"))
        val before = ai.turnRequests.size
        c.engine.moreIdeas(id)
        idle()
        assertEquals(before + 1, ai.turnRequests.size)
        assertEquals(listOf("E", "F", "G"), c.store.get(id)!!.ideaBatches.last().ideas.map { it.title })
    }

    @Test fun onlyDuplicatesShowsError() {
        val id = toIdeas()
        ai.turnReplies += Result.success(FakeAi.ideas("A", "B", "C", "D"))
        ai.turnReplies += Result.success(FakeAi.ideas("D", "C", "B", "A"))
        c.engine.moreIdeas(id)
        idle()
        assertEquals(AiError.DuplicateIdeas, c.engine.ops.value[id]?.error)
        assertEquals(1, c.store.get(id)!!.ideaBatches.size)
    }

    @Test fun combineLabelNamesBothIdeas() {
        val id = toIdeas()
        val ideas = c.store.get(id)!!.allIdeas
        ai.turnReplies += Result.success(FakeAi.ideas("M1", "M2", "M3", "M4"))
        c.engine.combine(id, ideas[0], ideas[1])
        idle()
        assertEquals("A + B", c.store.get(id)!!.ideaBatches.last().label)
    }

    @Test fun demoMoreQuestionsGivesNewQuestionsAndIdeas() = kotlinx.coroutines.test.runTest {
        // 체험 AI 를 직접 불러 실제 흐름(기본 질문 → 아이디어 → 추가 질문 3개 → 새 아이디어)을 흉내 낸다.
        val demo = app.ember.ideas.ai.DemoAiService()
        val sys = app.ember.ideas.ai.Protocol.discoverySystem(app.ember.ideas.ai.ReplyLanguage.KO)
        val msgs = mutableListOf(app.ember.ideas.data.ChatMessage("user", "[시작] 새 아이디어 탐색을 시작합니다."))
        suspend fun next(): app.ember.ideas.ai.Protocol.InterviewReply {
            val r = demo.turn(app.ember.ideas.ai.ClaudeModel.OPUS, app.ember.ideas.ai.TurnRequest(sys, msgs.toList(), app.ember.ideas.ai.Protocol.discoverySchema, app.ember.ideas.ai.Effort.LOW))
            msgs += app.ember.ideas.data.ChatMessage("assistant", r.text)
            return app.ember.ideas.ai.Protocol.parseReply(r.text)
        }
        var reply = next()
        val baseQuestions = mutableListOf<String>()
        while (reply.isQuestion) {
            baseQuestions += reply.question.title
            msgs += app.ember.ideas.data.ChatMessage("user", "[답변] ${reply.question.title}\n선택: x")
            reply = next()
        }
        val first = reply.ideas.map { it.title }.toSet()
        assertEquals(4, first.size)
        msgs += app.ember.ideas.data.ChatMessage("user", app.ember.ideas.ai.Protocol.moreQuestionsMessage(baseQuestions, first.toList()))
        val extra = mutableListOf<String>()
        reply = next()
        while (reply.isQuestion) {
            extra += reply.question.title
            val left = 3 - extra.size
            val note = if (left > 0) app.ember.ideas.ai.Protocol.remainingNote(left) else "\n" + app.ember.ideas.ai.Protocol.freshIdeasMessage(first.toList())
            msgs += app.ember.ideas.data.ChatMessage("user", "[답변] ${reply.question.title}\n선택: x$note")
            reply = next()
        }
        assertEquals(3, extra.size)
        assertTrue(extra.none { it in baseQuestions })
        assertTrue(reply.isIdeas)
        assertTrue(reply.ideas.none { it.title in first })
    }
}
