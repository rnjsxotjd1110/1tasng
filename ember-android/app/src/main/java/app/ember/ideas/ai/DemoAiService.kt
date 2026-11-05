package app.ember.ideas.ai

import app.ember.ideas.data.ChatMessage
import app.ember.ideas.data.SampleProject
import app.ember.ideas.data.Usage
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/**
 * 키 없이 체험하는 데모용 Claude. 미리 준비한 질문·아이디어·설계서를 순서대로 돌려준다.
 * 실제 네트워크를 쓰지 않으며 비용이 들지 않는다.
 */
class DemoAiService : AiService {

    override suspend fun turn(model: ClaudeModel, request: TurnRequest): TurnResult {
        delay(1400)
        val ko = request.system.contains("한국어(Korean)")
        val userTurns = request.messages.count { it.role == ChatMessage.USER }
        val isDesign = request.schema == Protocol.designSchema
        val wantsNow = request.messages.lastOrNull()?.text?.startsWith("[요청]") == true
        val text = if (isDesign) {
            if (userTurns >= 3 || wantsNow) ready(ko) else designQuestions(ko)[userTurns - 1]
        } else {
            val qs = discoveryQuestions(ko)
            if (userTurns > qs.size || wantsNow) ideas(ko) else qs[userTurns - 1]
        }
        return TurnResult(text, Usage())
    }

    override fun stream(model: ClaudeModel, request: StreamRequest): Flow<StreamEvent> = flow {
        val ko = request.system.contains("한국어(Korean)")
        val doc = if (ko) SampleProject.SAMPLE_DOC_KO else SampleProject.SAMPLE_DOC_EN
        delay(600)
        doc.chunked(24).forEach { emit(StreamEvent.Delta(it)); delay(18) }
        emit(StreamEvent.Done(Usage(), truncated = false))
    }

    override suspend fun validate(apiKey: String, model: ClaudeModel) = Unit

    // ------------------------------------------------------------ 준비된 내용

    private fun q(stage: String, progress: Int, insight: String, title: String, sub: String, multi: Boolean, vararg o: Triple<String, String, String>): String {
        val opts = o.mapIndexed { i, (l, d, e) -> """{"id":"o${i + 1}","label":"$l","description":"$d","emoji":"$e"}""" }.joinToString(",")
        return """{"kind":"question","stage":"$stage","progress":$progress,"insight":"$insight","question":{"title":"$title","subtitle":"$sub","multi_select":$multi,"options":[$opts],"allow_custom":true,"custom_hint":""},"ideas_intro":"","ideas":[],"ready_summary":""}"""
    }

    private fun discoveryQuestions(ko: Boolean) = if (ko) listOf(
        q("플랫폼", 15, "", "주로 어디서 플레이하면 좋을까요?", "조작 방식과 한 판 길이가 달라져요.", false,
            Triple("모바일", "출퇴근길에 한 손으로", "📱"), Triple("PC", "책상에 앉아 집중해서", "💻"), Triple("웹 브라우저", "설치 없이 바로", "🌐"), Triple("콘솔", "거실 큰 화면으로", "🕹️")),
        q("분위기", 35, "모바일에서 짧게 즐기는 게임을 원하고 있어요.", "어떤 분위기에 끌리나요?", "아트와 사운드의 방향을 정하는 데 쓰여요.", true,
            Triple("아늑하고 따뜻한", "코지 게임처럼 편안한 분위기", "🕯️"), Triple("몽환적인", "꿈속 같은 색감과 음악", "🌙"), Triple("긴장감 넘치는", "손에 땀을 쥐는 순간들", "⚡"), Triple("유쾌하고 엉뚱한", "웃음이 터지는 상황과 캐릭터", "🎈")),
        q("핵심 재미", 60, "아늑하고 몽환적인 모바일 게임을 그리고 있어요.", "어떤 재미가 중심이면 좋을까요?", "핵심 루프의 뼈대가 돼요.", false,
            Triple("퍼즐 풀기", "머리를 써서 딱 맞아떨어지는 쾌감", "🧩"), Triple("수집과 성장", "조금씩 모이고 커지는 만족감", "🌱"), Triple("이야기", "다음 장면이 궁금해지는 몰입", "📖"), Triple("경영", "작은 가게를 꾸려 가는 재미", "🏪")),
        q("규모", 82, "짧게 즐기는 아늑한 퍼즐 게임을 원하고 있어요.", "개발 규모는 어느 정도인가요?", "범위를 현실적으로 맞출게요.", false,
            Triple("혼자, 3개월", "작고 완성도 높게", "🧑‍💻"), Triple("혼자, 6개월 이상", "콘텐츠를 넉넉하게", "⏳"), Triple("소규모 팀", "2~4명이 함께", "👥")),
    ) else listOf(
        q("Platform", 15, "", "Where should people play?", "This shapes controls and session length.", false,
            Triple("Mobile", "One hand on the commute", "📱"), Triple("PC", "Focused at a desk", "💻"), Triple("Web", "No install needed", "🌐"), Triple("Console", "Big screen in the living room", "🕹️")),
        q("Mood", 40, "You want a short mobile game.", "Which mood draws you in?", "Sets the art and sound direction.", true,
            Triple("Cozy", "Warm and relaxing", "🕯️"), Triple("Dreamy", "Soft colors and music", "🌙"), Triple("Tense", "Edge-of-your-seat moments", "⚡"), Triple("Playful", "Silly situations", "🎈")),
        q("Core fun", 65, "You're picturing a cozy, dreamy mobile game.", "What should the core fun be?", "This becomes the backbone of the loop.", false,
            Triple("Puzzles", "The click of a perfect fit", "🧩"), Triple("Collect & grow", "Slow, satisfying progress", "🌱"), Triple("Story", "Wanting to see what's next", "📖"), Triple("Management", "Running a tiny shop", "🏪")),
    )

    private fun designQuestions(ko: Boolean) = if (ko) listOf(
        q("핵심 루프", 30, "", "한 판의 길이는 어느 정도가 좋을까요?", "출퇴근 시간에 맞춰 정해요.", false,
            Triple("1~2분", "정거장 한두 개 사이", "⏱️"), Triple("3~5분", "추천 · 지하철 한 구간에 딱 맞아요", "☕"), Triple("10분 이상", "앉아서 길게", "🛋️")),
        q("기술", 70, "한 판 3~5분의 짧은 퍼즐로 정했어요.", "어떤 엔진으로 만들까요?", "프로필에 적은 도구를 기준으로 추천했어요.", false,
            Triple("Godot 4", "추천 · 가볍고 2D 퍼즐에 잘 맞아요", "🛠️"), Triple("Unity", "에셋이 많지만 빌드가 무거워요", "🧱"), Triple("Flutter + Flame", "앱 UI와 섞기 쉬워요", "🧩")),
    ) else listOf(
        q("Core loop", 30, "", "How long should one run be?", "Fit it to a commute.", false,
            Triple("1–2 min", "Between one or two stops", "⏱️"), Triple("3–5 min", "Recommended · one subway leg", "☕"), Triple("10+ min", "Sit down and play", "🛋️")),
        q("Tech", 70, "You chose short 3–5 minute puzzles.", "Which engine?", "Based on the tools in your profile.", false,
            Triple("Godot 4", "Recommended · light and great for 2D", "🛠️"), Triple("Unity", "Huge asset store, heavier builds", "🧱"), Triple("Flutter + Flame", "Easy to mix with app UI", "🧩")),
    )

    private fun ready(ko: Boolean) = """{"kind":"ready","stage":"${if (ko) "완료" else "Done"}","progress":100,"insight":"","question":{"title":"","subtitle":"","multi_select":false,"options":[],"allow_custom":false,"custom_hint":""},"ideas_intro":"","ideas":[],"ready_summary":"${if (ko) "- 한 판 3~5분\\n- Godot 4, 세로 화면\\n- 유료 단일 구매" else "- 3–5 minute runs\\n- Godot 4, portrait\\n- One-time purchase"}"}"""

    private fun idea(id: String, t: String, l: String, cat: String, hook: String, feats: List<String>, uniq: String, money: String, scope: String, time: String, diff: Int, fit: String) =
        """{"id":"$id","title":"$t","logline":"$l","category":"$cat","platforms":["Android","iOS"],"genre":"$cat","target_audience":"","core_hook":"$hook","key_features":[${feats.joinToString(",") { "\"$it\"" }}],"unique_point":"$uniq","monetization":"$money","scope":"$scope","dev_time":"$time","difficulty":$diff,"fit_reason":"$fit"}"""

    private fun ideas(ko: Boolean): String {
        val list = if (ko) listOf(
            idea("1", "지하철 정원사", "한 정거장마다 씨앗 하나를 심어 노선도를 꽃길로 바꾸는 퍼즐 게임.", "배치 퍼즐", "정거장 사이 짧은 시간 안에 꽃이 피는 조합을 찾는 쾌감", listOf("노선도 위 타일 배치", "정거장 수만큼 남은 턴", "계절마다 바뀌는 꽃 조합"), "실제 이동 시간과 한 판 길이가 맞물려요.", "유료 4,400원", "소형", "1인 3개월", 2, "짧은 세션과 아늑한 분위기, 혼자 개발 규모를 모두 반영했어요."),
            idea("2", "우산 대여소", "비 오는 도시에서 사람들의 동선을 읽고 우산을 빌려주는 경영 퍼즐.", "경영", "날씨 예보를 읽고 미리 준비하는 전략", listOf("날씨 예보", "손님 이야기", "가게 꾸미기"), "비가 그치면 하루가 끝나요.", "무료 + 꾸미기 아이템", "중형", "1인 5개월", 3, "아늑함과 전략을 함께 원해서 골랐어요."),
            idea("3", "별빛 배달부", "잠든 마을에 꿈을 배달하는 한 손 리듬 러너.", "리듬 러너", "음악에 맞춰 지붕을 건너는 손맛", listOf("한 손 탭 조작", "20곡 수록", "꿈 수집"), "배달한 꿈이 다음 곡을 바꿔요.", "유료", "중형", "1인 6개월", 4, "몽환적인 분위기를 반영했어요."),
            idea("4", "고양이 서점", "고양이가 추천하는 책을 손님에게 연결하는 대화형 퍼즐.", "내러티브", "손님의 사연에 맞는 책을 찾았을 때의 뿌듯함", listOf("사연 읽기", "책장 정리", "고양이 수집"), "고전 문학의 한 구절을 단서로 써요.", "유료", "소형", "1인 4개월", 2, "아늑함과 이야기 선호를 반영했어요."),
        ) else listOf(
            idea("1", "Subway Gardener", "Plant one seed per stop and turn the subway map into a path of flowers.", "Placement puzzle", "Finding the bloom combo before the next stop", listOf("Tile placement on a metro map", "Turns equal to stops left", "Seasonal flower combos"), "A run lasts exactly one commute leg.", "Premium $2.99", "Small", "Solo, 3 months", 2, "Short sessions, cozy mood and solo scope."),
            idea("2", "Umbrella Stand", "Read the city's foot traffic and lend umbrellas before the rain.", "Management", "Planning ahead from the forecast", listOf("Weather forecasts", "Customer stories", "Shop decoration"), "The day ends when the rain stops.", "Free + cosmetics", "Medium", "Solo, 5 months", 3, "Cozy with a bit of strategy."),
            idea("3", "Starlight Courier", "A one-handed rhythm runner delivering dreams to a sleeping town.", "Rhythm runner", "Hopping roofs to the beat", listOf("One-tap controls", "20 songs", "Dream collection"), "Delivered dreams remix the next song.", "Premium", "Medium", "Solo, 6 months", 4, "Matches the dreamy mood."),
            idea("4", "Cat Bookshop", "Match customers with books your cat recommends.", "Narrative", "Finding the perfect book for a story", listOf("Read customer stories", "Arrange shelves", "Collect cats"), "Classic literature lines are the clues.", "Premium", "Small", "Solo, 4 months", 2, "Cozy and story-driven."),
        )
        val intro = if (ko) "체험용으로 준비한 아이디어예요. 실제로는 내 답변에 맞춰 새로 만들어져요." else "These are pre-made demo ideas. With Claude connected, ideas are generated from your answers."
        return """{"kind":"ideas","stage":"${if (ko) "아이디어" else "Ideas"}","progress":100,"insight":"","question":{"title":"","subtitle":"","multi_select":false,"options":[],"allow_custom":false,"custom_hint":""},"ideas_intro":"$intro","ideas":[${list.joinToString(",")}],"ready_summary":""}"""
    }
}
