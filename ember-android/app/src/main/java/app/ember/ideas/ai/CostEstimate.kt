package app.ember.ideas.ai

import app.ember.ideas.data.DocDepth

/**
 * 행동별 예상 비용(USD)과 시간. 공개 단가와 평균 토큰 수로 계산한 대략값이며,
 * 사용자가 결정하는 순간(시작·깊이 선택·수정) 옆에 보여 준다.
 */
object CostEstimate {
    private const val QUESTION_IN = 3_500L
    private const val QUESTION_OUT = 900L
    private const val IDEAS_IN = 6_000L
    private const val IDEAS_OUT = 4_000L
    private const val DOC_IN = 4_500L
    private const val DISCOVERY_QUESTIONS = 7

    fun docOut(depth: DocDepth): Long = when (depth) {
        DocDepth.BRIEF -> 3_500L
        DocDepth.STANDARD -> 8_000L
        DocDepth.BUILD_READY -> 16_000L
    }

    fun question(m: ClaudeModel) = m.cost(QUESTION_IN, QUESTION_OUT, 0, 0)
    fun ideas(m: ClaudeModel) = m.cost(IDEAS_IN, IDEAS_OUT, 0, 0)

    /** 질문 약 7개 + 아이디어 한 번. */
    fun discovery(m: ClaudeModel) = question(m) * DISCOVERY_QUESTIONS + ideas(m)

    fun document(m: ClaudeModel, depth: DocDepth) = m.cost(DOC_IN, docOut(depth), 0, 0)

    /** 설계 질문 + 설계서. */
    fun design(m: ClaudeModel, depth: DocDepth, withQuestions: Boolean) =
        document(m, depth) + if (withQuestions) question(m) * depth.designQuestions else 0.0

    fun revision(m: ClaudeModel, depth: DocDepth) = m.cost(DOC_IN + docOut(depth), docOut(depth), 0, 0)

    fun fullSet(m: ClaudeModel) = discovery(m) + design(m, DocDepth.STANDARD, true)

    // 크레딧은 요청마다 올림하고 최소 1 크레딧이라(서버 billing/pricing.ts) 요청 단위로 더한다.
    // 값싼 모델(Haiku)은 합계 USD 로 한 번에 바꾸면 실제보다 훨씬 적게 나온다.
    private fun credits(usd: Double) = app.ember.ideas.account.ServerConfig.creditsFor(usd)

    fun discoveryCredits(m: ClaudeModel) = credits(question(m)) * DISCOVERY_QUESTIONS + credits(ideas(m))

    fun designCredits(m: ClaudeModel, depth: DocDepth, withQuestions: Boolean) =
        credits(document(m, depth)) + if (withQuestions) credits(question(m)) * depth.designQuestions else 0

    fun fullSetCredits(m: ClaudeModel) = discoveryCredits(m) + designCredits(m, DocDepth.STANDARD, true)

    /** 출력 속도 기준 대략 시간(분) 범위. */
    fun minutes(m: ClaudeModel, depth: DocDepth): Pair<Int, Int> {
        val tps = when (m) { ClaudeModel.OPUS -> 60.0; ClaudeModel.SONNET -> 90.0; ClaudeModel.HAIKU -> 180.0 }
        val min = (docOut(depth) / tps / 60.0).toInt().coerceAtLeast(1)
        return min to min + 2
    }
}
