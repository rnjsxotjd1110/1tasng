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
        } else discoveryReply(request.messages, ko)
        return TurnResult(text, Usage())
    }

    /**
     * 실제 Claude 와 같은 흐름을 흉내 낸다: 기본 질문 → 아이디어, '질문 더 받기'면 추가 질문 3개 → 다른 아이디어 묶음.
     */
    private fun discoveryReply(messages: List<ChatMessage>, ko: Boolean): String {
        val qs = discoveryQuestions(ko)
        val users = messages.filter { it.role == ChatMessage.USER }
        val last = users.lastOrNull()?.text.orEmpty()
        val ideaBatches = messages.count { it.role == ChatMessage.ASSISTANT && it.text.contains("\"kind\":\"ideas\"") }
        val extraStart = users.indexOfLast { it.text.startsWith(Protocol.TAG_MORE_QUESTIONS) }
        val lastIdeasAt = messages.indexOfLast { it.role == ChatMessage.ASSISTANT && it.text.contains("\"kind\":\"ideas\"") }
        val extraActive = extraStart >= 0 && messages.indexOf(users[extraStart]) > lastIdeasAt
        if (extraActive && !last.contains(Protocol.TAG_FRESH_IDEAS)) {
            val answered = users.drop(extraStart + 1).count { it.text.startsWith("[답변]") || it.text.startsWith("[건너뜀]") }
            val extra = extraQuestions(ko)
            if (answered < extra.size) return extra[answered]
        }
        if (last.startsWith("[요청]") || ideaBatches > 0 || users.size > qs.size) return ideas(ko, ideaBatches)
        return qs[users.size - 1]
    }

    private fun extraQuestions(ko: Boolean) = if (ko) listOf(
        q("핵심 경험", 30, "아늑하고 몽환적인 모바일 게임을 원하고 있어요.", "앞의 아이디어 중 어떤 손맛이 가장 끌렸나요?", "다음 아이디어의 중심 재미를 정해요.", false,
            Triple("배치하고 맞추기", "퍼즐처럼 딱 맞아떨어지는 순간", ""), Triple("가꾸고 키우기", "조금씩 자라는 걸 보는 즐거움", ""), Triple("리듬과 타이밍", "음악에 맞춰 손이 움직이는 재미", ""), Triple("이야기 엿보기", "사연을 알아 가는 재미", "")),
        q("소재", 60, "가꾸고 키우는 재미를 중심에 두고 싶어 해요.", "어떤 소재가 더 마음에 드나요?", "세계관과 아트 방향을 좁혀요.", true,
            Triple("밤바다와 등대", "잔잔한 파도와 불빛", ""), Triple("작은 우체국", "편지와 사람들 이야기", ""), Triple("하늘 섬", "구름 위의 작은 마을", ""), Triple("오래된 기차", "창밖으로 흐르는 풍경", "")),
        q("피할 것", 85, "밤바다나 기차처럼 잔잔한 소재를 좋아해요.", "피하고 싶은 요소가 있나요?", "아이디어에서 빼야 할 것을 정해요.", true,
            Triple("시간 제한", "쫓기는 느낌은 싫어요", ""), Triple("경쟁·랭킹", "다른 사람과 겨루기 싫어요", ""), Triple("긴 글", "읽을 게 많은 건 부담돼요", ""), Triple("과금 압박", "결제를 계속 권하는 구조", "")),
    ) else listOf(
        q("Core feel", 30, "You want a cozy, dreamy mobile game.", "Which feel from the ideas pulled you in most?", "Sets the core fun of the next ideas.", false,
            Triple("Placing and fitting", "The click of a perfect fit", ""), Triple("Growing things", "Watching something grow", ""), Triple("Rhythm and timing", "Moving to the music", ""), Triple("Uncovering stories", "Learning people's stories", "")),
        q("Setting", 60, "You want growing things at the center.", "Which setting do you like more?", "Narrows the world and art direction.", true,
            Triple("Night sea and lighthouse", "Calm waves and lights", ""), Triple("Tiny post office", "Letters and people", ""), Triple("Sky islands", "A village above the clouds", ""), Triple("Old train", "Scenery passing by", "")),
        q("Avoid", 85, "You like calm settings like the sea or trains.", "Anything you want to avoid?", "Decides what to leave out.", true,
            Triple("Time limits", "No rushing", ""), Triple("Rankings", "No competing", ""), Triple("Lots of text", "Too much reading", ""), Triple("Pushy payments", "Constant upsells", "")),
    )

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
        """{"id":"$id","title":"$t","logline":"$l","category":"$cat","platforms":["Android","iOS"],"genre":"$cat","target_audience":"","core_hook":"$hook","key_features":[${feats.joinToString(",") { "\"$it\"" }}],"unique_point":"$uniq","monetization":"$money","scope":"$scope","dev_time":"$time","difficulty":$diff,"fun_score":${3 + (id.hashCode() and 1) + (if (diff <= 2) 1 else 0)},"novelty_score":${2 + (id.length + diff) % 4},"fit_reason":"$fit"}"""

    private fun ideas(ko: Boolean, round: Int = 0): String {
        if (round % 2 == 1) return secondIdeas(ko)
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

    /** 두 번째로 받는 아이디어 묶음. 첫 묶음과 겹치지 않는다. */
    private fun secondIdeas(ko: Boolean): String {
        val list = if (ko) listOf(
            idea("5", "등대 우체부", "밤바다 등대에 닿은 편지를 섬마다 배달하며 불빛 길을 잇는 퍼즐.", "경로 퍼즐", "편지가 닿을 때마다 섬에 불이 하나씩 켜지는 순간", listOf("섬 사이 빛 경로 잇기", "편지 속 주민 이야기", "시간 제한 없는 한 판"), "편지 내용이 다음 섬의 퍼즐 규칙이 돼요.", "유료 3,900원", "소형", "1인 3개월", 2, "가꾸는 재미와 밤바다 소재, 시간 제한 없이를 반영했어요."),
            idea("6", "구름 정원 기차", "하늘 섬을 도는 작은 기차에 화분을 싣고 역마다 정원을 키우는 게임.", "육성", "기차가 한 바퀴 돌 때마다 자라 있는 정원", listOf("역마다 다른 꽃", "기차 칸 꾸미기", "하루 한 바퀴 루틴"), "기차 노선이 곧 정원의 모양이 돼요.", "무료 + 꾸미기", "중형", "1인 5개월", 3, "키우는 재미와 기차·하늘 섬 소재를 섞었어요."),
            idea("7", "파도 소리 수집가", "바닷가를 걸으며 파도 소리를 모아 잔잔한 곡을 완성하는 감상형 게임.", "음악 수집", "모은 소리로 나만의 곡이 완성되는 뿌듯함", listOf("소리 조각 수집", "곡 조합", "밤바다 산책"), "경쟁 없이 들으면서 쉬는 게임이에요.", "유료", "소형", "1인 4개월", 2, "경쟁·랭킹을 빼고 잔잔함을 살렸어요."),
            idea("8", "작은 등불 가게", "등불을 만들어 밤길을 걷는 손님들에게 파는 아늑한 가게 운영.", "가게 운영", "손님이 내 등불을 들고 떠나는 장면", listOf("등불 재료 조합", "손님별 취향", "가게 확장"), "팔린 등불이 마을 지도를 밝혀요.", "유료", "중형", "1인 6개월", 3, "등대·불빛 소재와 가꾸는 재미를 반영했어요."),
        ) else listOf(
            idea("5", "Lighthouse Postman", "Deliver letters between islands and link a path of light across the night sea.", "Path puzzle", "An island lights up with every letter delivered", listOf("Link light paths between islands", "Islanders' stories in letters", "No time limits"), "Each letter sets the next island's rule.", "Premium $2.99", "Small", "Solo, 3 months", 2, "Growing, night sea, and no timers."),
            idea("6", "Cloud Garden Train", "Load pots onto a little train circling sky islands and grow a garden at each stop.", "Growing", "Seeing the garden grown after every loop", listOf("Different flowers per stop", "Decorate train cars", "One loop a day"), "The rail line becomes the garden's shape.", "Free + cosmetics", "Medium", "Solo, 5 months", 3, "Growing plus trains and sky islands."),
            idea("7", "Wave Collector", "Walk the shore collecting wave sounds to finish a calm song.", "Music collecting", "Your own song built from collected sounds", listOf("Collect sound pieces", "Compose songs", "Night beach walks"), "A game for resting, no competition.", "Premium", "Small", "Solo, 4 months", 2, "No rankings, just calm."),
            idea("8", "Little Lantern Shop", "Craft lanterns and sell them to travelers walking at night.", "Shop sim", "Watching a customer leave with your lantern", listOf("Combine lantern parts", "Customer tastes", "Expand the shop"), "Sold lanterns light up the town map.", "Premium", "Medium", "Solo, 6 months", 3, "Lights and growth together."),
        )
        val intro = if (ko) "추가 답변(가꾸는 재미, 밤바다·기차 소재, 시간 제한 없이)을 반영해 새로 고른 체험용 아이디어예요." else "Demo ideas picked again using your extra answers."
        return """{"kind":"ideas","stage":"${if (ko) "아이디어" else "Ideas"}","progress":100,"insight":"","question":{"title":"","subtitle":"","multi_select":false,"options":[],"allow_custom":false,"custom_hint":""},"ideas_intro":"$intro","ideas":[${list.joinToString(",")}],"ready_summary":""}"""
    }
}
