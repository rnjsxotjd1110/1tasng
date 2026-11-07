package app.ember.ideas.logic

import app.ember.ideas.account.ServerConfig
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.CostEstimate
import app.ember.ideas.data.DocDepth
import app.ember.ideas.ui.screens.freeSets
import app.ember.ideas.ui.strings.EnStrings
import app.ember.ideas.ui.strings.KoStrings
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** 가격 체제(마크업 2.5, 무료 20 크레딧)에서 행동별 크레딧과 안내 문구. */
class CreditMathTest {
    @Before fun setUp() {
        ServerConfig.override = ServerConfig.Values(serverUrl = "https://ember.example", reportEmail = "", privacyUrl = "", creditMarkup = 2.5, freeCredits = 20)
    }

    @After fun tearDown() { ServerConfig.override = null }

    @Test fun haikuCountsTheOneCreditMinimumPerRequest() {
        // 질문 7번 + 아이디어 1번 = 요청 8번, 각각 1 크레딧(합계 USD 로 바꾸면 3 이 되어 틀린다)
        assertEquals(8, CostEstimate.discoveryCredits(ClaudeModel.HAIKU))
        assertEquals(3, ServerConfig.creditsFor(CostEstimate.discovery(ClaudeModel.HAIKU)))
        // 설계 질문 6번(각 1) + 표준 설계서(2)
        assertEquals(8, CostEstimate.designCredits(ClaudeModel.HAIKU, DocDepth.STANDARD, true))
    }

    @Test fun freeTwentyCreditsCoverOneDiscoveryAndOneDesign() {
        assertEquals(1, freeSets(20))
        assertEquals(0, freeSets(10))
    }

    @Test fun opusPricesAtMarkupTwoAndAHalf() {
        assertEquals(82, CostEstimate.discoveryCredits(ClaudeModel.OPUS))
        assertEquals(93, CostEstimate.designCredits(ClaudeModel.OPUS, DocDepth.STANDARD, true))
        assertEquals(175, CostEstimate.fullSetCredits(ClaudeModel.OPUS))
    }

    @Test fun freeCreditsTextNeverSaysZeroTimes() {
        val ko = KoStrings.creditsBody(20, freeSets(20))
        assertTrue(ko, ko.contains("아이디어 탐색 1번과 표준 설계서 1개"))
        assertFalse(ko.contains("0번"))
        val none = KoStrings.creditsBody(5, freeSets(5))
        assertFalse(none, none.contains("번"))
        assertEquals("You get 20 free credits, enough for one idea session and one standard design doc on Haiku 5.5. When they run out, top up with Google Play.", EnStrings.creditsBody(20, 1))
        assertTrue(EnStrings.creditsBody(40, 2).contains("about 2 idea sessions and 2 standard design docs"))
        assertEquals("You get 5 free credits. When they run out, top up with Google Play.", EnStrings.creditsBody(5, 0))
    }
}
