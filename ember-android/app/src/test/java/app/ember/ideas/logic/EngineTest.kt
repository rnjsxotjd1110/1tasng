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
}
